import 'dart:convert';

/// Un cuadro de la melodía de referencia (una nota objetivo en un instante).
class MelodyFrame {
  final double t; // segundos
  final int? midi; // nota MIDI objetivo, o null si no hay voz
  final bool voiced;

  const MelodyFrame({required this.t, required this.midi, required this.voiced});
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
}
