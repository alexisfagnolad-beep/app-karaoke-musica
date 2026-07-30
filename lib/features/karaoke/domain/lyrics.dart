import 'dart:convert';

/// Una palabra de la letra con su tiempo (segundos).
class LyricWord {
  final double start;
  final double end;
  final String text;

  const LyricWord({required this.start, required this.end, required this.text});
}

/// Una línea de la letra (frase) con sus palabras.
class LyricLine {
  final double start;
  final double end;
  final String text;
  final List<LyricWord> words;

  const LyricLine({
    required this.start,
    required this.end,
    required this.text,
    required this.words,
  });
}

/// Letra sincronizada generada por la PC (`lyrics.json`), para mostrar debajo
/// de las barras y resaltar la palabra que va sonando.
class Lyrics {
  final String? language;
  final List<LyricLine> lines;

  const Lyrics({this.language, required this.lines});

  factory Lyrics.fromJson(Map<String, dynamic> json) {
    final rawLines = (json['lines'] as List?) ?? const [];
    final lines = rawLines.map((e) {
      final m = e as Map<String, dynamic>;
      final rawWords = (m['words'] as List?) ?? const [];
      final words = rawWords.map((w) {
        final wm = w as Map<String, dynamic>;
        return LyricWord(
          start: (wm['start'] as num).toDouble(),
          end: (wm['end'] as num).toDouble(),
          text: wm['text'] as String? ?? '',
        );
      }).toList();
      return LyricLine(
        start: (m['start'] as num).toDouble(),
        end: (m['end'] as num).toDouble(),
        text: m['text'] as String? ?? '',
        words: words,
      );
    }).toList();
    return Lyrics(language: json['language'] as String?, lines: lines);
  }

  static Lyrics parse(String source) =>
      Lyrics.fromJson(json.decode(source) as Map<String, dynamic>);

  bool get isEmpty => lines.isEmpty;

  /// Índice de la línea que suena en el instante [t] (segundos). Si estás en
  /// un hueco entre líneas, devuelve la próxima que va a sonar (para mostrarla
  /// venir). Devuelve null si no hay líneas.
  int? lineIndexAt(double t) {
    if (lines.isEmpty) return null;
    // Línea activa (t dentro de [start, end]).
    for (var i = 0; i < lines.length; i++) {
      if (t >= lines[i].start && t <= lines[i].end) return i;
    }
    // Si no hay activa, la próxima que empieza después de t.
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].start > t) return i;
    }
    return lines.length - 1;
  }
}
