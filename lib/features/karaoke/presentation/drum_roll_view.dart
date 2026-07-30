import 'package:flutter/material.dart';

import '../data/karaoke_controller.dart';

/// Vista didáctica de batería: 3 carriles (bombo / redoblante / hi-hat) con
/// pads de colores abajo y los golpes "cayendo" hacia el pad. El pad se
/// enciende cuando el golpe llega a la línea, y parpadea cuando golpeás vos.
class DrumRollView extends StatefulWidget {
  const DrumRollView({super.key, required this.controller});

  final KaraokeController controller;

  @override
  State<DrumRollView> createState() => _DrumRollViewState();
}

class _DrumRollViewState extends State<DrumRollView>
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _DrumPainter(widget.controller, _ticker),
            size: Size.infinite,
          ),
          _buildCountIn(),
        ],
      ),
    );
  }

  Widget _buildCountIn() {
    return AnimatedBuilder(
      animation: _ticker,
      builder: (context, _) {
        final c = widget.controller;
        final hits = c.rhythmRef?.hits ?? const [];
        if (!c.running || hits.isEmpty) return const SizedBox.shrink();
        final pos = c.clock;
        final remain = hits.first.t - pos;
        if (remain <= 0 || remain > 3.5) return const SizedBox.shrink();
        final n = remain.ceil().clamp(1, 3);
        return Align(
          alignment: const Alignment(0, -0.4),
          child: Container(
            width: 110,
            height: 110,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$n',
              style: const TextStyle(
                fontSize: 64,
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

class _DrumPainter extends CustomPainter {
  _DrumPainter(this.c, Listenable repaint) : super(repaint: repaint);

  final KaraokeController c;

  static const double lookahead = 2.4;
  static const List<Color> laneColors = [
    Color(0xFFEF5350), // Bombo (grave) rojo
    Color(0xFFFFCA28), // Redoblante (medio) amarillo
    Color(0xFF29B6F6), // Hi-hat (agudo) celeste
  ];
  static const List<String> laneNames = ['Bombo', 'Redob.', 'Hi-hat'];

  @override
  void paint(Canvas canvas, Size size) {
    final hits = c.rhythmRef?.hits ?? const [];
    final padH = (size.height * 0.22).clamp(70.0, 160.0);
    final hitLine = size.height - padH;
    final laneW = size.width / 3;
    final pps = hitLine / lookahead;
    final pos = c.clock;

    double xForLane(int b) => b * laneW + laneW / 2;
    double yForTime(double t) => hitLine - (t - pos) * pps;

    // Fondo.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, hitLine),
      Paint()..color = const Color(0xFF14121C),
    );
    // Separadores de carril.
    final sep = Paint()..color = Colors.white.withValues(alpha: 0.06);
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(Offset(i * laneW, 0), Offset(i * laneW, hitLine), sep);
    }

    // Qué pads están "activos" (un golpe llegando a la línea ~ahora).
    final active = <bool>[false, false, false];
    for (final h in hits) {
      final y = yForTime(h.t);
      final band = h.band.clamp(0, 2);
      if ((h.t - pos).abs() < 0.09) active[band] = true;
      if (y < -30 || y > hitLine + 4) continue;
      final x = xForLane(band);
      final r = (laneW * 0.3).clamp(12.0, 44.0);
      final color = laneColors[band];
      // "Golpe" cayendo: círculo con halo.
      canvas.drawCircle(
        Offset(x, y.clamp(0.0, hitLine)),
        r,
        Paint()..color = color.withValues(alpha: 0.9),
      );
      canvas.drawCircle(
        Offset(x, y.clamp(0.0, hitLine)),
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white.withValues(alpha: 0.5),
      );
    }

    // Línea de "golpeá ahora".
    canvas.drawLine(
      Offset(0, hitLine),
      Offset(size.width, hitLine),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.65)
        ..strokeWidth = 2,
    );

    // Flash cuando el usuario golpea (cualquier pad).
    final userFlash = c.lastUserHitT >= 0 && (pos - c.lastUserHitT) < 0.12;

    // Pads abajo.
    for (var b = 0; b < 3; b++) {
      final rect = Rect.fromLTWH(
        b * laneW + 6,
        hitLine + 6,
        laneW - 12,
        padH - 12,
      );
      final rr = RRect.fromRectAndRadius(rect, const Radius.circular(14));
      final on = active[b];
      canvas.drawRRect(
        rr,
        Paint()
          ..color = on ? laneColors[b] : laneColors[b].withValues(alpha: 0.25),
      );
      if (userFlash) {
        canvas.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..color = Colors.white,
        );
      }
      _label(
        canvas,
        laneNames[b],
        Offset(b * laneW + laneW / 2, hitLine + padH / 2 - 8),
        Colors.white,
        laneW,
      );
    }
  }

  void _label(
    Canvas canvas,
    String text,
    Offset center,
    Color color,
    double maxW,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy));
  }

  @override
  bool shouldRepaint(covariant _DrumPainter oldDelegate) => true;
}
