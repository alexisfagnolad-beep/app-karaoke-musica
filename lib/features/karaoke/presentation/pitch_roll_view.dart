import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/karaoke_controller.dart';
import '../domain/lyrics.dart';
import '../domain/scoring.dart';
import 'piano_roll_view.dart' show kNoteColors;

// Nombres Do-Re-Mi por clase de nota (solo blancas; las negras llevan ♯).
const Map<int, String> _solfege = {
  0: 'Do',
  2: 'Re',
  4: 'Mi',
  5: 'Fa',
  7: 'Sol',
  9: 'La',
  11: 'Si',
};

/// Nombre lúdico de la nota (Do-Re-Mi, con ♯ para negras).
String _noteName(int midi) {
  final pc = midi % 12;
  return _solfege[pc] ?? '${_solfege[(pc - 1) % 12]}♯';
}

/// Vista tipo karaoke (SingStar): la línea melódica dibujada como barras que
/// se desplazan de derecha a izquierda. Cuando cantás sobre la barra, se
/// ilumina; si desafinás, tu voz aparece como una barrita más tenue arriba
/// (agudo) o abajo (grave) de la nota objetivo.
class PitchRollView extends StatefulWidget {
  const PitchRollView({super.key, required this.controller, this.lyrics});

  final KaraokeController controller;

  /// Letra sincronizada, para mostrar la sílaba pegada a cada barra.
  final Lyrics? lyrics;

  @override
  State<PitchRollView> createState() => _PitchRollViewState();
}

class _PitchRollViewState extends State<PitchRollView>
    with SingleTickerProviderStateMixin {
  // Anima el desplazamiento a ~60 fps repintando cada frame.
  late final AnimationController _ticker = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _PitchRollPainter(
              controller: widget.controller,
              repaint: _ticker,
              lyrics: widget.lyrics,
              barBase: scheme.onSurface.withValues(alpha: 0.12),
              lit: const Color(0xFFE0457B),
              glow: const Color(0xFFFF7FB0),
              nowLine: scheme.onSurface.withValues(alpha: 0.25),
              onPitch: const Color(0xFF4AE3B5),
              offPitch: const Color(0xFFFFB74D),
            ),
            size: Size.infinite,
          ),
          _buildCountIn(),
        ],
      ),
    );
  }

  /// Cuenta regresiva 3‑2‑1 justo antes de que entre la primera nota, para
  /// prepararte. No aparece si no hay intro (la voz entra enseguida).
  Widget _buildCountIn() {
    return AnimatedBuilder(
      animation: _ticker,
      builder: (context, _) {
        final c = widget.controller;
        if (!c.running || c.notes.isEmpty) return const SizedBox.shrink();
        final pos = c.clock;
        final remain = c.notes.first.startT - pos;
        if (remain <= 0 || remain > 3.5) return const SizedBox.shrink();
        final n = remain.ceil().clamp(1, 3);
        return Center(
          child: Container(
            width: 120,
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$n',
              style: const TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PitchRollPainter extends CustomPainter {
  _PitchRollPainter({
    required this.controller,
    required Listenable repaint,
    required this.lyrics,
    required this.barBase,
    required this.lit,
    required this.glow,
    required this.nowLine,
    required this.onPitch,
    required this.offPitch,
  }) : super(repaint: repaint);

  final KaraokeController controller;
  final Lyrics? lyrics;
  final Color barBase;
  final Color lit;
  final Color glow;
  final Color nowLine;
  final Color onPitch;
  final Color offPitch;

  // Pixeles por segundo (velocidad del scroll) y posición de la línea "ahora".
  static const double pps = 130.0;
  static const double nowFrac = 0.28;

  @override
  void paint(Canvas canvas, Size size) {
    final notes = controller.notes;
    if (notes.isEmpty) return;

    // Rango vertical de notas (con margen), para mapear MIDI -> y.
    var minMidi = notes.first.midi.toDouble();
    var maxMidi = minMidi;
    for (final n in notes) {
      minMidi = math.min(minMidi, n.midi.toDouble());
      maxMidi = math.max(maxMidi, n.midi.toDouble());
    }
    minMidi -= 2.5;
    maxMidi += 2.5;
    final range = math.max(1.0, maxMidi - minMidi);

    double yFor(double midi) => size.height * (1.0 - (midi - minMidi) / range);

    final pos = controller.clock;
    final nowX = size.width * nowFrac;
    double xFor(double t) => nowX + (t - pos) * pps;

    // Alto de cada barra (un poco menos que el espacio de un semitono).
    final barH = (size.height / range * 0.7).clamp(9.0, 22.0);

    final basePaint = Paint()..color = barBase;
    final litPaint = Paint()..color = lit;

    // Barras de la melodía.
    for (var i = 0; i < notes.length; i++) {
      final n = notes[i];
      final x0 = xFor(n.startT);
      final x1 = xFor(n.endT);
      if (x1 < -4 || x0 > size.width + 4) continue;
      final y = yFor(n.midi.toDouble());
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x0, y - barH / 2, math.max(2.0, x1 - x0), barH),
        Radius.circular(barH / 2),
      );
      canvas.drawRRect(rect, basePaint);

      // Tramo acertado, marcado en su lugar real (desde dónde empezamos a
      // cantar la nota hasta dónde llegamos), aunque hayamos entrado tarde.
      final cs = i < controller.coverStart.length ? controller.coverStart[i] : 1.0;
      final ce = i < controller.coverEnd.length ? controller.coverEnd[i] : 0.0;
      if (ce > cs) {
        final xa = x0 + (x1 - x0) * cs;
        final xb = x0 + (x1 - x0) * ce;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(xa, y - barH / 2, math.max(2.0, xb - xa), barH),
            Radius.circular(barH / 2),
          ),
          litPaint,
        );
      }

      if (controller.activeNote == i) {
        canvas.drawRRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = glow,
        );
      }

      final cx = (x0 + x1) / 2;
      // Letra (sílaba) PEGADA arriba de la barra, en amarillo brillante, para no
      // tener que separar la vista de las barras.
      final syl = _syllableAt(n.startT);
      if (syl != null && syl.isNotEmpty) {
        _label(canvas, syl, Offset(cx, y - barH / 2 - 20), _lyricColor, 19);
      }
      // Nombre de la nota (Do-Re-Mi) DEBAJO de la barra, con el color del teclado.
      final fs = (barH * 1.0).clamp(13.0, 20.0);
      _label(
        canvas,
        _noteName(n.midi),
        Offset(cx, y + barH / 2 + fs * 0.7),
        kNoteColors[n.midi % 12],
        fs,
      );
    }

    // Línea "ahora".
    canvas.drawLine(
      Offset(nowX, 0),
      Offset(nowX, size.height),
      Paint()
        ..color = nowLine
        ..strokeWidth = 2,
    );

    // Tu voz: barrita en la línea "ahora", a la altura de tu afinación.
    final sung = controller.livePitch;
    if (sung != null) {
      final idx = controller.activeNote;
      double disp = sung;
      var hit = false;
      if (idx != null) {
        // Plegamos a la octava del objetivo para que no salte de octava.
        disp = notes[idx].midi + octaveFoldedDiff(sung, notes[idx].midi);
        hit =
            (disp - notes[idx].midi).abs() <=
            KaraokeController.onPitchTolerance;
      }
      disp = disp.clamp(minMidi, maxMidi);
      final y = yFor(disp);
      final color = hit ? onPitch : offPitch.withValues(alpha: 0.75);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(nowX - 16, y - barH / 2, 32, barH),
          Radius.circular(barH / 2),
        ),
        Paint()..color = color,
      );
    }
  }

  static const Color _lyricColor = Color(0xFFFFD24A);

  /// Sílaba de la letra que corresponde al instante [t] (arranque de la nota).
  String? _syllableAt(double t) {
    final ly = lyrics;
    if (ly == null) return null;
    for (final line in ly.lines) {
      if (t < line.start || t > line.end) continue;
      for (final w in line.words) {
        if (t >= w.start && t < w.end) return w.text;
      }
    }
    return null;
  }

  void _label(
    Canvas canvas,
    String s,
    Offset center,
    Color color,
    double fontSize,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _PitchRollPainter oldDelegate) => true;
}
