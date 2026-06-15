import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Atenúa la voz de una canción por cancelación de fase ("center channel
/// cancellation"): en una mezcla estéreo, la voz suele estar centrada (igual
/// en L y R), así que `L - R` la cancela y deja el resto.
///
/// Instantáneo y liviano, pero imperfecto: baja bien la voz si está centrada,
/// a medias en otras grabaciones. La separación de calidad (Demucs) queda
/// para el motor de PC, como dice el README.
///
/// El audio se decodifica a PCM con el decodificador nativo del dispositivo
/// (MediaCodec en Android, vía MethodChannel); la cancelación L−R se hace en
/// Dart (lógica testeada).
class VoiceAttenuationProcessor {
  static const MethodChannel _channel = MethodChannel('karaoke/decoder');

  /// Procesa [inputPath] y devuelve la ruta del WAV con la voz atenuada.
  Future<String> process(
    String inputPath, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final decodedPath = '${dir.path}/karaoke_decoded.wav';
    final outputPath = '${dir.path}/karaoke_voz_atenuada.wav';

    onProgress?.call(0.05);

    // 1) Decodificación nativa a WAV PCM 16-bit.
    final result = await _channel.invokeMethod<String>('decodeToWav', {
      'input': inputPath,
      'output': decodedPath,
    });
    if (result == null) {
      throw Exception('La decodificación nativa no devolvió resultado.');
    }

    onProgress?.call(0.7);

    // 2) Cancelación de fase L−R -> WAV mono.
    karaokeMonoWav(File(decodedPath), File(outputPath));

    // 3) Limpiamos el WAV intermedio (puede pesar bastante).
    try {
      File(decodedPath).deleteSync();
    } catch (_) {}

    onProgress?.call(1.0);
    return outputPath;
  }

  /// Lee un WAV PCM 16-bit (mono o estéreo) y escribe un WAV mono con
  /// `L - R` (en estéreo) para cancelar lo que está centrado. Función pura
  /// (sin plugins): se testea en `flutter test`.
  static void karaokeMonoWav(File input, File output) {
    final bytes = input.readAsBytesSync();
    final data = ByteData.sublistView(bytes);

    var sampleRate = 44100;
    var channels = 2;
    var bits = 16;
    var dataOffset = -1;
    var dataLen = 0;

    // Recorre los chunks RIFF buscando 'fmt ' y 'data'.
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
      pos = body + size + (size & 1); // chunks alineados a 2 bytes
    }

    if (dataOffset < 0 || bits != 16) {
      throw Exception('WAV no soportado (bits=$bits).');
    }

    final end = (dataOffset + dataLen).clamp(0, bytes.length);
    final out = BytesBuilder(copy: false);

    if (channels >= 2) {
      final frameBytes = channels * 2; // 2 bytes por muestra
      for (var i = dataOffset; i + frameBytes <= end; i += frameBytes) {
        final l = data.getInt16(i, Endian.little);
        final r = data.getInt16(i + 2, Endian.little);
        var mono = l - r;
        if (mono > 32767) mono = 32767;
        if (mono < -32768) mono = -32768;
        out.addByte(mono & 0xFF);
        out.addByte((mono >> 8) & 0xFF);
      }
    } else {
      // Mono: no hay canales para cancelar, se copia tal cual.
      for (var i = dataOffset; i + 2 <= end; i += 2) {
        out.addByte(bytes[i]);
        out.addByte(bytes[i + 1]);
      }
    }

    final pcm = out.takeBytes();
    final sink = output.openSync(mode: FileMode.write);
    sink.writeFromSync(_wavHeader(dataBytes: pcm.length, sampleRate: sampleRate));
    sink.writeFromSync(pcm);
    sink.closeSync();
  }

  /// Header WAV PCM 16-bit mono.
  static Uint8List _wavHeader({required int dataBytes, required int sampleRate}) {
    const monoChannels = 1;
    const bitsPerSample = 16;
    final byteRate = sampleRate * monoChannels * bitsPerSample ~/ 8;
    final blockAlign = monoChannels * bitsPerSample ~/ 8;

    final b = BytesBuilder();
    void str(String s) => b.add(s.codeUnits);
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
    u16(1); // PCM
    u16(monoChannels);
    u32(sampleRate);
    u32(byteRate);
    u16(blockAlign);
    u16(bitsPerSample);
    str('data');
    u32(dataBytes);
    return b.takeBytes();
  }
}
