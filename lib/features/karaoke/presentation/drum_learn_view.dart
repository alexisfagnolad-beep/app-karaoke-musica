import 'package:flutter/material.dart';

import '../data/karaoke_controller.dart';

const Color _kHit = Color(0xFF4AE3B5);

/// Vista de batería estilo Guitar Hero (horizontal): notas cayendo por
/// carriles que terminan en una batería dibujada abajo. Cuando la nota llega,
/// el chico golpea esa parte real; la parte se ilumina en la app.
class DrumLearnView extends StatefulWidget {
  const DrumLearnView({
    super.key,
    required this.controller,
    this.fullKit = false,
  });

  final KaraokeController controller;

  /// true dibuja una batería completa (toms, crash, ride); false, un set simple.
  final bool fullKit;

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
    return LayoutBuilder(
      builder: (context, cons) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _onTap(d.localPosition.dx, cons.maxWidth),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _DrumLearnPainter(
                  widget.controller,
                  _ticker,
                  widget.fullKit,
                ),
                size: Size.infinite,
              ),
              _buildCountIn(),
            ],
          ),
        );
      },
    );
  }

  /// Tocar una pieza en pantalla: izquierda = redoblante, centro = bombo,
  /// derecha = hi-hat.
  void _onTap(double dx, double width) {
    final band = dx < width * 0.39 ? 1 : (dx < width * 0.61 ? 0 : 2);
    widget.controller.tapDrum(band);
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
  _DrumLearnPainter(this.c, Listenable repaint, this.fullKit)
    : super(repaint: repaint);

  final KaraokeController c;
  final bool fullKit;

  // En "Para empezar" (play-along) las notas caen más despacio y se leen mejor.
  double get lookahead => c.playAlong ? 3.0 : 2.2;

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
    final pos = c.clock;

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

    // Encendido de cada pieza: SOLO si acertaste (golpe virtual o físico) cerca
    // del objetivo. Si nadie toca, nada se ilumina (ni el kit ni la nota).
    final lit = <bool>[
      for (var i = 0; i < 3; i++)
        c.lastBandHitT[i] >= 0 && (pos - c.lastBandHitT[i]) < 0.22,
    ];

    // Notas cayendo (brillan solo si esa pieza fue acertada al pasar).
    for (final h in hits) {
      final y = yForTime(h.t);
      if (y < -30 || y > hitLine + 4) continue;
      final band = h.band.clamp(0, 2);
      final x = laneX[band]!;
      final r = (size.width * 0.022).clamp(10.0, 26.0);
      final cy = y.clamp(0.0, hitLine);
      final glow = lit[band] && (h.t - pos).abs() < 0.25;
      if (glow) {
        canvas.drawCircle(
          Offset(x, cy),
          r + 5,
          Paint()
            ..color = _kHit
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }
      canvas.drawCircle(
        Offset(x, cy),
        r,
        Paint()..color = glow ? _kHit : colors[band],
      );
      canvas.drawCircle(
        Offset(x, cy),
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

    // --- Batería dibujada abajo ---
    _drawKit(canvas, size, hitLine, lit);

    // Cartel rápido de "¡Bien!" al acertar.
    if (c.lastHitT >= 0 && (pos - c.lastHitT) >= 0 && (pos - c.lastHitT) < 0.6) {
      _flash(canvas, size, '¡Bien! ✨');
    }
  }

  void _drawKit(Canvas canvas, Size size, double top, List<bool> lit) {
    final w = size.width;
    final h = size.height;
    const grey = Color(0xFF3A3A46);

    if (fullKit) {
      // Batería completa (front view). Solo bombo/redoblante/hi-hat se
      // iluminan (son los que la IA distingue); el resto es decorativo.
      // Platillos.
      _cymbal(
        canvas,
        Offset(w * 0.20, top + (h - top) * 0.12),
        w * 0.11,
        grey,
        false,
      ); // crash
      _cymbal(
        canvas,
        Offset(w * 0.80, top + (h - top) * 0.10),
        w * 0.12,
        grey,
        false,
      ); // ride
      // Hi-hat (activo).
      _cymbal(
        canvas,
        Offset(w * 0.66, top + (h - top) * 0.28),
        w * 0.10,
        colors[2],
        lit[2],
      );
      _label(canvas, 'Hi-hat', Offset(w * 0.66, top + (h - top) * 0.28));
      // Toms (decorativos).
      _drum(canvas, Offset(w * 0.42, h * 0.72), w * 0.06, grey, false);
      _drum(canvas, Offset(w * 0.58, h * 0.72), w * 0.06, grey, false);
      _drum(
        canvas,
        Offset(w * 0.86, h * 0.80),
        w * 0.075,
        grey,
        false,
      ); // floor
      // Redoblante (activo).
      _drum(
        canvas,
        Offset(w * 0.28, h * 0.80),
        w * 0.07,
        colors[1],
        lit[1],
      );
      _label(canvas, 'Redob.', Offset(w * 0.28, h * 0.80));
      // Bombo (activo, grande, centro).
      _drum(
        canvas,
        Offset(w * 0.5, h * 0.88),
        w * 0.11,
        colors[0],
        lit[0],
      );
      _label(canvas, 'Bombo', Offset(w * 0.5, h * 0.88));
      return;
    }

    // Set simple: 3 piezas grandes.
    _cymbal(
      canvas,
      Offset(w * 0.14, top + (h - top) * 0.18),
      w * 0.11,
      grey,
      false,
    );
    _cymbal(
      canvas,
      Offset(w * 0.86, top + (h - top) * 0.18),
      w * 0.11,
      grey,
      false,
    );
    _cymbal(
      canvas,
      Offset(w * 0.72, top + (h - top) * 0.30),
      w * 0.12,
      colors[2],
      lit[2],
    );
    _label(canvas, names[2], Offset(w * 0.72, top + (h - top) * 0.30));
    _drum(
      canvas,
      Offset(w * 0.28, h * 0.82),
      w * 0.075,
      colors[1],
      lit[1],
    );
    _label(canvas, names[1], Offset(w * 0.28, h * 0.82));
    _drum(
      canvas,
      Offset(w * 0.5, h * 0.86),
      w * 0.11,
      colors[0],
      lit[0],
    );
    _label(canvas, names[0], Offset(w * 0.5, h * 0.86));
  }

  void _drum(Canvas canvas, Offset c, double r, Color color, bool on) {
    if (on) {
      // Brillo fuerte al acertar.
      canvas.drawCircle(
        c,
        r + 8,
        Paint()
          ..color = _kHit
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }
    canvas.drawCircle(
      c,
      r,
      Paint()..color = on ? _kHit : Color.lerp(color, Colors.black, 0.55)!,
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
    if (on) {
      canvas.drawOval(
        Rect.fromCenter(center: c, width: rx * 2.3, height: rx * 0.9),
        Paint()
          ..color = _kHit
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }
    canvas.drawOval(
      rect,
      Paint()..color = on ? _kHit : Color.lerp(color, Colors.black, 0.5)!,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = on ? 4 : 2
        ..color = on ? Colors.white : Colors.white24,
    );
  }

  void _flash(Canvas canvas, Size size, String s) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: const TextStyle(
          color: _kHit,
          fontSize: 30,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, size.height * 0.1));
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
