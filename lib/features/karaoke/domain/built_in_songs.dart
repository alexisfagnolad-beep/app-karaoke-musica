import 'package:flutter/material.dart';

import 'melody.dart';
import 'rhythm.dart';

/// Una melodía prediseñada, lista para tocar sin PC (piano/voz).
class BuiltInSong {
  final String title;
  final IconData icon;
  final List<MelodyNote> notes;
  final double duration;

  const BuiltInSong({
    required this.title,
    required this.icon,
    required this.notes,
    required this.duration,
  });
}

/// Un patrón rítmico prediseñado para practicar batería.
class BuiltInPattern {
  final String title;
  final IconData icon;
  final Rhythm rhythm;
  final double duration;

  const BuiltInPattern({
    required this.title,
    required this.icon,
    required this.rhythm,
    required this.duration,
  });
}

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

double _dur(List<MelodyNote> n) => n.isEmpty ? 0.0 : n.last.endT + 1.0;

BuiltInSong _song(
  String title,
  IconData icon,
  List<List<num>> seq,
  double bpm,
) {
  final notes = _mel(seq, bpm);
  return BuiltInSong(
    title: title,
    icon: icon,
    notes: notes,
    duration: _dur(notes),
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
  ], 100),
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
  ], 100),
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
  ], 110),
];

Rhythm _pattern(double bpm, int bars, List<List<num>> perBar, double lead) {
  final spb = 60.0 / bpm;
  final hits = <RhythmHit>[];
  for (var bar = 0; bar < bars; bar++) {
    final base = bar * 4.0 + lead;
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

/// Patrones rítmicos para practicar batería. band: 0 bombo, 1 redoblante,
/// 2 hi-hat. [beatDentroDelCompás, band].
final List<BuiltInPattern> builtInPatterns = [
  _pat('Rock básico', Icons.music_note, 90, 4, const [
    [0, 2], [0.5, 2], [1, 2], [1.5, 2], [2, 2], [2.5, 2], [3, 2], [3.5, 2],
    [0, 0], [2, 0], // bombo 1 y 3
    [1, 1], [3, 1], // redoblante 2 y 4
  ]),
  _pat('Pop simple', Icons.queue_music, 100, 4, const [
    [0, 2],
    [1, 2],
    [2, 2],
    [3, 2],
    [0, 0],
    [2.5, 0],
    [1, 1],
    [3, 1],
  ]),
  _pat('Marcha', Icons.directions_walk, 110, 4, const [
    [0, 0],
    [1, 1],
    [2, 0],
    [3, 1],
  ]),
];
