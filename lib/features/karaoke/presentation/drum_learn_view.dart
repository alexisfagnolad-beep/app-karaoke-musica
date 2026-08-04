import 'package:flutter/material.dart';

import '../data/karaoke_controller.dart';

const Color _kHit = Color(0xFF4AE3B5);

/// Una pieza de la batería dibujada. [band] la asocia a lo que la app detecta
/// (0 grave/bombo, 1 medio/redoblante, 2 agudo/hi-hat); varias piezas pueden
/// compartir banda. [x],[y] son fracción del alto/ancho; [size] fracción del
/// ancho. [cymbal] la dibuja como platillo (óvalo).
class DrumPieceDef {
  final String id;
  final String label;
  final int band;
  final double x;
  final double y;
  final double size;
  final bool cymbal;
  final Color color;

  const DrumPieceDef(
    this.id,
    this.label,
    this.band, {
    required this.x,
    required this.y,
    required this.size,
    required this.color,
    this.cymbal = false,
  });
}

/// Catálogo de piezas disponibles para armar la batería. Distribución tipo
/// batería real (vista de frente): redoblante a la izquierda, hi-hat, toms
/// arriba con el crash entre medio, bombo grande al centro, ride a la derecha, y
/// chancha + bombo legüero a la derecha del todo. Cada pieza tiene su color, y
/// las notas que caen usan ese mismo color (más didáctico).
const List<DrumPieceDef> kDrumPieces = [
  DrumPieceDef('crash', 'Platillo (crash)', 2,
      x: 0.50, y: 0.61, size: 0.10, cymbal: true, color: Color(0xFFAB47BC)),
  DrumPieceDef('ride', 'Ride', 2,
      x: 0.82, y: 0.62, size: 0.11, cymbal: true, color: Color(0xFF42A5F5)),
  DrumPieceDef('hihat', 'Hi-hat', 2,
      x: 0.28, y: 0.68, size: 0.09, cymbal: true, color: Color(0xFF4FC3F7)),
  DrumPieceDef('tom1', 'Tom 1', 1,
      x: 0.42, y: 0.71, size: 0.058, color: Color(0xFF66BB6A)),
  DrumPieceDef('tom2', 'Tom 2', 1,
      x: 0.58, y: 0.71, size: 0.058, color: Color(0xFF26C6DA)),
  DrumPieceDef('chancha', 'Chancha', 1,
      x: 0.74, y: 0.87, size: 0.068, color: Color(0xFFFF8A3D)),
  DrumPieceDef('snare', 'Redoblante', 1,
      x: 0.15, y: 0.87, size: 0.075, color: Color(0xFFFFCA28)),
  DrumPieceDef('kick', 'Bombo', 0,
      x: 0.50, y: 0.90, size: 0.11, color: Color(0xFFEF5350)),
  DrumPieceDef('leguero', 'Bombo legüero', 0,
      x: 0.90, y: 0.90, size: 0.078, color: Color(0xFF8D6E63)),
];

/// Piezas por defecto (las 3 que la app distingue por sonido).
const Set<String> kDefaultPieces = {'kick', 'snare', 'hihat'};

/// Pieza canónica de cada banda (0 bombo, 1 redoblante, 2 hi-hat).
String _canonId(int band) => const ['kick', 'snare', 'hihat'][band.clamp(0, 2)];

DrumPieceDef? _pieceDef(String id) {
  for (final d in kDrumPieces) {
    if (d.id == id) return d;
  }
  return null;
}

/// Vista de batería estilo Guitar Hero (horizontal): notas cayendo por
/// carriles que terminan en una batería dibujada abajo. Cuando la nota llega,
/// el chico golpea esa parte real; la parte se ilumina en la app.
class DrumLearnView extends StatefulWidget {
  const DrumLearnView({
    super.key,
    required this.controller,
    this.pieces = kDefaultPieces,
  });

  final KaraokeController controller;

  /// Piezas elegidas para dibujar (ids del catálogo [kDrumPieces]).
  final Set<String> pieces;

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
        final size = Size(cons.maxWidth, cons.maxHeight);
        // Listener (no GestureDetector): permite golpear DOS o más piezas a la
        // vez (un dedo por pieza).
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => _onTap(e.localPosition, size),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _DrumLearnPainter(
                  widget.controller,
                  _ticker,
                  widget.pieces,
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

  /// Tocar la pieza dibujada MÁS CERCANA al toque: suena su propio sonido.
  void _onTap(Offset p, Size size) {
    String? bestId;
    var bestBand = 0;
    var best = double.infinity;
    for (final def in kDrumPieces) {
      if (!widget.pieces.contains(def.id)) continue;
      final cx = def.x * size.width;
      final cy = def.y * size.height;
      final d = (cx - p.dx) * (cx - p.dx) + (cy - p.dy) * (cy - p.dy);
      if (d < best) {
        best = d;
        bestId = def.id;
        bestBand = def.band;
      }
    }
    if (bestId != null) widget.controller.tapPiece(bestId, bestBand);
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
  _DrumLearnPainter(this.c, Listenable repaint, this.pieces)
    : super(repaint: repaint);

  final KaraokeController c;
  final Set<String> pieces;

  // En "Para empezar" (play-along) las notas caen más despacio y se leen mejor.
  double get lookahead => c.playAlong ? 3.0 : 2.2;

  // band -> carril (0 bombo=centro, 1 redoblante=izq, 2 hi-hat=der).
  static const List<Color> colors = [
    Color(0xFFEF5350), // bombo rojo
    Color(0xFFFFCA28), // redoblante amarillo
    Color(0xFF29B6F6), // hi-hat celeste
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final hits = c.rhythmRef?.hits ?? const [];
    // Fondo transparente: el degradé lindo va detrás (en la pantalla).

    final hitLine = size.height * 0.56;
    final pps = hitLine / lookahead;
    final pos = c.clock;

    // Carril por banda (fallback si la pieza no está dibujada).
    final laneX = <int, double>{
      1: size.width * 0.28,
      0: size.width * 0.5,
      2: size.width * 0.72,
    };

    double yForTime(double t) => hitLine - (t - pos) * pps;

    // Notas cayendo: cada una cae hacia SU pieza (tom1, crash, …) y brilla solo
    // si esa pieza fue acertada al pasar por la línea.
    for (final h in hits) {
      final y = yForTime(h.t);
      if (y < -30 || y > hitLine + 4) continue;
      final band = h.band.clamp(0, 2);
      final pieceId = h.piece ?? _canonId(band);
      final def = _pieceDef(pieceId);
      final x = (def != null && pieces.contains(pieceId))
          ? def.x * size.width
          : laneX[band]!;
      final r = (size.width * 0.022).clamp(10.0, 26.0);
      final cy = y.clamp(0.0, hitLine);
      final ht = c.lastPieceHitT[pieceId] ?? -1e9;
      final glow = (pos - ht) < 0.25 && (h.t - pos).abs() < 0.25;
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
        Paint()..color = glow ? _kHit : (def?.color ?? colors[band]),
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

    // Línea "golpeá ahora". Destella al ESCUCHAR un golpe (aunque sea fuera de
    // tiempo), para confirmar que el micrófono te está tomando.
    final heard = c.lastUserHitT >= 0 && (pos - c.lastUserHitT) < 0.15;
    if (heard) {
      canvas.drawLine(
        Offset(0, hitLine),
        Offset(size.width, hitLine),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 6
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    canvas.drawLine(
      Offset(0, hitLine),
      Offset(size.width, hitLine),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..strokeWidth = 2,
    );

    // --- Batería dibujada abajo ---
    _drawKit(canvas, size, pos);

    // Indicador de micrófono (nivel), para ver que está escuchando.
    if (c.micPractice) _micMeter(canvas, size, c.micLevel, c.listening);

    // Cartel rápido de "¡Bien!" al acertar.
    if (c.lastHitT >= 0 && (pos - c.lastHitT) >= 0 && (pos - c.lastHitT) < 0.6) {
      _flash(canvas, size, '¡Bien! ✨');
    }
  }

  void _micMeter(Canvas canvas, Size size, double level, bool listening) {
    final w = size.width * 0.34;
    final x = size.width * 0.5 - w / 2;
    final y = size.height * 0.05;
    const h = 10.0;
    final bg = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, w, h),
      const Radius.circular(5),
    );
    canvas.drawRRect(bg, Paint()..color = Colors.white24);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w * level.clamp(0.0, 1.0), h),
        const Radius.circular(5),
      ),
      Paint()..color = level > 0.5 ? _kHit : const Color(0xFFFFCA28),
    );
    final tp = TextPainter(
      text: TextSpan(
        text: listening ? '🎤 Escuchando tu instrumento…' : '🎤 micrófono',
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width * 0.5 - tp.width / 2, y - 18));
  }

  void _drawKit(Canvas canvas, Size size, double pos) {
    final w = size.width;
    final h = size.height;
    // Dibuja las piezas elegidas. Cada pieza se ilumina SOLO si esa pieza fue
    // acertada recién (por su propio golpe), no todas las de la misma banda.
    for (final def in kDrumPieces) {
      if (!pieces.contains(def.id)) continue;
      final center = Offset(w * def.x, h * def.y);
      final ht = c.lastPieceHitT[def.id] ?? -1e9;
      final on = (pos - ht) < 0.22;
      final color = def.color;
      if (def.cymbal) {
        _cymbal(canvas, center, w * def.size, color, on);
      } else {
        _drum(canvas, center, w * def.size, color, on);
      }
      _label(canvas, def.label, center);
    }
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
