import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:karaoke_musica/features/player/data/voice_attenuation_processor.dart';

/// Construye un WAV PCM 16-bit estéreo con un componente centrado (igual en
/// L y R, simula la voz) más componentes laterales distintos.
File _writeStereoWav(Directory dir, int frames) {
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

  const sampleRate = 44100;
  final dataBytes = frames * 4; // estéreo, 16-bit
  str('RIFF');
  u32(36 + dataBytes);
  str('WAVE');
  str('fmt ');
  u32(16);
  u16(1);
  u16(2);
  u32(sampleRate);
  u32(sampleRate * 4);
  u16(4);
  u16(16);
  str('data');
  u32(dataBytes);

  for (var i = 0; i < frames; i++) {
    const center = 5000; // voz centrada
    final sideL = (i % 50) * 100;
    final sideR = -(i % 30) * 80;
    final l = center + sideL;
    final r = center + sideR;
    final t = ByteData(4)
      ..setInt16(0, l, Endian.little)
      ..setInt16(2, r, Endian.little);
    b.add(t.buffer.asUint8List());
  }

  final f = File('${dir.path}/in.wav');
  f.writeAsBytesSync(b.takeBytes());
  return f;
}

void main() {
  test('karaokeMonoWav cancela el centro (voz) y deja el lateral', () {
    final dir = Directory.systemTemp.createTempSync('karaoke_test');
    addTearDown(() => dir.deleteSync(recursive: true));

    const frames = 1000;
    final input = _writeStereoWav(dir, frames);
    final output = File('${dir.path}/out.wav');

    VoiceAttenuationProcessor.karaokeMonoWav(input, output);

    final ob = output.readAsBytesSync();
    final od = ByteData.sublistView(ob);

    // El header mono ocupa 44 bytes; data mono = frames * 2 bytes.
    expect(ob.length, 44 + frames * 2);

    for (var i = 0; i < frames; i++) {
      final got = od.getInt16(44 + i * 2, Endian.little);
      final sideL = (i % 50) * 100;
      final sideR = -(i % 30) * 80;
      final expected = (sideL - sideR).clamp(-32768, 32767);
      expect(got, expected, reason: 'frame $i');
    }
  });
}
