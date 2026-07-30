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
    double minDuration = 0.08,
    double maxGap = 0.35,
    int smoothWindow = 5,
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

    // 2) Corrección de saltos de octava por continuidad: cada nota se lleva a
    //    la octava más cercana a la anterior (arranca desde la mediana global).
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

    // 3) Suavizado por mediana + redondeo a semitono.
    final midi = <int>[];
    final half = smoothWindow ~/ 2;
    for (var i = 0; i < vm.length; i++) {
      final lo = (i - half).clamp(0, vm.length - 1);
      final hi = (i + half).clamp(0, vm.length - 1);
      midi.add(_median(vm.sublist(lo, hi + 1)).round());
    }

    // 4) Agrupar tramos con la misma nota, puenteando huecos <= maxGap.
    final result = <MelodyNote>[];
    int? curMidi;
    double? start;
    double? lastT;

    void close() {
      if (curMidi != null && start != null && lastT != null) {
        final end = lastT! + dt;
        if (end - start! >= minDuration) {
          result.add(MelodyNote(startT: start!, endT: end, midi: curMidi!));
        }
      }
      curMidi = null;
      start = null;
      lastT = null;
    }

    for (var i = 0; i < midi.length; i++) {
      final m = midi[i];
      final t = vt[i];
      final gap = lastT == null ? 0.0 : t - lastT!;
      if (curMidi == null) {
        curMidi = m;
        start = t;
        lastT = t;
      } else if (m == curMidi && gap <= maxGap) {
        lastT = t;
      } else {
        close();
        curMidi = m;
        start = t;
        lastT = t;
      }
    }
    close();
    return result;
  }

  static double _median(List<double> xs) {
    if (xs.isEmpty) return 0;
    final s = List<double>.of(xs)..sort();
    final mid = s.length ~/ 2;
    return s.length.isOdd ? s[mid] : (s[mid - 1] + s[mid]) / 2.0;
  }
}
