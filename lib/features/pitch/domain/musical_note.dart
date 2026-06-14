import 'dart:math' as math;

/// Representa la nota musical más cercana a una frecuencia detectada,
/// junto con su desviación en cents respecto de la afinación exacta.
///
/// Convención de afinación: A4 = 440 Hz (estándar).
/// 100 cents = 1 semitono. Un valor de cents positivo significa que la
/// voz está "alta" (sostenida) respecto de la nota; negativo, "baja".
class MusicalNote {
  /// Nombre de la nota sin octava, ej. "A", "C#".
  final String name;

  /// Octava científica, ej. 4 para el La central (A4 = 440 Hz).
  final int octave;

  /// Frecuencia detectada en Hz.
  final double frequency;

  /// Desviación respecto de la nota exacta, en cents (rango aprox. -50..+50).
  final double cents;

  /// Número de nota MIDI de la nota más cercana (A4 = 69).
  final int midi;

  const MusicalNote({
    required this.name,
    required this.octave,
    required this.frequency,
    required this.cents,
    required this.midi,
  });

  /// Nombre completo con octava, ej. "A4".
  String get fullName => '$name$octave';

  /// true si está suficientemente afinada (menos de [tolerance] cents).
  bool isInTune({double tolerance = 5.0}) => cents.abs() < tolerance;

  /// Nombres de las 12 notas cromáticas empezando en Do (C).
  static const List<String> noteNames = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];

  /// Frecuencia de referencia de A4.
  static const double a4Frequency = 440.0;

  /// Construye la nota más cercana a [frequency] (Hz).
  ///
  /// Devuelve `null` para frecuencias no válidas (<= 0), que ocurren cuando
  /// no hay sonido afinado (silencio, ruido).
  static MusicalNote? fromFrequency(double frequency) {
    if (frequency <= 0 || frequency.isNaN || frequency.isInfinite) {
      return null;
    }

    // Número de nota MIDI continuo a partir de la frecuencia.
    final midiFloat =
        69.0 + 12.0 * (math.log(frequency / a4Frequency) / math.ln2);
    final midiRound = midiFloat.round();

    // Desviación: diferencia entre la nota continua y la entera, en cents.
    final cents = (midiFloat - midiRound) * 100.0;

    final name = noteNames[midiRound % 12];
    // En notación científica, C-1 es MIDI 0 -> octava = midi ~/ 12 - 1.
    final octave = (midiRound ~/ 12) - 1;

    return MusicalNote(
      name: name,
      octave: octave,
      frequency: frequency,
      cents: cents,
      midi: midiRound,
    );
  }
}
