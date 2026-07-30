import 'package:flutter/material.dart';

import '../data/karaoke_controller.dart';
import 'piano_roll_view.dart' show kNoteColors;

const Set<int> _whitePc = {0, 2, 4, 5, 7, 9, 11};
const Map<int, String> _solfege = {
  0: 'Do',
  2: 'Re',
  4: 'Mi',
  5: 'Fa',
  7: 'Sol',
  9: 'La',
  11: 'Si',
};
// Grado diatónico dentro de la octava (para ubicar la nota en el pentagrama).
const Map<int, int> _degree = {0: 0, 2: 1, 4: 2, 5: 3, 7: 4, 9: 5, 11: 6};

/// Vista de piano estilo Yousician (horizontal): pentagrama arriba con las
/// notas fluyendo de derecha a izquierda, y un teclado realista abajo con las
/// teclas de colores que se encienden cuando hay que tocarlas.
class PianoLearnView extends StatefulWidget {
  const PianoLearnView({super.key, required this.controller});

  final KaraokeController controller;

  @override
  State<PianoLearnView> createState() => _PianoLearnViewState();
}

class _PianoLearnViewState extends State<PianoLearnView>
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
          painter: _LearnPainter(widget.controller, _ticker),
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
        if (!c.running || c.notes.isEmpty) return const SizedBox.shrink();
        final pos = c.player.position.inMilliseconds / 1000.0;
        final remain = c.notes.first.startT - pos;
        if (remain <= 0 || remain > 3.5) return const SizedBox.shrink();
        final n = remain.ceil().clamp(1, 3);
        return Align(
          alignment: const Alignment(-0.55, -0.4),
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

int _dindex(int midi) {
  final white = _whitePc.contains(midi % 12) ? midi : midi - 1;
  return (white ~/ 12) * 7 + _degree[white % 12]!;
}

class _LearnPainter extends CustomPainter {
  _LearnPainter(this.c, Listenable repaint) : super(repaint: repaint);

  final KaraokeController c;

  static const double lookahead = 3.2; // segundos visibles a la derecha.
  static const double nowFrac = 0.2;

  @override
  void paint(Canvas canvas, Size size) {
    final notes = c.notes;
    if (notes.isEmpty) return;

    // Fondo.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0F0E16),
    );

    final keyboardTop = size.height * 0.52;
    final nowX = size.width * nowFrac;
    final pos = c.player.position.inMilliseconds / 1000.0;
    final pps = (size.width - nowX) / lookahead;
    double xForTime(double t) => nowX + (t - pos) * pps;

    // ---------- Pentagrama ----------
    final staffAreaH = keyboardTop;
    final staffSpace = (staffAreaH / 10).clamp(12.0, 30.0);
    final half = staffSpace / 2;
    final middleY = staffAreaH * 0.52; // línea del medio (Si4, dindex 41).
    double yForD(int d) => middleY - (d - 41) * half;

    // Fondo claro del pentagrama.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, keyboardTop),
      Paint()..color = const Color(0xFF1B1A24),
    );
    // 5 líneas (E4,G4,B4,D5,F5 = dindex 37,39,41,43,45).
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1.5;
    for (final d in [37, 39, 41, 43, 45]) {
      final y = yForD(d);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Notas fluyendo (barras de color sobre el pentagrama).
    final noteH = staffSpace * 0.95;
    for (final n in notes) {
      final x0 = xForTime(n.startT);
      final x1 = xForTime(n.endT);
      if (x1 < -8 || x0 > size.width + 8) continue;
      final d = _dindex(n.midi);
      final y = yForD(d);
      final color = kNoteColors[n.midi % 12];

      // Líneas adicionales (ledger) si la nota se sale del pentagrama.
      _ledgerLines(canvas, d, (x0 + x1) / 2, yForD, noteH, size.width);

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTRB(x0, y - noteH / 2, x1, y + noteH / 2),
        Radius.circular(noteH / 2),
      );
      canvas.drawRRect(rect, Paint()..color = color);
      // Sostenido.
      if (!_whitePc.contains(n.midi % 12)) {
        _text(canvas, '♯', Offset(x0 - 10, y), Colors.white, 13);
      }
    }

    // Línea "ahora".
    canvas.drawLine(
      Offset(nowX, 0),
      Offset(nowX, keyboardTop),
      Paint()
        ..color = const Color(0xFF4AE3B5)
        ..strokeWidth = 2.5,
    );

    // ---------- Teclado ----------
    _paintKeyboard(canvas, size, keyboardTop, notes, pos);
  }

  void _ledgerLines(
    Canvas canvas,
    int d,
    double cx,
    double Function(int) yForD,
    double noteH,
    double w,
  ) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1.5;
    final hw = noteH * 0.9;
    if (d > 45) {
      for (var l = 47; l <= d; l += 2) {
        final y = yForD(l);
        canvas.drawLine(Offset(cx - hw, y), Offset(cx + hw, y), p);
      }
    } else if (d < 37) {
      for (var l = 35; l >= d; l -= 2) {
        final y = yForD(l);
        canvas.drawLine(Offset(cx - hw, y), Offset(cx + hw, y), p);
      }
    }
  }

  void _paintKeyboard(
    Canvas canvas,
    Size size,
    double top,
    List notes,
    double pos,
  ) {
    // Rango usado por la canción (solo esas teclas).
    var minMidi = notes.first.midi as int;
    var maxMidi = minMidi;
    for (final n in notes) {
      final m = n.midi as int;
      if (m < minMidi) minMidi = m;
      if (m > maxMidi) maxMidi = m;
    }
    var startMidi = minMidi - 1;
    while (!_whitePc.contains(startMidi % 12)) {
      startMidi--;
    }
    var endMidi = maxMidi + 1;
    while (!_whitePc.contains(endMidi % 12)) {
      endMidi++;
    }

    final whites = <int>[];
    for (var m = startMidi; m <= endMidi; m++) {
      if (_whitePc.contains(m % 12)) whites.add(m);
    }
    if (whites.isEmpty) return;

    final kbH = size.height - top;
    final whiteW = size.width / whites.length;

    double xForMidi(int midi) {
      if (_whitePc.contains(midi % 12)) {
        return whites.indexOf(midi) * whiteW + whiteW / 2;
      }
      return (whites.indexOf(midi - 1) + 1) * whiteW;
    }

    int? activeMidi;
    for (final n in notes) {
      if (pos >= n.startT && pos < n.endT) {
        activeMidi = n.midi as int;
        break;
      }
    }
    final sung = c.livePitch?.round();

    // Blancas con sticker de color.
    for (var i = 0; i < whites.length; i++) {
      final midi = whites[i];
      final x = i * whiteW;
      final rect = Rect.fromLTWH(x + 1, top, whiteW - 2, kbH);
      final color = kNoteColors[midi % 12];
      final active = activeMidi == midi;
      canvas.drawRect(rect, Paint()..color = const Color(0xFFF7F7FA));
      // Sombra sutil arriba (realismo).
      canvas.drawRect(
        Rect.fromLTWH(x + 1, top, whiteW - 2, 8),
        Paint()..color = Colors.black.withValues(alpha: 0.12),
      );
      final bandH = kbH * 0.4;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x + 2, top + kbH - bandH, whiteW - 4, bandH - 3),
          bottomLeft: const Radius.circular(6),
          bottomRight: const Radius.circular(6),
        ),
        Paint()..color = color,
      );
      if (active) {
        canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.55));
      }
      // El aprendiz tocó ESTA tecla: verde festivo si es la correcta.
      final played = sung == midi;
      final correct = played && activeMidi == midi;
      if (correct) {
        canvas.drawRect(
          rect,
          Paint()..color = const Color(0xFF4AE3B5).withValues(alpha: 0.65),
        );
      }
      _text(
        canvas,
        _solfege[midi % 12] ?? '',
        Offset(x + whiteW / 2, top + kbH - bandH / 2),
        Colors.white,
        (whiteW * 0.32).clamp(11.0, 20.0),
      );
      if (played) {
        canvas.drawRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = correct ? 5 : 3
            ..color = correct
                ? const Color(0xFF2FD9A8)
                : const Color(0xFFFFB74D),
        );
      }
    }

    // Negras.
    final blackH = kbH * 0.62;
    for (var m = startMidi; m <= endMidi; m++) {
      if (_whitePc.contains(m % 12)) continue;
      final x = xForMidi(m);
      final w = whiteW * 0.58;
      final active = activeMidi == m;
      final color = kNoteColors[m % 12];
      final rr = RRect.fromRectAndCorners(
        Rect.fromLTWH(x - w / 2, top, w, blackH),
        bottomLeft: const Radius.circular(5),
        bottomRight: const Radius.circular(5),
      );
      final played = sung == m;
      final correct = played && active;
      canvas.drawRRect(
        rr,
        Paint()
          ..color = correct
              ? const Color(0xFF4AE3B5)
              : (active ? color : Color.lerp(color, Colors.black, 0.5)!),
      );
      if (played) {
        canvas.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = correct ? 4 : 3
            ..color = correct
                ? const Color(0xFF2FD9A8)
                : const Color(0xFFFFB74D),
        );
      }
    }
  }

  void _text(
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
  bool shouldRepaint(covariant _LearnPainter oldDelegate) => true;
}
