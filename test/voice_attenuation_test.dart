import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:karaoke_musica/features/player/data/voice_attenuation_processor.dart';

const _sampleRate = 44100;

/// Escribe un WAV PCM 16-bit estéreo a partir de muestras L/R.
File _writeStereoWav(Directory dir, List<int> left, List<int> right) {
  final frames = left.length;
  final b = BytesBuilder();
  void str(String s) => b.add(s.codeUnits);
  void u32(int v) {
    b..addByte(v & 0xFF)..addByte((v >> 8) & 0xFF)
      ..addByte((v >> 16) & 0xFF)..addByte((v >> 24) & 0xFF);
  }

  void u16(int v) => b..addByte(v & 0xFF)..addByte((v >> 8) & 0xFF);

  final dataBytes = frames * 4;
  str('RIFF');
  u32(36 + dataBytes);
  str('WAVE');
  str('fmt ');
  u32(16);
  u16(1);
  u16(2);
  u32(_sampleRate);
  u32(_sampleRate * 4);
  u16(4);
  u16(16);
  str('data');
  u32(dataBytes);
  for (var i = 0; i < frames; i++) {
    final t = ByteData(4)
      ..setInt16(0, left[i], Endian.little)
      ..setInt16(2, right[i], Endian.little);
    b.add(t.buffer.asUint8List());
  }
  final f = File('${dir.path}/in.wav');
  f.writeAsBytesSync(b.takeBytes());
  return f;
}

double _rmsLeft(File wav) {
  final bytes = wav.readAsBytesSync();
  final d = ByteData.sublistView(bytes);
  // data empieza en 44 (header estándar que escribe el procesador).
  var sum = 0.0;
  var count = 0;
  for (var i = 44; i + 4 <= bytes.length; i += 4) {
    final l = d.getInt16(i, Endian.little).toDouble();
    sum += l * l;
    count++;
  }
  return math.sqrt(sum / count);
}

void main() {
  test('atenúa una voz centrada y mantiene salida estéreo', () {
    final dir = Directory.systemTemp.createTempSync('karaoke_test');
    addTearDown(() => dir.deleteSync(recursive: true));

    const frames = _sampleRate; // 1 segundo
    final left = List<int>.filled(frames, 0);
    final right = List<int>.filled(frames, 0);
    for (var i = 0; i < frames; i++) {
      // Tono de 1000 Hz centrado (igual en L y R): simula la voz.
      final v = (10000 * math.sin(2 * math.pi * 1000 * i / _sampleRate)).round();
      left[i] = v;
      right[i] = v;
    }

    final input = _writeStereoWav(dir, left, right);
    final output = File('${dir.path}/out.wav');

    VoiceAttenuationProcessor.attenuateVoiceWav(input, output, strength: 0.95);

    // Salida estéreo: header (44) + frames*4 bytes.
    final outBytes = output.readAsBytesSync();
    expect(outBytes.length, 44 + frames * 4);

    // La voz centrada (1000 Hz) debe reducirse mucho.
    final inRms = _rmsLeft(input);
    final outRms = _rmsLeft(output);
    expect(outRms, lessThan(inRms * 0.3),
        reason: 'la voz centrada debería bajar bastante');
  });

  test('preserva los graves centrados (no los cancela)', () {
    final dir = Directory.systemTemp.createTempSync('karaoke_bass');
    addTearDown(() => dir.deleteSync(recursive: true));

    const frames = _sampleRate;
    final left = List<int>.filled(frames, 0);
    final right = List<int>.filled(frames, 0);
    for (var i = 0; i < frames; i++) {
      // Tono de 60 Hz centrado: el bajo, debe conservarse.
      final v = (10000 * math.sin(2 * math.pi * 60 * i / _sampleRate)).round();
      left[i] = v;
      right[i] = v;
    }

    final input = _writeStereoWav(dir, left, right);
    final output = File('${dir.path}/out.wav');
    VoiceAttenuationProcessor.attenuateVoiceWav(input, output, strength: 0.95);

    final inRms = _rmsLeft(input);
    final outRms = _rmsLeft(output);
    expect(outRms, greaterThan(inRms * 0.6),
        reason: 'los graves centrados deberían conservarse');
  });
}
