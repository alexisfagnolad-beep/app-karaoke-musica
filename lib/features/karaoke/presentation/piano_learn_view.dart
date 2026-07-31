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

const Color _kHit = Color(0xFF4AE3B5);

/// Vista de piano estilo Yousician (horizontal): pentagrama arriba con las
/// notas fluyendo de derecha a izquierda, y un teclado realista abajo. Se puede
/// tocar con los dedos (multitáctil, notas sostenidas); si tocás justo la nota
/// al pasar por la línea, la tecla y la nota brillan.
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

  // Dedo (pointer) -> nota MIDI que está apretando (para el multitáctil).
  final Map<int, int> _pointerMidi = {};

  @override
  void dispose() {
    for (final e in _pointerMidi.entries) {
      widget.controller.noteOff(e.key, e.value);
    }
    _pointerMidi.clear();
    _ticker.dispose();
    super.dispose();
  }

  void _onDown(PointerDownEvent e, Size size) {
    final midi = _keyAt(e.localPosition, size);
    if (midi == null) return;
    _pointerMidi[e.pointer] = midi;
    widget.controller.noteOn(e.pointer, midi);
  }

  void _onUp(int pointer) {
    final midi = _pointerMidi.remove(pointer);
    if (midi != null) widget.controller.noteOff(pointer, midi);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cons) {
        final size = Size(cons.maxWidth, cons.maxHeight);
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => _onDown(e, size),
          onPointerUp: (e) => _onUp(e.pointer),
          onPointerCancel: (e) => _onUp(e.pointer),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _LearnPainter(widget.controller, _ticker),
                size: Size.infinite,
              ),
              _buildCountIn(),
            ],
          ),
        );
      },
    );
  }

  /// Mapea un toque a la tecla del teclado dibujado (o null si es el pentagrama).
  int? _keyAt(Offset p, Size size) {
    final c = widget.controller;
    if (c.notes.isEmpty) return null;
    final top = size.height * 0.52;
    if (p.dy < top) return null;

    var minMidi = c.notes.first.midi;
    var maxMidi = minMidi;
    for (final n in c.notes) {
      if (n.midi < minMidi) minMidi = n.midi;
      if (n.midi > maxMidi) maxMidi = n.midi;
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
    if (whites.isEmpty) return null;

    final whiteW = size.width / whites.length;
    final kbH = size.height - top;
    final blackH = kbH * 0.62;

    // Negras primero (están arriba y encima de las blancas).
    for (var m = startMidi; m <= endMidi; m++) {
      if (_whitePc.contains(m % 12)) continue;
      final wi = whites.indexOf(m - 1);
      if (wi < 0) continue;
      final cx = (wi + 1) * whiteW;
      final w = whiteW * 0.58;
      if (p.dy <= top + blackH && (p.dx - cx).abs() <= w / 2) return m;
    }
    final idx = (p.dx / whiteW).floor().clamp(0, whites.length - 1);
    return whites[idx];
  }

  Widget _buildCountIn() {
    return AnimatedBuilder(
      animation: _ticker,
      builder: (context, _) {
        final c = widget.controller;
        if (!c.running || c.notes.isEmpty) return const SizedBox.shrink();
        final pos = c.clock;
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

  // Segundos visibles a la derecha. En "Para empezar" (play-along) la ventana
  // es más amplia: las notas viajan más despacio y se leen mejor.
  double get lookahead => c.playAlong ? 4.4 : 3.2;
  static const double nowFrac = 0.2;

  @override
  void paint(Canvas canvas, Size size) {
    final notes = c.notes;
    if (notes.isEmpty) return;

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0F0E16),
    );

    final keyboardTop = size.height * 0.52;
    final nowX = size.width * nowFrac;
    final pos = c.clock;
    final pps = (size.width - nowX) / lookahead;
    double xForTime(double t) => nowX + (t - pos) * pps;

    // ---------- Pentagrama ----------
    final staffAreaH = keyboardTop;
    final staffSpace = (staffAreaH / 10).clamp(12.0, 30.0);
    final half = staffSpace / 2;
    final middleY = staffAreaH * 0.52;
    double yForD(int d) => middleY - (d - 41) * half;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, keyboardTop),
      Paint()..color = const Color(0xFF1B1A24),
    );
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1.5;
    for (final d in [37, 39, 41, 43, 45]) {
      final y = yForD(d);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Notas fluyendo (barras de color). Si ya fueron acertadas, brillan.
    final noteH = staffSpace * 0.95;
    for (var i = 0; i < notes.length; i++) {
      final n = notes[i];
      final x0 = xForTime(n.startT);
      final x1 = xForTime(n.endT);
      if (x1 < -8 || x0 > size.width + 8) continue;
      final d = _dindex(n.midi);
      final y = yForD(d);
      final hit = i < c.noteHit.length && c.noteHit[i];
      final color = hit ? _kHit : kNoteColors[n.midi % 12];

      _ledgerLines(canvas, d, (x0 + x1) / 2, yForD, noteH, size.width);

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTRB(x0, y - noteH / 2, x1, y + noteH / 2),
        Radius.circular(noteH / 2),
      );
      if (hit) {
        canvas.drawRRect(
          rect,
          Paint()
            ..color = _kHit
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }
      canvas.drawRRect(rect, Paint()..color = color);
      if (!_whitePc.contains(n.midi % 12)) {
        _text(canvas, '♯', Offset(x0 - 10, y), Colors.white, 13);
      }
    }

    // Línea "ahora".
    canvas.drawLine(
      Offset(nowX, 0),
      Offset(nowX, keyboardTop),
      Paint()
        ..color = _kHit
        ..strokeWidth = 2.5,
    );

    // ---------- Teclado ----------
    _paintKeyboard(canvas, size, keyboardTop, notes, pos);

    // Indicador de micrófono (piano real).
    if (c.micPractice) _micMeter(canvas, size, c.micLevel, c.listening);

    // Cartel rápido de "¡Bien!" al acertar.
    if (c.lastHitT >= 0 && (pos - c.lastHitT) >= 0 && (pos - c.lastHitT) < 0.6) {
      _text(
        canvas,
        '¡Bien! ✨',
        Offset(size.width * 0.5, keyboardTop * 0.16),
        _kHit,
        26,
      );
    }
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

    // Nota guía activa (la que hay que tocar ahora) y si ya la acertaron.
    int? targetIdx;
    for (var i = 0; i < notes.length; i++) {
      if (pos >= notes[i].startT && pos < notes[i].endT) {
        targetIdx = i;
        break;
      }
    }
    final targetMidi = targetIdx != null ? notes[targetIdx].midi as int : null;
    final targetHit =
        targetIdx != null &&
        targetIdx < c.noteHit.length &&
        c.noteHit[targetIdx];

    // Blancas con sticker de color.
    for (var i = 0; i < whites.length; i++) {
      final midi = whites[i];
      final x = i * whiteW;
      final rect = Rect.fromLTWH(x + 1, top, whiteW - 2, kbH);
      final color = kNoteColors[midi % 12];
      canvas.drawRect(rect, Paint()..color = const Color(0xFFF7F7FA));
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
      _text(
        canvas,
        _solfege[midi % 12] ?? '',
        Offset(x + whiteW / 2, top + kbH - bandH / 2),
        Colors.white,
        (whiteW * 0.32).clamp(11.0, 20.0),
      );
      _keyDecor(
        canvas,
        rect,
        isTarget: midi == targetMidi,
        targetHit: targetHit,
        pressed: c.pressedMidis.contains(midi),
        radius: 0,
      );
    }

    // Negras.
    final blackH = kbH * 0.62;
    for (var m = startMidi; m <= endMidi; m++) {
      if (_whitePc.contains(m % 12)) continue;
      final x = xForMidi(m);
      final w = whiteW * 0.58;
      final color = kNoteColors[m % 12];
      final rr = RRect.fromRectAndCorners(
        Rect.fromLTWH(x - w / 2, top, w, blackH),
        bottomLeft: const Radius.circular(5),
        bottomRight: const Radius.circular(5),
      );
      canvas.drawRRect(
        rr,
        Paint()..color = Color.lerp(color, Colors.black, 0.5)!,
      );
      _keyDecorRR(
        canvas,
        rr,
        isTarget: m == targetMidi,
        targetHit: targetHit,
        pressed: c.pressedMidis.contains(m),
      );
    }
  }

  /// Realce de una tecla blanca: contorno guía tenue en la nota objetivo, y
  /// brillo verde fuerte solo si se acertó. Si se aprieta, un realce suave.
  void _keyDecor(
    Canvas canvas,
    Rect rect, {
    required bool isTarget,
    required bool targetHit,
    required bool pressed,
    required double radius,
  }) {
    if (pressed) {
      canvas.drawRect(
        rect,
        Paint()..color = Colors.white.withValues(alpha: 0.25),
      );
    }
    if (isTarget && targetHit) {
      canvas.drawRect(
        rect,
        Paint()
          ..color = _kHit.withValues(alpha: 0.85)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = const Color(0xFF2FD9A8),
      );
    } else if (isTarget) {
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = Colors.white.withValues(alpha: 0.5),
      );
    }
  }

  void _keyDecorRR(
    Canvas canvas,
    RRect rr, {
    required bool isTarget,
    required bool targetHit,
    required bool pressed,
  }) {
    if (pressed) {
      canvas.drawRRect(
        rr,
        Paint()..color = Colors.white.withValues(alpha: 0.28),
      );
    }
    if (isTarget && targetHit) {
      canvas.drawRRect(
        rr,
        Paint()
          ..color = _kHit
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = const Color(0xFF2FD9A8),
      );
    } else if (isTarget) {
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: 0.5),
      );
    }
  }

  void _micMeter(Canvas canvas, Size size, double level, bool listening) {
    final w = size.width * 0.3;
    final x = size.width * 0.5 - w / 2;
    final y = size.height * 0.04;
    const h = 9.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h),
        const Radius.circular(5),
      ),
      Paint()..color = Colors.white24,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w * level.clamp(0.0, 1.0), h),
        const Radius.circular(5),
      ),
      Paint()..color = level > 0.5 ? _kHit : const Color(0xFFFFCA28),
    );
    _text(
      canvas,
      listening ? '🎤 Escuchando tu piano…' : '🎤 micrófono',
      Offset(size.width * 0.5, y - 10),
      Colors.white70,
      12,
    );
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
