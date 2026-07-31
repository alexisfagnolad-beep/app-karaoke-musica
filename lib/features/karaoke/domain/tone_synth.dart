import 'dart:math' as math;
import 'dart:typed_data';

import 'melody.dart';
import 'rhythm.dart';

/// Sintetizador de tonos simple y liviano (sin assets): genera audio WAV en
/// memoria para que las canciones/patrones prediseñados SUENEN y para que, al
/// tocar el piano o la batería en pantalla, se escuche el instrumento.
///
/// Todo es PCM 16 bits mono a 22050 Hz, sintetizado con senoides + envolvente.
/// Así la app no engorda con archivos de audio.
class ToneSynth {
  static const int sr = 22050;

  static double _freq(int midi) =>
      (440.0 * math.pow(2, (midi - 69) / 12.0)).toDouble();

  /// Melodía completa (para reproducir mientras el chico sigue la guía).
  static Uint8List renderMelody(List<MelodyNote> notes, double duration) {
    final buf = Float64List(((duration + 0.5) * sr).ceil());
    for (final n in notes) {
      _addTone(
        buf,
        n.startT,
        (n.endT - n.startT).clamp(0.08, 4.0).toDouble(),
        _freq(n.midi),
        0.5,
      );
    }
    _normalize(buf, 0.85);
    return _wav(buf);
  }

  /// Patrón de batería completo (bombo/redoblante/hi-hat).
  static Uint8List renderRhythm(Rhythm rhythm, double duration) {
    final buf = Float64List(((duration + 0.5) * sr).ceil());
    var seed = 12345;
    for (final h in rhythm.hits) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      switch (h.band) {
        case 0:
          _addKick(buf, h.t);
          break;
        case 1:
          _addSnare(buf, h.t, seed);
          break;
        default:
          _addHat(buf, h.t, seed);
      }
    }
    _normalize(buf, 0.9);
    return _wav(buf);
  }

  /// Una nota suelta corta (decae sola).
  static Uint8List noteTone(int midi) {
    final buf = Float64List((0.6 * sr).ceil());
    _addTone(buf, 0, 0.55, _freq(midi), 0.6);
    _normalize(buf, 0.9);
    return _wav(buf);
  }

  /// Una nota SOSTENIDA (para tocar el piano en pantalla y mantenerla apretada):
  /// se mantiene mientras dure y se corta al soltar la tecla.
  static Uint8List sustainedTone(int midi, {double seconds = 2.6}) {
    final buf = Float64List((seconds * sr).ceil());
    _addSustained(buf, seconds, _freq(midi), 0.55);
    _normalize(buf, 0.9);
    return _wav(buf);
  }

  static void _addSustained(
    Float64List buf,
    double dur,
    double freq,
    double gain,
  ) {
    final len = (dur * sr).round();
    final attack = 0.01 * sr;
    final release = 0.18 * sr;
    for (var i = 0; i < len; i++) {
      if (i >= buf.length) break;
      final t = i / sr;
      double env;
      if (i < attack) {
        env = i / attack;
      } else {
        final rel = len - i;
        env = rel < release ? rel / release : 1.0;
      }
      env *= 0.85 + 0.15 * math.exp(-0.8 * t); // leve caída, más natural
      final ph = 2 * math.pi * freq * t;
      final v =
          (math.sin(ph) +
              0.3 * math.sin(2 * ph) +
              0.12 * math.sin(3 * ph) +
              0.06 * math.sin(4 * ph)) *
          gain *
          env;
      buf[i] += v;
    }
  }

  /// Un golpe suelto (para tocar la batería en pantalla). band: 0 bombo,
  /// 1 redoblante, 2 hi-hat.
  static Uint8List drumTone(int band) {
    final buf = Float64List((0.25 * sr).ceil());
    if (band == 0) {
      _addKick(buf, 0);
    } else if (band == 1) {
      _addSnare(buf, 0, 3);
    } else {
      _addHat(buf, 0, 9);
    }
    _normalize(buf, 0.95);
    return _wav(buf);
  }

  // --- Síntesis ---

  static void _addTone(
    Float64List buf,
    double start,
    double dur,
    double freq,
    double gain,
  ) {
    final s0 = (start * sr).floor();
    final len = (dur * sr).round();
    final attack = 0.008 * sr;
    final release = 0.06 * sr;
    for (var i = 0; i < len; i++) {
      final idx = s0 + i;
      if (idx < 0 || idx >= buf.length) continue;
      final t = i / sr;
      double env;
      if (i < attack) {
        env = i / attack;
      } else {
        final rel = len - i;
        env = rel < release ? rel / release : 1.0;
      }
      env *= math.exp(-1.8 * t); // decaimiento tipo piano
      final ph = 2 * math.pi * freq * t;
      final v =
          (math.sin(ph) + 0.35 * math.sin(2 * ph) + 0.15 * math.sin(3 * ph)) *
          gain *
          env;
      buf[idx] += v;
    }
  }

  static void _addKick(Float64List buf, double start) {
    final s0 = (start * sr).floor();
    final len = (0.18 * sr).round();
    for (var i = 0; i < len; i++) {
      final idx = s0 + i;
      if (idx < 0 || idx >= buf.length) continue;
      final t = i / sr;
      final f = 110 * math.exp(-18 * t) + 45; // barrido de tono hacia grave
      final env = math.exp(-16 * t);
      buf[idx] += math.sin(2 * math.pi * f * t) * env * 0.9;
    }
  }

  static void _addSnare(Float64List buf, double start, int seed) {
    final s0 = (start * sr).floor();
    final len = (0.16 * sr).round();
    var rnd = seed & 0x7fffffff;
    for (var i = 0; i < len; i++) {
      final idx = s0 + i;
      if (idx < 0 || idx >= buf.length) continue;
      final t = i / sr;
      rnd = (rnd * 1103515245 + 12345) & 0x7fffffff;
      final noise = (rnd / 0x3fffffff) - 1.0;
      final env = math.exp(-22 * t);
      final tone = math.sin(2 * math.pi * 185 * t) * 0.4;
      buf[idx] += (noise * 0.7 + tone) * env * 0.7;
    }
  }

  static void _addHat(Float64List buf, double start, int seed) {
    final s0 = (start * sr).floor();
    final len = (0.06 * sr).round();
    var rnd = seed & 0x7fffffff;
    var prev = 0.0;
    for (var i = 0; i < len; i++) {
      final idx = s0 + i;
      if (idx < 0 || idx >= buf.length) continue;
      final t = i / sr;
      rnd = (rnd * 1103515245 + 12345) & 0x7fffffff;
      final noise = (rnd / 0x3fffffff) - 1.0;
      final hp = noise - prev; // pasa-altos crudo (brillo)
      prev = noise;
      final env = math.exp(-45 * t);
      buf[idx] += hp * env * 0.5;
    }
  }

  static void _normalize(Float64List buf, double peak) {
    var mx = 0.0;
    for (final v in buf) {
      final a = v.abs();
      if (a > mx) mx = a;
    }
    if (mx > peak && mx > 0) {
      final g = peak / mx;
      for (var i = 0; i < buf.length; i++) {
        buf[i] *= g;
      }
    }
  }

  static Uint8List _wav(Float64List buf) {
    final n = buf.length;
    final dataLen = n * 2;
    final out = Uint8List(44 + dataLen);
    final bd = ByteData.view(out.buffer);
    void ascii(int off, String s) {
      for (var i = 0; i < s.length; i++) {
        out[off + i] = s.codeUnitAt(i);
      }
    }

    ascii(0, 'RIFF');
    bd.setUint32(4, 36 + dataLen, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    bd.setUint32(16, 16, Endian.little);
    bd.setUint16(20, 1, Endian.little); // PCM
    bd.setUint16(22, 1, Endian.little); // mono
    bd.setUint32(24, sr, Endian.little);
    bd.setUint32(28, sr * 2, Endian.little); // byte rate
    bd.setUint16(32, 2, Endian.little); // block align
    bd.setUint16(34, 16, Endian.little); // bits
    ascii(36, 'data');
    bd.setUint32(40, dataLen, Endian.little);
    for (var i = 0; i < n; i++) {
      var v = buf[i];
      if (v > 1) v = 1;
      if (v < -1) v = -1;
      bd.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
    }
    return out;
  }
}
