import 'dart:convert';

/// Un cuadro de la melodía de referencia (una nota objetivo en un instante).
class MelodyFrame {
  final double t; // segundos
  final int? midi; // nota MIDI objetivo, o null si no hay voz
  final bool voiced;

  const MelodyFrame({
    required this.t,
    required this.midi,
    required this.voiced,
  });
}

/// Una nota sostenida de la melodía: una barra del karaoke. Su duración
/// (endT - startT) refleja el fraseo — notas largas = barras largas.
class MelodyNote {
  final double startT;
  final double endT;
  final int midi;

  const MelodyNote({
    required this.startT,
    required this.endT,
    required this.midi,
  });

  double get duration => endT - startT;
}

/// Melodía de referencia generada por la PC (`melody.json`): la nota que debería
/// sonar a lo largo del tiempo. El celular la usa como "partitura" para puntuar.
class Melody {
  final double fps;
  final List<MelodyFrame> frames;

  const Melody({required this.fps, required this.frames});

  factory Melody.fromJson(Map<String, dynamic> json) {
    final fps = (json['fps'] as num?)?.toDouble() ?? 50.0;
    final rawFrames = (json['frames'] as List?) ?? const [];
    final frames = rawFrames.map((e) {
      final m = e as Map<String, dynamic>;
      return MelodyFrame(
        t: (m['t'] as num).toDouble(),
        midi: (m['midi'] as num?)?.toInt(),
        voiced: m['voiced'] == true,
      );
    }).toList();
    return Melody(fps: fps, frames: frames);
  }

  static Melody parse(String source) =>
      Melody.fromJson(json.decode(source) as Map<String, dynamic>);

  /// Cuadro más cercano al tiempo [t] (segundos). Asume frames ordenados por t.
  MelodyFrame? frameAt(double t) {
    if (frames.isEmpty) return null;
    if (t <= frames.first.t) return frames.first;
    if (t >= frames.last.t) return frames.last;

    var lo = 0;
    var hi = frames.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (frames[mid].t < t) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    final b = frames[lo];
    final a = frames[lo - 1];
    return (t - a.t) <= (b.t - t) ? a : b;
  }

  double get durationSeconds => frames.isEmpty ? 0 : frames.last.t;

  bool get hasVoice => frames.any((f) => f.voiced && f.midi != null);

  /// Agrupa los cuadros en notas sostenidas (barras del karaoke): tramos
  /// contiguos con la misma nota MIDI. Notas más largas → barras más largas
  /// (respeta el fraseo). Descarta tramos muy cortos (jitter del análisis).
  ///
  /// [minDuration]: dura­ción mínima (seg) para que un tramo cuente como nota.
  /// [maxGap]: hueco máximo (seg) que se "puentea" entre dos tramos de la
  /// misma nota (para no cortar una nota por micro-silencios del análisis).
  List<MelodyNote> notes({double minDuration = 0.11, double maxGap = 0.12}) {
    final result = <MelodyNote>[];
    final dt = fps > 0 ? 1.0 / fps : 0.02;

    int? curMidi;
    double? start;
    double? lastVoicedT;

    void close() {
      if (curMidi != null && start != null && lastVoicedT != null) {
        final end = lastVoicedT! + dt;
        if (end - start! >= minDuration) {
          result.add(MelodyNote(startT: start!, endT: end, midi: curMidi!));
        }
      }
      curMidi = null;
      start = null;
      lastVoicedT = null;
    }

    for (final f in frames) {
      final voiced = f.voiced && f.midi != null;
      if (!voiced) {
        // Silencio: cerramos salvo que sea un hueco corto dentro de la nota.
        if (curMidi != null &&
            lastVoicedT != null &&
            f.t - lastVoicedT! <= maxGap) {
          continue; // puenteamos el micro-silencio.
        }
        close();
        continue;
      }
      if (curMidi == null) {
        curMidi = f.midi;
        start = f.t;
        lastVoicedT = f.t;
      } else if (f.midi == curMidi) {
        lastVoicedT = f.t;
      } else {
        close();
        curMidi = f.midi;
        start = f.t;
        lastVoicedT = f.t;
      }
    }
    close();
    return result;
  }
}
