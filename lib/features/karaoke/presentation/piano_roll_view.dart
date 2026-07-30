import 'package:flutter/material.dart';

import '../data/karaoke_controller.dart';

/// Colores por nota (esquema tipo Boomwhackers, didáctico para chicos).
const List<Color> kNoteColors = [
  Color(0xFFEF5350), // Do  (C)  rojo
  Color(0xFFEC407A), // Do#
  Color(0xFFFFA726), // Re  (D)  naranja
  Color(0xFFFFCA28), // Re#
  Color(0xFFFFEE58), // Mi  (E)  amarillo
  Color(0xFF66BB6A), // Fa  (F)  verde
  Color(0xFF26A69A), // Fa#
  Color(0xFF29B6F6), // Sol (G)  celeste
  Color(0xFF42A5F5), // Sol#
  Color(0xFF5C6BC0), // La  (A)  índigo
  Color(0xFF7E57C2), // La#
  Color(0xFFAB47BC), // Si  (B)  violeta
];

const Map<int, String> _solfege = {
  0: 'Do',
  2: 'Re',
  4: 'Mi',
  5: 'Fa',
  7: 'Sol',
  9: 'La',
  11: 'Si',
};

const Set<int> _whitePc = {0, 2, 4, 5, 7, 9, 11};

/// Vista didáctica de piano: un teclado de colores abajo y las notas de la
/// melodía "cayendo" hacia la tecla que hay que tocar (estilo enseñar piano).
class PianoRollView extends StatefulWidget {
  const PianoRollView({super.key, required this.controller});

  final KaraokeController controller;

  @override
  State<PianoRollView> createState() => _PianoRollViewState();
}

class _PianoRollViewState extends State<PianoRollView>
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
            painter: _PianoPainter(widget.controller, _ticker),
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
        if (!c.running || c.notes.isEmpty) return const SizedBox.shrink();
        final pos = c.player.position.inMilliseconds / 1000.0;
        final remain = c.notes.first.startT - pos;
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

class _PianoPainter extends CustomPainter {
  _PianoPainter(this.c, Listenable repaint) : super(repaint: repaint);

  final KaraokeController c;

  static const double lookahead = 2.6; // segundos visibles cayendo.

  @override
  void paint(Canvas canvas, Size size) {
    final notes = c.notes;
    if (notes.isEmpty) return;

    // Rango de teclas: SOLO las que usa la canción (así el teclado no se llena
    // de teclas de más y las que hay quedan bien grandes). Con un semitono de
    // margen a cada lado y arrancando/terminando en tecla blanca.
    var minMidi = notes.first.midi;
    var maxMidi = notes.first.midi;
    for (final n in notes) {
      if (n.midi < minMidi) minMidi = n.midi;
      if (n.midi > maxMidi) maxMidi = n.midi;
    }
    var startMidi = minMidi - 1;
    while (!_whitePc.contains(startMidi % 12)) {
      startMidi--; // arrancar en una tecla blanca.
    }
    var endMidi = maxMidi + 1;
    while (!_whitePc.contains(endMidi % 12)) {
      endMidi++; // terminar en una tecla blanca.
    }
    // Techo de seguridad para melodías con rango enorme.
    if (endMidi - startMidi > 36) {
      final center = (minMidi + maxMidi) ~/ 2;
      startMidi = center - 18;
      while (!_whitePc.contains(startMidi % 12)) {
        startMidi--;
      }
      endMidi = center + 18;
      while (!_whitePc.contains(endMidi % 12)) {
        endMidi++;
      }
    }

    // Teclas blancas en el rango.
    final whites = <int>[];
    for (var m = startMidi; m <= endMidi; m++) {
      if (_whitePc.contains(m % 12)) whites.add(m);
    }
    if (whites.isEmpty) return;

    // Teclado más grande (más protagonismo, más didáctico).
    final keyboardH = (size.height * 0.40).clamp(120.0, 300.0);
    final hitLine = size.height - keyboardH;
    final whiteW = size.width / whites.length;
    final pps = hitLine / lookahead;
    final pos = c.player.position.inMilliseconds / 1000.0;

    double xForMidi(int midi) {
      if (_whitePc.contains(midi % 12)) {
        final i = whites.indexOf(midi);
        return i * whiteW + whiteW / 2;
      }
      // Negra: se ubica en el borde entre la blanca de abajo y la de arriba.
      final lower = midi - 1;
      final i = whites.indexOf(lower);
      return (i + 1) * whiteW;
    }

    // Nota objetivo activa ahora (para iluminar su tecla).
    int? activeMidi;
    for (final n in notes) {
      if (pos >= n.startT && pos < n.endT) {
        activeMidi = n.midi;
        break;
      }
    }

    double yForTime(double t) => hitLine - (t - pos) * pps;

    // --- Fondo del área de caída ---
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, hitLine),
      Paint()..color = const Color(0xFF14121C),
    );

    // Guías verticales tenues por cada tecla blanca.
    final guide = Paint()..color = Colors.white.withValues(alpha: 0.05);
    for (var i = 1; i < whites.length; i++) {
      canvas.drawLine(
        Offset(i * whiteW, 0),
        Offset(i * whiteW, hitLine),
        guide,
      );
    }

    // --- Notas cayendo ---
    for (final n in notes) {
      final top = yForTime(n.endT);
      final bottom = yForTime(n.startT);
      if (bottom < 0 || top > hitLine) continue;
      final b = bottom.clamp(0.0, hitLine);
      final tTop = top.clamp(-40.0, hitLine);
      final isBlack = !_whitePc.contains(n.midi % 12);
      final w = isBlack ? whiteW * 0.62 : whiteW * 0.86;
      final x = xForMidi(n.midi);
      final color = kNoteColors[n.midi % 12];
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTRB(x - w / 2, tTop, x + w / 2, b),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, Paint()..color = color.withValues(alpha: 0.92));
    }

    // Línea de "tocá ahora".
    canvas.drawLine(
      Offset(0, hitLine),
      Offset(size.width, hitLine),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..strokeWidth = 2,
    );

    // --- Teclado ---
    // Nota que está tocando el usuario (para marcarla).
    final sung = c.livePitch?.round();

    // Blancas: SIEMPRE con su color (como los stickers de colores que se pegan
    // en el piano real). Cuando la nota está activa, la tecla entera se pinta.
    for (var i = 0; i < whites.length; i++) {
      final midi = whites[i];
      final x = i * whiteW;
      final rect = Rect.fromLTWH(x + 1, hitLine, whiteW - 2, keyboardH);
      final active = activeMidi == midi;
      final color = kNoteColors[midi % 12];
      // Base blanca.
      canvas.drawRect(rect, Paint()..color = const Color(0xFFF7F7FA));
      // Franja de color abajo (el "sticker").
      final bandH = keyboardH * 0.4;
      final band = RRect.fromRectAndCorners(
        Rect.fromLTWH(
          x + 2,
          hitLine + keyboardH - bandH,
          whiteW - 4,
          bandH - 3,
        ),
        bottomLeft: const Radius.circular(6),
        bottomRight: const Radius.circular(6),
      );
      canvas.drawRRect(band, Paint()..color = color);
      // Activa: se pinta toda la tecla.
      if (active) {
        canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.55));
      }
      // Nombre Do-Re-Mi sobre la franja de color.
      _label(
        canvas,
        _solfege[midi % 12] ?? '',
        Offset(x + whiteW / 2, hitLine + keyboardH - bandH / 2 - 10),
        Colors.white,
        whiteW,
      );
      // Tecla que toca el usuario.
      if (sung == midi) {
        canvas.drawRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xFF4AE3B5),
        );
      }
    }

    // Negras (encima): también con su color, un poco más oscuro para
    // distinguirlas; activas se pintan a full.
    final blackH = keyboardH * 0.62;
    for (var m = startMidi; m <= endMidi; m++) {
      if (_whitePc.contains(m % 12)) continue;
      final x = xForMidi(m);
      final w = whiteW * 0.6;
      final active = activeMidi == m;
      final color = kNoteColors[m % 12];
      final rect = Rect.fromLTWH(x - w / 2, hitLine, w, blackH);
      final rr = RRect.fromRectAndCorners(
        rect,
        bottomLeft: const Radius.circular(5),
        bottomRight: const Radius.circular(5),
      );
      // Oscurecemos el color para que "sea" tecla negra pero se vea el color.
      final darker = Color.lerp(color, Colors.black, 0.45)!;
      canvas.drawRRect(rr, Paint()..color = active ? color : darker);
      if (sung == m) {
        canvas.drawRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xFF4AE3B5),
        );
      }
    }
  }

  void _label(
    Canvas canvas,
    String text,
    Offset center,
    Color color,
    double maxW,
  ) {
    if (text.isEmpty || maxW < 16) return;
    // Escala el nombre con el ancho de la tecla (grande cuando hay pocas).
    final fontSize = (maxW * 0.34).clamp(12.0, 22.0);
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy));
  }

  @override
  bool shouldRepaint(covariant _PianoPainter oldDelegate) => true;
}
