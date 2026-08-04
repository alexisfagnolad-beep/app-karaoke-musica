import 'package:flutter/material.dart';

import 'lyrics.dart';
import 'melody.dart';
import 'rhythm.dart';

/// Una melodía prediseñada, lista para tocar sin PC (piano/voz).
class BuiltInSong {
  final String title;
  final IconData icon;
  final List<MelodyNote> notes;
  final double duration;

  /// Letra sincronizada (una sílaba por nota), para cantar. Puede ser null.
  final Lyrics? lyrics;

  const BuiltInSong({
    required this.title,
    required this.icon,
    required this.notes,
    required this.duration,
    this.lyrics,
  });
}

/// Arma una letra sincronizada asignando una sílaba a cada nota (en orden) y
/// agrupándolas en frases de [perLine] palabras. Robusta a diferencias de
/// largo (usa el mínimo).
Lyrics? _lyrics(List<MelodyNote> notes, List<String> syl, {int perLine = 6}) {
  if (syl.isEmpty) return null;
  final words = <LyricWord>[];
  final n = notes.length < syl.length ? notes.length : syl.length;
  for (var i = 0; i < n; i++) {
    words.add(
      LyricWord(start: notes[i].startT, end: notes[i].endT, text: syl[i]),
    );
  }
  if (words.isEmpty) return null;
  final lines = <LyricLine>[];
  for (var i = 0; i < words.length; i += perLine) {
    final end = (i + perLine) < words.length ? i + perLine : words.length;
    final chunk = words.sublist(i, end);
    lines.add(
      LyricLine(
        start: chunk.first.start,
        end: chunk.last.end,
        text: chunk.map((w) => w.text).join(' '),
        words: chunk,
      ),
    );
  }
  return Lyrics(lines: lines);
}

/// Un patrón rítmico prediseñado para practicar batería.
class BuiltInPattern {
  final String title;
  final IconData icon;
  final Rhythm rhythm;
  final double duration;

  /// Piezas que usa el patrón (para armar la batería dibujada). Por defecto las
  /// 3 básicas; los patrones que usan toms/platillos traen su propio set.
  final Set<String> pieces;

  const BuiltInPattern({
    required this.title,
    required this.icon,
    required this.rhythm,
    required this.duration,
    this.pieces = const {'kick', 'snare', 'hihat'},
  });
}

/// Banda (grave/medio/agudo) de cada pieza, para los patrones por pieza.
const Map<String, int> _pieceBand = {
  'kick': 0,
  'leguero': 0,
  'snare': 1,
  'chancha': 1,
  'tom1': 1,
  'tom2': 1,
  'floor': 1,
  'hihat': 2,
  'crash': 2,
  'ride': 2,
};

// [midi, startBeat, durBeats] -> notas (con un compás de entrada para la cuenta).
List<MelodyNote> _mel(List<List<num>> seq, double bpm, {double lead = 4}) {
  final spb = 60.0 / bpm;
  return [
    for (final e in seq)
      MelodyNote(
        startT: spb * (lead + e[1]),
        endT: spb * (lead + e[1] + e[2]),
        midi: e[0].toInt(),
      ),
  ];
}

// [midi, durBeats] en secuencia (los tiempos se acumulan solos). midi <= 0 es
// un silencio. Más simple y menos propenso a errores para melodías largas.
List<MelodyNote> _melSeq(List<List<num>> seq, double bpm, {double lead = 4}) {
  final spb = 60.0 / bpm;
  final out = <MelodyNote>[];
  var beat = lead;
  for (final e in seq) {
    final midi = e[0].toInt();
    final dur = e[1].toDouble();
    if (midi > 0) {
      out.add(
        MelodyNote(startT: spb * beat, endT: spb * (beat + dur), midi: midi),
      );
    }
    beat += dur;
  }
  return out;
}

double _dur(List<MelodyNote> n) => n.isEmpty ? 0.0 : n.last.endT + 1.0;

BuiltInSong _song(
  String title,
  IconData icon,
  List<List<num>> seq,
  double bpm, {
  List<String> syllables = const [],
}) {
  final notes = _mel(seq, bpm);
  return BuiltInSong(
    title: title,
    icon: icon,
    notes: notes,
    duration: _dur(notes),
    lyrics: _lyrics(notes, syllables),
  );
}

BuiltInSong _songSeq(
  String title,
  IconData icon,
  List<List<num>> seq,
  double bpm, {
  List<String> syllables = const [],
}) {
  final notes = _melSeq(seq, bpm);
  return BuiltInSong(
    title: title,
    icon: icon,
    notes: notes,
    duration: _dur(notes),
    lyrics: _lyrics(notes, syllables),
  );
}

/// Melodías simples pensadas para empezar de cero (dominio público).
final List<BuiltInSong> builtInSongs = [
  _song('Oda a la Alegría', Icons.emoji_emotions, const [
    [64, 0, 1],
    [64, 1, 1],
    [65, 2, 1],
    [67, 3, 1],
    [67, 4, 1],
    [65, 5, 1],
    [64, 6, 1],
    [62, 7, 1],
    [60, 8, 1],
    [60, 9, 1],
    [62, 10, 1],
    [64, 11, 1],
    [64, 12, 1.5],
    [62, 13.5, 0.5],
    [62, 14, 2],
  ], 78, syllables: const [
    'Es', 'cu', 'cha', 'her', 'ma', 'no', 'la', 'can',
    'ción', 'de', 'la', 'a', 'le', 'grí', 'a',
  ]),
  _song('Estrellita (Twinkle)', Icons.star, const [
    [60, 0, 1],
    [60, 1, 1],
    [67, 2, 1],
    [67, 3, 1],
    [69, 4, 1],
    [69, 5, 1],
    [67, 6, 2],
    [65, 8, 1],
    [65, 9, 1],
    [64, 10, 1],
    [64, 11, 1],
    [62, 12, 1],
    [62, 13, 1],
    [60, 14, 2],
  ], 76, syllables: const [
    'Es', 'tre', 'lli', 'ta', 'dón', 'de', 'es', 'tás',
    'quie', 'ro', 'ver', 'te', 'bri', 'llar',
  ]),
  _song('Feliz Cumpleaños', Icons.cake, const [
    [67, 0, 0.75],
    [67, 0.75, 0.25],
    [69, 1, 1],
    [67, 2, 1],
    [72, 3, 1],
    [71, 4, 2],
    [67, 6, 0.75],
    [67, 6.75, 0.25],
    [69, 7, 1],
    [67, 8, 1],
    [74, 9, 1],
    [72, 10, 2],
    [67, 12, 0.75],
    [67, 12.75, 0.25],
    [79, 13, 1],
    [76, 14, 1],
    [72, 15, 1],
    [71, 16, 1],
    [69, 17, 2],
    [77, 19, 0.75],
    [77, 19.75, 0.25],
    [76, 20, 1],
    [72, 21, 1],
    [74, 22, 1],
    [72, 23, 2],
  ], 84, syllables: const [
    'Cum', 'ple', 'a', 'ños', 'fe', 'liz',
    'Cum', 'ple', 'a', 'ños', 'fe', 'liz',
    'Cum', 'ple', 'a', 'ños', 'que', 'ri', 'do',
    'Cum', 'ple', 'a', 'ños', 'fe', 'liz',
  ]),
  // Fray Santiago / Martinillo (canon, dominio público). [midi, duración].
  _songSeq('Fray Santiago', Icons.notifications, const [
    [60, 1], [62, 1], [64, 1], [60, 1],
    [60, 1], [62, 1], [64, 1], [60, 1],
    [64, 1], [65, 1], [67, 2],
    [64, 1], [65, 1], [67, 2],
    [67, .5], [69, .5], [67, .5], [65, .5], [64, 1], [60, 1],
    [67, .5], [69, .5], [67, .5], [65, .5], [64, 1], [60, 1],
    [60, 1], [55, 1], [60, 2],
    [60, 1], [55, 1], [60, 2],
  ], 74, syllables: const [
    'Fray', 'San', 'tia', 'go', 'Fray', 'San', 'tia', 'go',
    'Duer', 'mes', 'tú', 'Duer', 'mes', 'tú',
    'Sue', 'nan', 'las', 'cam', 'pa', 'nas',
    'Sue', 'nan', 'las', 'cam', 'pa', 'nas',
    'Din', 'don', 'dan', 'Din', 'don', 'dan',
  ]),
  // "Mari tenía un corderito" (Mary had a little lamb).
  _songSeq('El corderito', Icons.pets, const [
    [64, 1], [62, 1], [60, 1], [62, 1], [64, 1], [64, 1], [64, 2],
    [62, 1], [62, 1], [62, 2], [64, 1], [67, 1], [67, 2],
    [64, 1], [62, 1], [60, 1], [62, 1], [64, 1], [64, 1], [64, 1],
    [64, 1], [62, 1], [62, 1], [64, 1], [62, 1], [60, 2],
  ], 88, syllables: const [
    'Ma', 'rí', 'a', 'tie', 'ne un', 'cor', 'de',
    'ri', 'to', 'blan', 'co', 'muy', 'chi',
    'qui', 'to', 'que a', 'to', 'dos', 'ha', 'ce',
    'reír', 'ju', 'gar', 'y', 'sal', 'tar',
  ]),
  // "Que llueva" (versión sencilla de terceras, para cantar fácil).
  _songSeq('Que llueva', Icons.water_drop, const [
    [67, 1], [64, 1], [67, 1], [64, 1],
    [69, 1], [67, 1], [65, 1], [64, 1],
    [67, 1], [64, 1], [67, 1], [64, 1],
    [69, 1], [67, 1], [64, 2],
    [60, 1], [62, 1], [64, 1], [65, 1], [67, 2],
  ], 82, syllables: const [
    'Que', 'llue', 'va', 'que', 'llue', 'va', 'la', 'Vir',
    'gen', 'de', 'la', 'cue', 'va', 'los', 'pa',
    'ja', 'ri', 'tos', 'can', 'tan',
  ]),
];

Rhythm _pattern(
  double bpm,
  int bars,
  List<List<num>> perBar,
  double lead, {
  double barBeats = 4,
}) {
  final spb = 60.0 / bpm;
  final hits = <RhythmHit>[];
  for (var bar = 0; bar < bars; bar++) {
    final base = bar * barBeats + lead;
    for (final e in perBar) {
      hits.add(RhythmHit((base + e[0]) * spb, e[1].toInt()));
    }
  }
  hits.sort((a, b) => a.t.compareTo(b.t));
  return Rhythm(onsets: hits.map((h) => h.t).toList(), hits: hits);
}

BuiltInPattern _pat(
  String title,
  IconData icon,
  double bpm,
  int bars,
  List<List<num>> perBar,
) {
  final r = _pattern(bpm, bars, perBar, 4);
  return BuiltInPattern(
    title: title,
    icon: icon,
    rhythm: r,
    duration: (r.onsets.isEmpty ? 0 : r.onsets.last) + 1.0,
  );
}

// Patrón por PIEZA: cada golpe apunta a una pieza específica (tom1, crash, …)
// para que suene e ilumine distinto. perBar: [beatDentroDelCompás, pieceId].
BuiltInPattern _patP(
  String title,
  IconData icon,
  double bpm,
  int bars,
  List<List<Object>> perBar,
) {
  final spb = 60.0 / bpm;
  final hits = <RhythmHit>[];
  final used = <String>{};
  for (var bar = 0; bar < bars; bar++) {
    final base = bar * 4.0 + 4;
    for (final e in perBar) {
      final beat = (e[0] as num).toDouble();
      final id = e[1] as String;
      used.add(id);
      hits.add(RhythmHit((base + beat) * spb, _pieceBand[id] ?? 1, piece: id));
    }
  }
  hits.sort((a, b) => a.t.compareTo(b.t));
  final r = Rhythm(onsets: hits.map((h) => h.t).toList(), hits: hits);
  return BuiltInPattern(
    title: title,
    icon: icon,
    rhythm: r,
    duration: (r.onsets.isEmpty ? 0 : r.onsets.last) + 1.0,
    pieces: used,
  );
}

// Patrón en compás de 3 tiempos (3/4), para el folclore (chacarera, gato,
// zamba). Un compás de entrada de 3 tiempos para la cuenta.
BuiltInPattern _patFolk(
  String title,
  IconData icon,
  double bpm,
  int bars,
  List<List<num>> perBar,
) {
  final r = _pattern(bpm, bars, perBar, 3, barBeats: 3);
  return BuiltInPattern(
    title: title,
    icon: icon,
    rhythm: r,
    duration: (r.onsets.isEmpty ? 0 : r.onsets.last) + 1.0,
  );
}

/// Patrones rítmicos para practicar batería. band: 0 bombo, 1 redoblante,
/// 2 hi-hat. [beatDentroDelCompás, band].
final List<BuiltInPattern> builtInPatterns = [
  _pat('Rock básico', Icons.music_note, 76, 4, const [
    [0, 2], [0.5, 2], [1, 2], [1.5, 2], [2, 2], [2.5, 2], [3, 2], [3.5, 2],
    [0, 0], [2, 0], // bombo 1 y 3
    [1, 1], [3, 1], // redoblante 2 y 4
  ]),
  _pat('Pop simple', Icons.queue_music, 82, 4, const [
    [0, 2],
    [1, 2],
    [2, 2],
    [3, 2],
    [0, 0],
    [2.5, 0],
    [1, 1],
    [3, 1],
  ]),
  _pat('Marcha', Icons.directions_walk, 86, 4, const [
    [0, 0],
    [1, 1],
    [2, 0],
    [3, 1],
  ]),
  // --- Folclore argentino (3/4, versiones simplificadas para practicar) ---
  // Chacarera: bombo con el "golpe" característico y madera (redoblante).
  _patFolk('Chacarera', Icons.local_fire_department, 80, 4, const [
    [0, 0], [1.5, 0], [2, 0], // bombo
    [1, 1], [2.5, 1], // madera / redoblante
  ]),
  // Gato: vivo, acento en 1 y 3.
  _patFolk('Gato', Icons.pets, 92, 4, const [
    [0, 0], [2, 0], // bombo
    [1, 1], [1.5, 1], [2.5, 1], // redoblante
  ]),
  // Zamba: más lenta y cadenciosa (6/8 sentido en 3 tiempos).
  _patFolk('Zamba', Icons.favorite, 72, 4, const [
    [0, 0], [1.5, 0], // bombo
    [1, 1], [2, 1], [2.5, 1], // redoblante
  ]),
  // --- Patrones por pieza: los toms y platillos suenan e iluminan distinto ---
  _patP('Redoble con toms', Icons.graphic_eq, 82, 2, const [
    [0, 'snare'], [0.5, 'snare'],
    [1, 'tom1'], [1.5, 'tom1'],
    [2, 'tom2'], [2.5, 'tom2'],
    [3, 'chancha'], [3.5, 'chancha'],
  ]),
  _patP('Rock con platillos', Icons.album, 88, 4, const [
    [0, 'crash'], [0, 'kick'],
    [0.5, 'hihat'], [1, 'snare'],
    [1.5, 'ride'], [2, 'kick'],
    [2.5, 'ride'], [3, 'snare'], [3.5, 'ride'],
  ]),
];
