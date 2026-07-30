import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/karaoke_controller.dart';
import '../domain/scoring.dart';

/// Vista tipo karaoke (SingStar): la línea melódica dibujada como barras que
/// se desplazan de derecha a izquierda. Cuando cantás sobre la barra, se
/// ilumina; si desafinás, tu voz aparece como una barrita más tenue arriba
/// (agudo) o abajo (grave) de la nota objetivo.
class PitchRollView extends StatefulWidget {
  const PitchRollView({super.key, required this.controller});

  final KaraokeController controller;

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
      child: CustomPaint(
        painter: _PitchRollPainter(
          controller: widget.controller,
          repaint: _ticker,
          barBase: scheme.onSurface.withValues(alpha: 0.12),
          lit: const Color(0xFFE0457B),
          glow: const Color(0xFFFF7FB0),
          nowLine: scheme.onSurface.withValues(alpha: 0.25),
          onPitch: const Color(0xFF4AE3B5),
          offPitch: const Color(0xFFFFB74D),
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _PitchRollPainter extends CustomPainter {
  _PitchRollPainter({
    required this.controller,
    required Listenable repaint,
    required this.barBase,
    required this.lit,
    required this.glow,
    required this.nowLine,
    required this.onPitch,
    required this.offPitch,
  }) : super(repaint: repaint);

  final KaraokeController controller;
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

    final pos = controller.player.position.inMilliseconds / 1000.0;
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

      final litFrac = i < controller.noteLit.length
          ? controller.noteLit[i]
          : 0.0;
      if (litFrac > 0) {
        final fillW = math.max(2.0, (x1 - x0) * litFrac);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x0, y - barH / 2, fillW, barH),
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

  @override
  bool shouldRepaint(covariant _PitchRollPainter oldDelegate) => true;
}
