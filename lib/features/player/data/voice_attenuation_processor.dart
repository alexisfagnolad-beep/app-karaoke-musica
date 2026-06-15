import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:path_provider/path_provider.dart';

/// Atenúa la voz de una canción por cancelación de fase (técnica "center
/// channel cancellation"): en una mezcla estéreo, la voz suele estar centrada
/// (igual en L y R), así que `L - R` la cancela y deja el resto.
///
/// Es instantáneo y liviano (corre en cualquier teléfono), pero imperfecto:
/// baja bien la voz si está centrada, a medias en otras grabaciones. La
/// separación de calidad (Demucs) queda para el motor de PC, como dice el
/// README.
///
/// Decodifica con flutter_soloud (MP3/WAV/FLAC nativo, sin FFmpeg) y escribe
/// un WAV mono con la mezcla atenuada, listo para reproducir.
class VoiceAttenuationProcessor {
  static const int sampleRate = 44100;
  static const int channels = 2;

  /// Procesa [inputPath] y devuelve la ruta del WAV con la voz atenuada.
  /// [onProgress] reporta avance de 0 a 1.
  Future<String> process(
    String inputPath, {
    void Function(double progress)? onProgress,
  }) async {
    final soloud = SoLoud.instance;
    final createdHere = !soloud.isInitialized;
    if (createdHere) {
      await soloud.init(sampleRate: sampleRate, channels: Channels.stereo);
    }

    AudioSource? source;
    try {
      source = await soloud.loadFile(inputPath, mode: LoadMode.disk);
      final totalSeconds = soloud.getLength(source).inMilliseconds / 1000.0;
      if (totalSeconds <= 0) {
        throw Exception('No se pudo leer la duración del audio.');
      }

      final dir = await getApplicationSupportDirectory();
      final outFile = File('${dir.path}/karaoke_voz_atenuada.wav');
      final raf = outFile.openSync(mode: FileMode.write);

      // Reservamos los 44 bytes del header; se completan al final.
      raf.writeFromSync(Uint8List(44));
      var totalMonoSamples = 0;

      const chunkSeconds = 30.0;
      var t = 0.0;
      while (t < totalSeconds) {
        final end = math.min(t + chunkSeconds, totalSeconds);
        final frames = ((end - t) * sampleRate).round();
        if (frames <= 0) break;

        // average:false => muestras por canal (intercaladas L,R,L,R…).
        final samples = await soloud.readSamplesFromFile(
          inputPath,
          frames * channels,
          startTime: t,
          endTime: end,
          average: false,
        );

        final out = BytesBuilder(copy: false);
        for (var i = 0; i + 1 < samples.length; i += 2) {
          var mono = samples[i] - samples[i + 1]; // cancela el centro
          if (mono > 1.0) mono = 1.0;
          if (mono < -1.0) mono = -1.0;
          final v = (mono * 32767).round();
          out.addByte(v & 0xFF);
          out.addByte((v >> 8) & 0xFF);
          totalMonoSamples++;
        }
        raf.writeFromSync(out.takeBytes());

        t = end;
        onProgress?.call((t / totalSeconds).clamp(0.0, 1.0));
      }

      raf.setPositionSync(0);
      raf.writeFromSync(_wavHeader(dataBytes: totalMonoSamples * 2));
      await raf.close();

      return outFile.path;
    } finally {
      if (source != null) soloud.disposeSource(source);
      // Liberamos el dispositivo de audio para no chocar con el reproductor.
      if (createdHere) soloud.deinit();
    }
  }

  /// Header WAV PCM 16-bit mono a [sampleRate].
  Uint8List _wavHeader({required int dataBytes}) {
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
    u32(16); // tamaño del bloque fmt (PCM)
    u16(1); // formato PCM
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
