import 'package:flutter_test/flutter_test.dart';
import 'package:karaoke_musica/features/karaoke/domain/melody.dart';
import 'package:karaoke_musica/features/karaoke/domain/rhythm.dart';
import 'package:karaoke_musica/features/karaoke/domain/scoring.dart';

Melody _demoMelody() {
  // 0..2s nota 60 (C4), 2..3s silencio, 3..5s nota 64 (E4). 50 fps.
  final frames = <MelodyFrame>[];
  for (var i = 0; i < 250; i++) {
    final t = i / 50.0;
    int? midi;
    bool voiced;
    if (t < 2) {
      midi = 60;
      voiced = true;
    } else if (t < 3) {
      midi = null;
      voiced = false;
    } else {
      midi = 64;
      voiced = true;
    }
    frames.add(MelodyFrame(t: t, midi: midi, voiced: voiced));
  }
  return Melody(fps: 50, frames: frames);
}

List<PerformanceSample> _gen(
    Melody m, double? Function(double t, int? target) f) {
  final out = <PerformanceSample>[];
  for (var i = 0; i < 250; i++) {
    final t = i / 50.0;
    out.add(PerformanceSample(t, f(t, m.frameAt(t)?.midi)));
  }
  return out;
}

void main() {
  group('puntaje melódico', () {
    final m = _demoMelody();

    test('cantar perfecto da puntaje alto', () {
      final r = scorePerformance(m, _gen(m, (t, tg) => tg?.toDouble()));
      expect(r.score, greaterThan(95));
    });

    test('una octava arriba también cuenta (folding)', () {
      final r = scorePerformance(m, _gen(m, (t, tg) => tg == null ? null : tg + 12.0));
      expect(r.score, greaterThan(95));
    });

    test('desafinado 3 semitonos da puntaje bajo', () {
      final r = scorePerformance(m, _gen(m, (t, tg) => tg == null ? null : tg + 3.0));
      expect(r.score, lessThan(20));
    });

    test('no cantar da 0', () {
      final r = scorePerformance(m, _gen(m, (t, tg) => null));
      expect(r.score, 0);
    });
  });

  group('puntaje rítmico', () {
    final ref = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0];

    test('golpes perfectos dan ~100', () {
      final r = scoreRhythm(ref, List.of(ref));
      expect(r.score, greaterThan(95));
    });

    test('todo corrido 300ms cae fuera de ventana -> bajo', () {
      final r = scoreRhythm(ref, ref.map((t) => t + 0.3).toList());
      expect(r.score, lessThan(10));
    });

    test('acertar la mitad -> recall 0.5', () {
      final r = scoreRhythm(ref, [0.5, 1.0, 1.5]);
      expect(r.recall, closeTo(0.5, 0.01));
    });
  });
}
