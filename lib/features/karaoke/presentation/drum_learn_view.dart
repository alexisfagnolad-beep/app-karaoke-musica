import 'package:flutter/material.dart';

import '../data/karaoke_controller.dart';

/// Vista de batería estilo Guitar Hero (horizontal): notas cayendo por
/// carriles que terminan en una batería dibujada abajo. Cuando la nota llega,
/// el chico golpea esa parte real; la parte se ilumina en la app.
class DrumLearnView extends StatefulWidget {
  const DrumLearnView({super.key, required this.controller});

  final KaraokeController controller;

  @override
  State<DrumLearnView> createState() => _DrumLearnViewState();
}

class _DrumLearnViewState extends State<DrumLearnView>
    with SingleTickerProviderStateMixin {
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
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: _DrumLearnPainter(widget.controller, _ticker),
          size: Size.infinite,
        ),
        _buildCountIn(),
      ],
    );
  }

  Widget _buildCountIn() {
    return AnimatedBuilder(
      animation: _ticker,
      builder: (context, _) {
        final c = widget.controller;
        final hits = c.rhythmRef?.hits ?? const [];
        if (!c.running || hits.isEmpty) return const SizedBox.shrink();
        final pos = c.player.position.inMilliseconds / 1000.0;
        final remain = hits.first.t - pos;
        if (remain <= 0 || remain > 3.5) return const SizedBox.shrink();
        final n = remain.ceil().clamp(1, 3);
        return Align(
          alignment: const Alignment(0, -0.55),
          child: Container(
            width: 100,
            height: 100,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$n',
              style: const TextStyle(
                fontSize: 56,
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

class _DrumLearnPainter extends CustomPainter {
  _DrumLearnPainter(this.c, Listenable repaint) : super(repaint: repaint);

  final KaraokeController c;

  static const double lookahead = 2.2;

  // band -> carril (0 bombo=centro, 1 redoblante=izq, 2 hi-hat=der).
  static const List<Color> colors = [
    Color(0xFFEF5350), // bombo rojo
    Color(0xFFFFCA28), // redoblante amarillo
    Color(0xFF29B6F6), // hi-hat celeste
  ];
  static const List<String> names = ['Bombo', 'Redob.', 'Hi-hat'];

  @override
  void paint(Canvas canvas, Size size) {
    final hits = c.rhythmRef?.hits ?? const [];
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0F0E16),
    );

    final hitLine = size.height * 0.56;
    final pps = hitLine / lookahead;
    final pos = c.player.position.inMilliseconds / 1000.0;

    // Posición horizontal de cada carril (redoblante izq, bombo centro, hi der).
    final laneX = <int, double>{
      1: size.width * 0.28,
      0: size.width * 0.5,
      2: size.width * 0.72,
    };

    double yForTime(double t) => hitLine - (t - pos) * pps;

    // Carriles (guías).
    final laneGuide = Paint()..color = Colors.white.withValues(alpha: 0.06);
    for (final x in laneX.values) {
      canvas.drawLine(Offset(x, 0), Offset(x, hitLine), laneGuide);
    }

    // Qué parte está activa (golpe llegando ~ahora).
    final active = <bool>[false, false, false];
    for (final h in hits) {
      final band = h.band.clamp(0, 2);
      if ((h.t - pos).abs() < 0.09) active[band] = true;
    }

    // Notas cayendo.
    for (final h in hits) {
      final y = yForTime(h.t);
      if (y < -30 || y > hitLine + 4) continue;
      final band = h.band.clamp(0, 2);
      final x = laneX[band]!;
      final r = (size.width * 0.022).clamp(10.0, 26.0);
      canvas.drawCircle(
        Offset(x, y.clamp(0.0, hitLine)),
        r,
        Paint()..color = colors[band],
      );
      canvas.drawCircle(
        Offset(x, y.clamp(0.0, hitLine)),
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white.withValues(alpha: 0.55),
      );
    }

    // Línea "golpeá ahora".
    canvas.drawLine(
      Offset(0, hitLine),
      Offset(size.width, hitLine),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..strokeWidth = 2,
    );

    // Flash del golpe del usuario.
    final userFlash = c.lastUserHitT >= 0 && (pos - c.lastUserHitT) < 0.12;

    // --- Batería dibujada abajo ---
    _drawKit(canvas, size, hitLine, active, userFlash);
  }

  void _drawKit(
    Canvas canvas,
    Size size,
    double top,
    List<bool> active,
    bool userFlash,
  ) {
    final w = size.width;
    final h = size.height;

    // Platillos decorativos (crash) arriba a los costados.
    _cymbal(
      canvas,
      Offset(w * 0.14, top + (h - top) * 0.18),
      w * 0.11,
      const Color(0xFF3A3A46),
      false,
    );
    _cymbal(
      canvas,
      Offset(w * 0.86, top + (h - top) * 0.18),
      w * 0.11,
      const Color(0xFF3A3A46),
      false,
    );

    // Hi-hat (carril 2, derecha).
    _cymbal(
      canvas,
      Offset(w * 0.72, top + (h - top) * 0.30),
      w * 0.12,
      colors[2],
      active[2] || userFlash,
    );
    _label(canvas, names[2], Offset(w * 0.72, top + (h - top) * 0.30));

    // Redoblante (carril 1, izquierda).
    _drum(
      canvas,
      Offset(w * 0.28, h * 0.82),
      w * 0.075,
      colors[1],
      active[1] || userFlash,
    );
    _label(canvas, names[1], Offset(w * 0.28, h * 0.82));

    // Bombo (carril 0, centro, grande).
    _drum(
      canvas,
      Offset(w * 0.5, h * 0.86),
      w * 0.11,
      colors[0],
      active[0] || userFlash,
    );
    _label(canvas, names[0], Offset(w * 0.5, h * 0.86));
  }

  void _drum(Canvas canvas, Offset c, double r, Color color, bool on) {
    canvas.drawCircle(
      c,
      r,
      Paint()..color = on ? color : Color.lerp(color, Colors.black, 0.55)!,
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = on ? 5 : 3
        ..color = on ? Colors.white : Colors.white24,
    );
  }

  void _cymbal(Canvas canvas, Offset c, double rx, Color color, bool on) {
    final rect = Rect.fromCenter(center: c, width: rx * 2, height: rx * 0.7);
    canvas.drawOval(
      rect,
      Paint()..color = on ? color : Color.lerp(color, Colors.black, 0.5)!,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = on ? 4 : 2
        ..color = on ? Colors.white : Colors.white24,
    );
  }

  void _label(Canvas canvas, String s, Offset center) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
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
  bool shouldRepaint(covariant _DrumLearnPainter oldDelegate) => true;
}
