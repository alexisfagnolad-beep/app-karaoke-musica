import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Atenúa la voz de una canción sin separación pesada (Demucs queda para PC).
///
/// Mejora sobre el L−R crudo (que suena hueco/metálico): trabaja en mid/side,
/// **conserva los graves** (bajo/bombo, centrados pero de baja frecuencia) y
/// reduce solo la banda media/aguda del centro (donde está la voz),
/// **manteniendo el estéreo**. La intensidad es ajustable.
///
/// El audio se decodifica a PCM con el decodificador nativo del dispositivo
/// (MediaCodec en Android, vía MethodChannel); el DSP se hace en Dart.
class VoiceAttenuationProcessor {
  static const MethodChannel _channel = MethodChannel('karaoke/decoder');

  /// Frecuencia de corte: por debajo se conservan los graves centrados.
  static const double _bassCutoffHz = 150.0;

  /// Decodifica [inputPath] a WAV PCM con el decodificador nativo y devuelve
  /// la ruta del WAV decodificado (estéreo). Se cachea para reprocesar rápido
  /// al cambiar la intensidad sin volver a decodificar.
  Future<String> decode(String inputPath) async {
    final dir = await getTemporaryDirectory();
    final decodedPath = '${dir.path}/karaoke_decoded.wav';
    final result = await _channel.invokeMethod<String>('decodeToWav', {
      'input': inputPath,
      'output': decodedPath,
    });
    if (result == null) {
      throw Exception('La decodificación nativa no devolvió resultado.');
    }
    return decodedPath;
  }

  /// Aplica la atenuación de voz al WAV [decodedPath] (estéreo) con la
  /// [strength] dada (0 = sin efecto, 1 = máximo) y devuelve la ruta del WAV
  /// resultante.
  Future<String> attenuate(String decodedPath, double strength) async {
    final dir = await getTemporaryDirectory();
    final outputPath = '${dir.path}/karaoke_voz_atenuada.wav';
    attenuateVoiceWav(File(decodedPath), File(outputPath), strength: strength);
    return outputPath;
  }

  /// Lee un WAV PCM 16-bit y escribe otro WAV PCM 16-bit con la voz atenuada.
  ///
  /// Estéreo: mid/side con preservación de graves. Mono: se copia (no hay
  /// canales para cancelar). Función pura (sin plugins): se testea en
  /// `flutter test`.
  static void attenuateVoiceWav(
    File input,
    File output, {
    required double strength,
  }) {
    final bytes = input.readAsBytesSync();
    final data = ByteData.sublistView(bytes);

    var sampleRate = 44100;
    var channels = 2;
    var bits = 16;
    var dataOffset = -1;
    var dataLen = 0;

    var pos = 12; // salta 'RIFF'<size>'WAVE'
    while (pos + 8 <= bytes.length) {
      final id = String.fromCharCodes(bytes.sublist(pos, pos + 4));
      final size = data.getUint32(pos + 4, Endian.little);
      final body = pos + 8;
      if (id == 'fmt ') {
        channels = data.getUint16(body + 2, Endian.little);
        sampleRate = data.getUint32(body + 4, Endian.little);
        bits = data.getUint16(body + 14, Endian.little);
      } else if (id == 'data') {
        dataOffset = body;
        dataLen = size;
        break;
      }
      pos = body + size + (size & 1);
    }

    if (dataOffset < 0 || bits != 16) {
      throw Exception('WAV no soportado (bits=$bits).');
    }

    final end = (dataOffset + dataLen).clamp(0, bytes.length);

    // Mono: no hay nada que cancelar, copiamos.
    if (channels < 2) {
      final pcm = Uint8List.sublistView(bytes, dataOffset, end);
      _writeWav(output, pcm, sampleRate: sampleRate, channels: 1);
      return;
    }

    final s = strength.clamp(0.0, 1.0);
    final a = 1 - math.exp(-2 * math.pi * _bassCutoffHz / sampleRate);
    final frameBytes = channels * 2;
    final out = BytesBuilder(copy: false);
    var lp = 0.0; // estado del filtro de graves (sobre el mid)

    for (var i = dataOffset; i + frameBytes <= end; i += frameBytes) {
      final l = data.getInt16(i, Endian.little).toDouble();
      final r = data.getInt16(i + 2, Endian.little).toDouble();
      final mid = (l + r) / 2;
      final side = (l - r) / 2;
      lp += a * (mid - lp); // graves centrados (se conservan)
      final vocalBand = mid - lp;
      final newMid = lp + (1 - s) * vocalBand;
      var outL = (newMid + side).round();
      var outR = (newMid - side).round();
      if (outL > 32767) outL = 32767;
      if (outL < -32768) outL = -32768;
      if (outR > 32767) outR = 32767;
      if (outR < -32768) outR = -32768;
      out.addByte(outL & 0xFF);
      out.addByte((outL >> 8) & 0xFF);
      out.addByte(outR & 0xFF);
      out.addByte((outR >> 8) & 0xFF);
    }

    _writeWav(output, out.takeBytes(), sampleRate: sampleRate, channels: 2);
  }

  static void _writeWav(
    File output,
    Uint8List pcm, {
    required int sampleRate,
    required int channels,
  }) {
    final sink = output.openSync(mode: FileMode.write);
    sink.writeFromSync(
      _wavHeader(
        dataBytes: pcm.length,
        sampleRate: sampleRate,
        channels: channels,
      ),
    );
    sink.writeFromSync(pcm);
    sink.closeSync();
  }

  static Uint8List _wavHeader({
    required int dataBytes,
    required int sampleRate,
    required int channels,
  }) {
    const bitsPerSample = 16;
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;

    final b = BytesBuilder();
    void str(String x) => b.add(x.codeUnits);
    void u32(int v) {
      b.addByte(v & 0xFF);
      b.addByte((v >> 8) & 0xFF);
      b.addByte((v >> 16) & 0xFF);
      b.addByte((v >> 24) & 0xFF);
    }

    void u16(int v) {
      b.addByte(v & 0xFF);
      b.addByte((v >> 8) & 0xFF);
    }

    str('RIFF');
    u32(36 + dataBytes);
    str('WAVE');
    str('fmt ');
    u32(16);
    u16(1);
    u16(channels);
    u32(sampleRate);
    u32(byteRate);
    u16(blockAlign);
    u16(bitsPerSample);
    str('data');
    u32(dataBytes);
    return b.takeBytes();
  }
}
