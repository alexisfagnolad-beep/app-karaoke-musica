import 'dart:math' as math;

import 'melody.dart';

/// Una muestra de la interpretación: en el instante [t] (segundos de la
/// reproducción), la nota MIDI detectada por el micrófono (o null si no sonó).
class PerformanceSample {
  final double t;
  final double? sungMidi;

  const PerformanceSample(this.t, this.sungMidi);
}

/// Resultado del puntaje.
class KaraokeResult {
  /// Puntaje final 0..100.
  final double score;

  /// Qué tan afinado estuvo lo que cantó/tocó (0..1).
  final double pitchAccuracy;

  /// Qué proporción del tiempo con nota objetivo produjo sonido (0..1)
  /// (mide sostenimiento / cumplimiento de duración).
  final double coverage;

  const KaraokeResult({
    required this.score,
    required this.pitchAccuracy,
    required this.coverage,
  });

  static const empty = KaraokeResult(score: 0, pitchAccuracy: 0, coverage: 0);

  /// Etiqueta simpática según el puntaje.
  String get label {
    if (score >= 90) return '¡Perfecto!';
    if (score >= 75) return '¡Muy bien!';
    if (score >= 60) return 'Bien';
    if (score >= 40) return 'Vas mejorando';
    return 'A practicar';
  }
}

/// Diferencia en semitonos plegada a la octava más cercana (-6..6).
/// Así no penaliza cantar/tocar una octava arriba o abajo.
double octaveFoldedDiff(double sungMidi, int targetMidi) {
  var diff = sungMidi - targetMidi;
  diff = diff - 12 * (diff / 12).round();
  return diff;
}

/// Puntúa la interpretación contra la melodía de referencia.
///
/// - Afinación: cuán cerca (en semitonos) estuvo cada nota del objetivo.
/// - Sostenimiento/duración: si produjo sonido durante los tramos con nota.
///
/// [tolerance] en semitonos: dentro de ~ese margen suma bien.
KaraokeResult scorePerformance(
  Melody melody,
  List<PerformanceSample> samples, {
  double tolerance = 2.5,
}) {
  if (samples.isEmpty || !melody.hasVoice) return KaraokeResult.empty;

  var accSum = 0.0;
  var voicedScored = 0;
  var sang = 0;

  for (final s in samples) {
    final frame = melody.frameAt(s.t);
    if (frame == null || !frame.voiced || frame.midi == null) continue;
    voicedScored++;
    if (s.sungMidi == null) continue;
    sang++;
    final diff = octaveFoldedDiff(s.sungMidi!, frame.midi!).abs();
    accSum += math.max(0.0, 1.0 - diff / tolerance);
  }

  if (voicedScored == 0) return KaraokeResult.empty;

  final coverage = sang / voicedScored;
  final pitchAccuracy = sang > 0 ? accSum / sang : 0.0;
  // El puntaje combina afinación con cuánto sostuvo (no vale afinar 2 notas).
  final score = 100 * pitchAccuracy * (0.4 + 0.6 * coverage);

  return KaraokeResult(
    score: score.clamp(0, 100),
    pitchAccuracy: pitchAccuracy,
    coverage: coverage,
  );
}

/// Puntúa contra las BARRAS que se ven (notas agrupadas), para que el puntaje
/// sea coherente con la guía en pantalla ("puntúa lo que ves").
KaraokeResult scoreAgainstNotes(
  List<MelodyNote> notes,
  List<PerformanceSample> samples, {
  double tolerance = 2.5,
}) {
  if (notes.isEmpty || samples.isEmpty) return KaraokeResult.empty;

  var accSum = 0.0;
  var scored = 0;
  var sang = 0;

  for (final s in samples) {
    final note = _noteAt(notes, s.t);
    if (note == null) continue; // fuera de toda barra: no puntúa.
    scored++;
    if (s.sungMidi == null) continue;
    sang++;
    final diff = octaveFoldedDiff(s.sungMidi!, note.midi).abs();
    accSum += math.max(0.0, 1.0 - diff / tolerance);
  }

  if (scored == 0) return KaraokeResult.empty;
  final coverage = sang / scored;
  final pitchAccuracy = sang > 0 ? accSum / sang : 0.0;
  final score = 100 * pitchAccuracy * (0.4 + 0.6 * coverage);
  return KaraokeResult(
    score: score.clamp(0, 100),
    pitchAccuracy: pitchAccuracy,
    coverage: coverage,
  );
}

MelodyNote? _noteAt(List<MelodyNote> notes, double t) {
  for (final n in notes) {
    if (t >= n.startT && t < n.endT) return n;
  }
  return null;
}
