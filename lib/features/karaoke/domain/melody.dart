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
  ///  1. Corrige saltos de octava (errores típicos del detector de tono).
  ///  2. Suaviza con un filtro de mediana (mata el jitter cuadro a cuadro).
  ///  3. Une tramos con la misma nota puenteando huecos → barras más largas.
  ///
  /// [minDuration]: duración mínima (seg) de una nota (descarta jitter).
  /// [maxGap]: hueco máximo (seg) que se "puentea" dentro de una misma nota.
  /// [smoothWindow]: ventana (en cuadros) del filtro de mediana (impar).
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

    // 2) Corrección de saltos de octava por continuidad.
    var prev = _median(List<double>.of(vm));
    for (var i = 0; i < vm.length; i++) {
      var m = vm[i];
      while (m - prev > 6) {
        m -= 12;
      }
      while (prev - m > 6) {
        m += 12;
      }
      vm[i] = m;
      prev = m;
    }

    // 3) Suavizado fuerte por mediana (mata el temblor cuadro a cuadro).
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
      final start = vt[segStart];
      final end = vt[endIdx] + dt;
      if (end - start >= minDuration) {
        result.add(MelodyNote(startT: start, endT: end, midi: midi));
      }
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

    // 5) Unir notas vecinas de la misma altura (por si quedó jitter en el borde).
    final merged = <MelodyNote>[];
    for (final n in result) {
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

  static double _median(List<double> xs) {
    if (xs.isEmpty) return 0;
    final s = List<double>.of(xs)..sort();
    final mid = s.length ~/ 2;
    return s.length.isOdd ? s[mid] : (s[mid - 1] + s[mid]) / 2.0;
  }
}
