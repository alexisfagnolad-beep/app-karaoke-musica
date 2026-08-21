import 'package:flutter/material.dart';

/// Mascota simpática de la app: una carita redonda con una nota musical,
/// para darle una identidad amigable para chicos.
class MascotFace extends StatelessWidget {
  const MascotFace({super.key, this.size = 52, this.happy = true});

  final double size;
  final bool happy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _MascotPainter(happy)),
    );
  }
}

class _MascotPainter extends CustomPainter {
  _MascotPainter(this.happy);
  final bool happy;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final c = Offset(w / 2, h * 0.56);
    final r = w * 0.42;

    // Cara.
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFFFE082));
    // Cachetitos.
    final cheek = Paint()..color = const Color(0x55FF7043);
    canvas.drawCircle(
      Offset(c.dx - r * 0.55, c.dy + r * 0.15),
      r * 0.16,
      cheek,
    );
    canvas.drawCircle(
      Offset(c.dx + r * 0.55, c.dy + r * 0.15),
      r * 0.16,
      cheek,
    );
    // Ojos.
    final eye = Paint()..color = const Color(0xFF3A2E1E);
    canvas.drawCircle(Offset(c.dx - r * 0.32, c.dy - r * 0.12), r * 0.11, eye);
    canvas.drawCircle(Offset(c.dx + r * 0.32, c.dy - r * 0.12), r * 0.11, eye);
    // Sonrisa.
    final smile = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.12
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF3A2E1E);
    final rect = Rect.fromCircle(
      center: Offset(c.dx, c.dy + r * 0.18),
      radius: r * 0.42,
    );
    canvas.drawArc(rect, happy ? 0.2 : 3.34, happy ? 2.74 : 2.6, false, smile);

    // Notita musical arriba.
    final note = Paint()..color = const Color(0xFF7C4DFF);
    final nc = Offset(w * 0.78, h * 0.2);
    canvas.drawOval(
      Rect.fromCenter(center: nc, width: r * 0.34, height: r * 0.26),
      note,
    );
    canvas.drawRect(
      Rect.fromLTWH(nc.dx + r * 0.12, nc.dy - r * 0.5, r * 0.07, r * 0.55),
      note,
    );
  }

  @override
  bool shouldRepaint(covariant _MascotPainter oldDelegate) => false;
}
