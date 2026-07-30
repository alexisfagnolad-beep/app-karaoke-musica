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

  /// Agrupa los cuadros en notas sostenidas (barras del karaoke).
  ///
  /// Para que las barras sean fáciles de cantar (es un juego), la referencia
  /// se limpia antes de agrupar:
  ///  1. Suaviza con un filtro de mediana (mata el jitter y picos de octava).
  ///  2. Segmenta por histéresis (notas largas, silueta amable).
  ///  3. "Resume": absorbe las notas cortas (corridas rápidas) en las vecinas.
  ///
  /// [minDuration]: por debajo de esto una nota se absorbe en su vecina.
  /// [maxGap]: hueco máximo (seg) que se "puentea" dentro de una misma nota.
  /// [smoothWindow]: ventana (en cuadros) del filtro de mediana (impar).
  /// [changeThreshold]: semitonos que la melodía debe alejarse para cambiar de
  /// nota (más alto = barras más resumidas / fáciles).
  List<MelodyNote> notes({
    double minDuration = 0.12,
    double maxGap = 0.35,
    int smoothWindow = 9,
    double changeThreshold = 0.8,
  }) {
    final dt = fps > 0 ? 1.0 / fps : 0.02;

    // 1) Cuadros con voz (tiempo + nota MIDI continua).
    final vt = <double>[];
    final vm = <double>[];
    for (final f in frames) {
      if (f.voiced && f.midi != null) {
        vt.add(f.t);
        vm.add(f.midi!.toDouble());
      }
    }
    if (vm.isEmpty) return const [];

    // 2) Suavizado fuerte por mediana (mata el temblor y los picos de 1-2
    //    cuadros, incluidos los errores de octava momentáneos del detector).
    //    No forzamos octava por continuidad: corrompía saltos musicales reales
    //    (quintas/sextas) y, como el puntaje pliega octavas, no hace falta.
    final sm = <double>[];
    final half = smoothWindow ~/ 2;
    for (var i = 0; i < vm.length; i++) {
      final lo = (i - half).clamp(0, vm.length - 1);
      final hi = (i + half).clamp(0, vm.length - 1);
      sm.add(_median(vm.sublist(lo, hi + 1)));
    }

    // 4) Segmentación por histéresis: mantenemos la nota (ancla) hasta que la
    //    melodía se aleja > changeThreshold semitonos de verdad. Así salen
    //    notas largas y una silueta amable, no un escalón por cada temblor.
    final result = <MelodyNote>[];
    var segStart = 0;
    var anchor = sm[0];
    var vals = <double>[sm[0]];

    void close(int endIdx) {
      if (vals.isEmpty) return;
      final midi = _median(vals).round();
      // No descartamos por duración acá: la simplificación (paso 6) absorbe
      // las notas cortas en sus vecinas, sin dejar huecos.
      result.add(
        MelodyNote(startT: vt[segStart], endT: vt[endIdx] + dt, midi: midi),
      );
    }

    for (var i = 1; i < sm.length; i++) {
      final gap = vt[i] - vt[i - 1];
      if (gap > maxGap || (sm[i] - anchor).abs() > changeThreshold) {
        close(i - 1);
        segStart = i;
        anchor = sm[i];
        vals = <double>[sm[i]];
      } else {
        vals.add(sm[i]);
      }
    }
    close(sm.length - 1);

    // 5) Unir notas vecinas de la misma altura.
    var notes = _mergeSamePitch(result, maxGap);

    // 6) Simplificar ("resumir"): absorbemos las notas más cortas que
    //    [minDuration] en la vecina más cercana en altura, para que las
    //    corridas rápidas y los adornos no hagan la canción injugable.
    notes = _absorbShort(notes, minDuration);
    notes = _mergeSamePitch(notes, maxGap);
    return notes;
  }

  static List<MelodyNote> _mergeSamePitch(
    List<MelodyNote> notes,
    double maxGap,
  ) {
    final merged = <MelodyNote>[];
    for (final n in notes) {
      if (merged.isNotEmpty &&
          merged.last.midi == n.midi &&
          n.startT - merged.last.endT <= maxGap) {
        final prevN = merged.removeLast();
        merged.add(
          MelodyNote(startT: prevN.startT, endT: n.endT, midi: n.midi),
        );
      } else {
        merged.add(n);
      }
    }
    return merged;
  }

  /// Absorbe las notas más cortas que [minDur] en la vecina más cercana en
  /// altura (extendiéndola sobre el tiempo de la corta). No deja huecos.
  static List<MelodyNote> _absorbShort(List<MelodyNote> notes, double minDur) {
    if (notes.length < 2) return notes;
    final list = List<MelodyNote>.of(notes);
    var guard = 0;
    while (list.length > 1 && guard++ < 5000) {
      // Nota más corta por debajo del umbral.
      var idx = -1;
      var shortest = minDur;
      for (var i = 0; i < list.length; i++) {
        if (list[i].duration < shortest) {
          shortest = list[i].duration;
          idx = i;
        }
      }
      if (idx == -1) break;

      // Vecina a la que la absorbemos: la más cercana en altura.
      int nb;
      if (idx == 0) {
        nb = 1;
      } else if (idx == list.length - 1) {
        nb = idx - 1;
      } else {
        final dPrev = (list[idx - 1].midi - list[idx].midi).abs();
        final dNext = (list[idx + 1].midi - list[idx].midi).abs();
        nb = dPrev <= dNext ? idx - 1 : idx + 1;
      }
      final cur = list[idx];
      final other = list[nb];
      final start = cur.startT < other.startT ? cur.startT : other.startT;
      final end = cur.endT > other.endT ? cur.endT : other.endT;
      final combined = MelodyNote(startT: start, endT: end, midi: other.midi);
      // Reemplazamos ambas por la combinada.
      final lo = idx < nb ? idx : nb;
      final hi = idx < nb ? nb : idx;
      list.removeAt(hi);
      list.removeAt(lo);
      list.insert(lo, combined);
    }
    return list;
  }

  static double _median(List<double> xs) {
    if (xs.isEmpty) return 0;
    final s = List<double>.of(xs)..sort();
    final mid = s.length ~/ 2;
    return s.length.isOdd ? s[mid] : (s[mid - 1] + s[mid]) / 2.0;
  }
}
