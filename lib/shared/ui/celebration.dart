import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_ui.dart';

/// Pantalla de resultado festiva y amigable para chicos: carita, estrellas
/// (1‑2‑3), puntaje grande y confeti cuando sale bien.
class Celebration extends StatefulWidget {
  const Celebration({
    super.key,
    required this.score,
    required this.onBack,
    required this.onRetry,
    this.details = const [],
  });

  /// Puntaje 0..100.
  final double score;
  final VoidCallback onBack;
  final VoidCallback onRetry;

  /// Filas de estadística opcionales (barras de detalle).
  final List<Widget> details;

  @override
  State<Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<Celebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();
  late final List<_Confetti> _confetti;

  int get _stars => widget.score >= 90
      ? 3
      : widget.score >= 70
      ? 2
      : widget.score >= 45
      ? 1
      : 0;

  String get _face => widget.score >= 75
      ? '😄'
      : widget.score >= 50
      ? '🙂'
      : '💪';

  String get _headline => widget.score >= 90
      ? '¡Genial!'
      : widget.score >= 75
      ? '¡Muy bien!'
      : widget.score >= 50
      ? '¡Bien!'
      : '¡A practicar!';

  @override
  void initState() {
    super.initState();
    final rnd = math.Random();
    _confetti = List.generate(
      widget.score >= 55 ? 40 : 0,
      (_) => _Confetti(
        x: rnd.nextDouble(),
        delay: rnd.nextDouble(),
        speed: 0.6 + rnd.nextDouble() * 0.8,
        size: 6 + rnd.nextDouble() * 8,
        color: _palette[rnd.nextInt(_palette.length)],
        rot: rnd.nextDouble() * 6.28,
      ),
    );
  }

  static const _palette = [
    AppColors.pink,
    AppColors.teal,
    AppColors.purple,
    AppColors.orange,
    AppColors.blue,
    Color(0xFFFFEE58),
  ];

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Horizontal (juegos de piano/batería): todo más compacto y en fila, para
    // que entre completo sin scrollear.
    final landscape = size.width > size.height;
    return Stack(
      children: [
        if (_confetti.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _ConfettiPainter(_confetti, _anim)),
            ),
          ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: landscape ? _landscape(context) : _portrait(context),
          ),
        ),
      ],
    );
  }

  Widget _buttons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton(
          onPressed: widget.onBack,
          child: const Text('Volver'),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: widget.onRetry,
          icon: const Icon(Icons.replay),
          label: const Text('Otra vez'),
        ),
      ],
    );
  }

  Widget _portrait(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_face, style: const TextStyle(fontSize: 72)),
        const SizedBox(height: 4),
        Text(
          _headline,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _Stars(count: _stars, anim: _anim),
        const SizedBox(height: 16),
        ScoreRing(score: widget.score, size: 150),
        if (widget.details.isNotEmpty) ...[
          const SizedBox(height: 20),
          ...widget.details,
        ],
        const SizedBox(height: 28),
        _buttons(),
      ],
    );
  }

  Widget _landscape(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_face, style: const TextStyle(fontSize: 52)),
            Text(
              _headline,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _Stars(count: _stars, anim: _anim),
          ],
        ),
        const SizedBox(width: 28),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScoreRing(score: widget.score, size: 104),
            const SizedBox(height: 16),
            _buttons(),
          ],
        ),
      ],
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.count, required this.anim});

  final int count;
  final Animation<double> anim;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final on = i < count;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(
            on ? Icons.star_rounded : Icons.star_outline_rounded,
            color: on ? const Color(0xFFFFCA28) : Colors.white24,
            size: i == 1 ? 68 : 56,
          ),
        );
      }),
    );
  }
}

class _Confetti {
  _Confetti({
    required this.x,
    required this.delay,
    required this.speed,
    required this.size,
    required this.color,
    required this.rot,
  });
  final double x;
  final double delay;
  final double speed;
  final double size;
  final Color color;
  final double rot;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.parts, this.anim) : super(repaint: anim);

  final List<_Confetti> parts;
  final Animation<double> anim;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in parts) {
      final t = (anim.value + p.delay) % 1.0;
      final y = (t * p.speed * size.height * 1.4) % (size.height + 20) - 10;
      final x = p.x * size.width + math.sin((t + p.delay) * 6.28) * 12;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rot + t * 6.28);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.6,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = p.color,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
