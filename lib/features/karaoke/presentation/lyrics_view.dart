import 'package:flutter/material.dart';

import '../data/karaoke_controller.dart';
import '../domain/lyrics.dart';

/// Muestra la letra sincronizada debajo de las barras: la línea actual con la
/// palabra que va sonando resaltada, y abajo la línea que viene.
class LyricsView extends StatefulWidget {
  const LyricsView({
    super.key,
    required this.controller,
    required this.lyrics,
    this.big = false,
  });

  final KaraokeController controller;
  final Lyrics lyrics;

  /// Versión grande para el Modo Escenario (proyección).
  final bool big;

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView>
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
    final theme = Theme.of(context);
    final dim = theme.colorScheme.onSurface.withValues(alpha: 0.45);
    final bright = theme.colorScheme.onSurface;
    const accent = Color(0xFF4AE3B5);

    return AnimatedBuilder(
      animation: _ticker,
      builder: (context, _) {
        final pos = widget.controller.clock;
        final idx = widget.lyrics.lineIndexAt(pos);
        if (idx == null) return SizedBox(height: widget.big ? 140 : 76);

        final line = widget.lyrics.lines[idx];
        final active = pos >= line.start && pos <= line.end;
        final next = idx + 1 < widget.lyrics.lines.length
            ? widget.lyrics.lines[idx + 1]
            : null;

        return SizedBox(
          height: widget.big ? 140 : 76,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLine(line, pos, active, bright, dim, accent, theme),
              if (next != null) ...[
                SizedBox(height: widget.big ? 12 : 6),
                Text(
                  next.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      (widget.big
                              ? theme.textTheme.titleLarge
                              : theme.textTheme.bodyMedium)
                          ?.copyWith(color: dim),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildLine(
    LyricLine line,
    double pos,
    bool active,
    Color bright,
    Color dim,
    Color accent,
    ThemeData theme,
  ) {
    final baseStyle =
        (widget.big ? theme.textTheme.displaySmall : theme.textTheme.titleLarge)
            ?.copyWith(fontWeight: FontWeight.bold);

    // Sin palabras con tiempo: mostramos la línea entera.
    if (line.words.isEmpty) {
      return Text(
        line.text,
        maxLines: 2,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: baseStyle?.copyWith(color: active ? bright : dim),
      );
    }

    // Con palabras: resaltamos según el tiempo.
    return RichText(
      maxLines: 2,
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        children: [
          for (final w in line.words)
            TextSpan(
              text: '${w.text} ',
              style: baseStyle?.copyWith(
                color: pos >= w.end ? bright : (pos >= w.start ? accent : dim),
              ),
            ),
        ],
      ),
    );
  }
}
