import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Fondo lindo para el karaoke: un degradé que se mueve suave y notas musicales
/// flotando hacia arriba. Puramente decorativo (no interfiere con los toques).
class KaraokeBackdrop extends StatefulWidget {
  const KaraokeBackdrop({super.key});

  @override
  State<KaraokeBackdrop> createState() => _KaraokeBackdropState();
}

class _KaraokeBackdropState extends State<KaraokeBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();
  late final List<_Note> _notes;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random(7);
    const glyphs = ['♪', '♫', '♩', '★', '♬'];
    _notes = List.generate(
      16,
      (i) => _Note(
        x: rnd.nextDouble(),
        phase: rnd.nextDouble(),
        speed: 0.5 + rnd.nextDouble() * 0.9,
        size: 16 + rnd.nextDouble() * 22,
        glyph: glyphs[rnd.nextInt(glyphs.length)],
        sway: 0.02 + rnd.nextDouble() * 0.05,
      ),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          final t = _anim.value;
          // Degradé que "respira" moviendo el ángulo.
          final a = t * 2 * math.pi;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(math.cos(a), math.sin(a)),
                end: Alignment(-math.cos(a), -math.sin(a)),
                colors: const [
                  Color(0xFF3A1C71),
                  Color(0xFFD76D77),
                  Color(0xFF3B8DFF),
                ],
              ),
            ),
            child: CustomPaint(
              painter: _NotesPainter(_notes, t),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _Note {
  _Note({
    required this.x,
    required this.phase,
    required this.speed,
    required this.size,
    required this.glyph,
    required this.sway,
  });
  final double x;
  final double phase;
  final double speed;
  final double size;
  final String glyph;
  final double sway;
}

class _NotesPainter extends CustomPainter {
  _NotesPainter(this.notes, this.t);

  final List<_Note> notes;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final n in notes) {
      final prog = (t * n.speed + n.phase) % 1.0;
      final y = size.height * (1.0 - prog) - 10;
      final x =
          n.x * size.width + math.sin((prog + n.phase) * 6.28) * size.width * n.sway;
      final tp = TextPainter(
        text: TextSpan(
          text: n.glyph,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.16),
            fontSize: n.size,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(covariant _NotesPainter oldDelegate) => true;
}
