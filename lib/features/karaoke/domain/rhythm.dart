import 'dart:convert';
import 'dart:math' as math;

/// Referencia rítmica generada por la PC (`rhythm.json`): los instantes en que
/// ocurre cada golpe (onset) de, por ejemplo, la batería. Se usa para puntuar
/// qué tan bien caés en el tiempo.
class Rhythm {
  final List<double> onsets; // tiempos en segundos, ordenados

  const Rhythm({required this.onsets});

  factory Rhythm.fromJson(Map<String, dynamic> json) {
    final raw = (json['onsets'] as List?) ?? const [];
    final onsets = raw.map((e) => (e as num).toDouble()).toList()..sort();
    return Rhythm(onsets: onsets);
  }

  static Rhythm parse(String source) =>
      Rhythm.fromJson(json.decode(source) as Map<String, dynamic>);

  double get durationSeconds => onsets.isEmpty ? 0 : onsets.last;
  bool get hasOnsets => onsets.isNotEmpty;
}

/// Resultado del puntaje rítmico.
class RhythmResult {
  final double score; // 0..100
  final double
  timing; // precisión temporal media de los golpes acertados (0..1)
  final double recall; // proporción de golpes de la referencia que acertaste
  final double precision; // proporción de tus golpes que cayeron en un objetivo
  final int matched;
  final int total;

  const RhythmResult({
    required this.score,
    required this.timing,
    required this.recall,
    required this.precision,
    required this.matched,
    required this.total,
  });

  static const empty = RhythmResult(
    score: 0,
    timing: 0,
    recall: 0,
    precision: 0,
    matched: 0,
    total: 0,
  );

  String get label {
    if (score >= 90) return '¡Perfecto!';
    if (score >= 75) return '¡Muy bien!';
    if (score >= 60) return 'Bien';
    if (score >= 40) return 'Vas mejorando';
    return 'A practicar';
  }
}

/// Puntúa los golpes del usuario contra la referencia rítmica.
///
/// Empareja cada golpe de la referencia con el golpe del usuario más cercano
/// dentro de [window] segundos; puntúa por cercanía temporal, cuántos acertó
/// (recall) y penaliza golpes de más (precisión).
RhythmResult scoreRhythm(
  List<double> reference,
  List<double> user, {
  double window = 0.18,
}) {
  if (reference.isEmpty) return RhythmResult.empty;

  final ref = List<double>.from(reference)..sort();
  final usr = List<double>.from(user)..sort();
  final used = List<bool>.filled(usr.length, false);

  var matched = 0;
  var timingSum = 0.0;

  for (final r in ref) {
    var best = -1;
    var bestDt = window + 1;
    for (var j = 0; j < usr.length; j++) {
      if (used[j]) continue;
      final dt = (usr[j] - r).abs();
      if (dt <= window && dt < bestDt) {
        best = j;
        bestDt = dt;
      }
    }
    if (best >= 0) {
      used[best] = true;
      matched++;
      timingSum += 1.0 - bestDt / window;
    }
  }

  final recall = matched / ref.length;
  final timing = matched > 0 ? timingSum / matched : 0.0;
  final precision = usr.isEmpty ? 0.0 : matched / usr.length;
  // El puntaje premia caer justo (timing) y acertar la mayoría (recall),
  // y baja un poco si metés muchos golpes de más (precisión).
  final score = 100 * timing * recall * (0.6 + 0.4 * precision);

  return RhythmResult(
    score: score.clamp(0, 100).toDouble(),
    timing: timing,
    recall: recall,
    precision: precision,
    matched: matched,
    total: ref.length,
  );
}

/// Detector de golpes (onsets) por energía, para el micrófono en vivo.
///
/// Mantiene un promedio móvil de energía; cuando la energía de un bloque supera
/// el promedio por un factor y pasó un mínimo de tiempo desde el último golpe,
/// registra un golpe. Pensado para alimentarse bloque a bloque.
class OnsetDetector {
  OnsetDetector({
    this.threshold = 2.2,
    this.minInterval = 0.09,
    this.smoothing = 0.9,
  });

  final double threshold; // cuántas veces por encima del promedio
  final double minInterval; // segundos entre golpes
  final double smoothing; // 0..1 del promedio móvil

  double _avgEnergy = 0.0;
  double _lastOnset = -1e9;
  bool _primed = false;

  /// Procesa un bloque de muestras en el tiempo [t] (segundos). Devuelve true
  /// si detectó un golpe.
  bool process(List<double> block, double t) {
    if (block.isEmpty) return false;
    var e = 0.0;
    for (final v in block) {
      e += v * v;
    }
    e /= block.length;

    if (!_primed) {
      _avgEnergy = e;
      _primed = true;
      return false;
    }

    final isHit =
        e > _avgEnergy * threshold &&
        e > 1e-5 &&
        (t - _lastOnset) >= minInterval;

    _avgEnergy = smoothing * _avgEnergy + (1 - smoothing) * e;

    if (isHit) {
      _lastOnset = t;
      return true;
    }
    return false;
  }

  void reset() {
    _avgEnergy = 0;
    _lastOnset = -1e9;
    _primed = false;
  }
}
