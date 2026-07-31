import 'package:flutter/material.dart';

import '../../../shared/ui/app_ui.dart';
import '../../../shared/ui/celebration.dart';
import '../data/karaoke_controller.dart';
import '../domain/lyrics.dart';
import '../domain/melody.dart';
import '../domain/rhythm.dart';
import 'drum_roll_view.dart';
import 'lyrics_view.dart';
import 'piano_roll_view.dart';
import 'pitch_roll_view.dart';
import 'stage_screen.dart';
import 'tempo_button.dart';

/// Pantalla de práctica con puntaje: reproduce el instrumental, muestra la guía
/// en vivo (nota objetivo vs tu nota, o los golpes) y al final el puntaje.
class KaraokeScreen extends StatefulWidget {
  const KaraokeScreen({
    super.key,
    required this.instrumentalPath,
    required this.title,
    this.melody,
    this.rhythm,
    this.lyrics,
    this.freeMode = false,
    this.pianoView = false,
  });

  final String instrumentalPath;
  final String title;
  final Melody? melody;
  final Rhythm? rhythm;
  final Lyrics? lyrics;

  /// Modo "Solo letra": reproduce con barras y letra, sin micrófono ni puntaje.
  final bool freeMode;

  /// Arranca en la vista didáctica de piano (teclado de colores) en vez de las
  /// barras. Igual se puede alternar con el botón.
  final bool pianoView;

  @override
  State<KaraokeScreen> createState() => _KaraokeScreenState();
}

class _KaraokeScreenState extends State<KaraokeScreen> {
  final KaraokeController _c = KaraokeController();
  late bool _pianoView = widget.pianoView;

  @override
  void initState() {
    super.initState();
    if (widget.rhythm != null) {
      _c.loadRhythmic(widget.instrumentalPath, widget.rhythm!);
    } else if (widget.melody != null) {
      _c.loadMelodic(
        widget.instrumentalPath,
        widget.melody!,
        freeMode: widget.freeMode,
        // Arranca en Fácil: barras largas y pegadas, línea melódica amigable.
        difficulty: 0,
      );
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: gradientAppBar(
        context,
        widget.title,
        colors: const [AppColors.pink, AppColors.purple],
        actions: [
          TempoButton(controller: _c),
          if (widget.melody != null)
            IconButton(
              tooltip: _pianoView ? 'Ver barras' : 'Ver piano',
              icon: Icon(_pianoView ? Icons.bar_chart : Icons.piano),
              onPressed: () => setState(() => _pianoView = !_pianoView),
            ),
          if (widget.melody != null)
            PopupMenuButton<int>(
              tooltip: 'Dificultad',
              icon: const Icon(Icons.tune),
              onSelected: (v) {
                if (_c.running) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Pará la canción para cambiar la dificultad.',
                      ),
                    ),
                  );
                  return;
                }
                _c.setDifficulty(v);
              },
              itemBuilder: (_) => [
                for (final e in const [
                  [0, 'Fácil', 'Barras bien resumidas'],
                  [1, 'Normal', 'Equilibrado'],
                  [2, 'Exigente', 'Sigue la melodía de cerca'],
                ])
                  CheckedPopupMenuItem(
                    value: e[0] as int,
                    checked: _c.difficulty == e[0],
                    child: Text('${e[1]}  ·  ${e[2]}'),
                  ),
              ],
            ),
          if (widget.melody != null)
            IconButton(
              tooltip: 'Modo escenario (proyectar)',
              icon: const Icon(Icons.cast),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StageScreen(
                    controller: _c,
                    title: widget.title,
                    lyrics: widget.lyrics,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            if (_c.finished) return _resultView();
            return _practiceView();
          },
        ),
      ),
    );
  }

  // ---------- Práctica en vivo ----------
  Widget _practiceView() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_c.error != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _c.error!,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          if (!_c.isRhythm && !widget.freeMode) _melodicHeader(),
          if (!_c.isRhythm && !widget.freeMode) const SizedBox(height: 12),
          if (_c.isRhythm) _rhythmHeader(),
          if (_c.isRhythm) const SizedBox(height: 12),
          Expanded(
            child: _c.isRhythm
                ? DrumRollView(controller: _c)
                : (_pianoView
                      ? PianoRollView(controller: _c)
                      : PitchRollView(controller: _c)),
          ),
          if (!_c.isRhythm &&
              !_pianoView &&
              widget.lyrics != null &&
              !widget.lyrics!.isEmpty)
            LyricsView(controller: _c, lyrics: widget.lyrics!),
          const SizedBox(height: 12),
          _progressBar(),
          const SizedBox(height: 16),
          if (!_c.running)
            FilledButton.icon(
              onPressed: _c.start,
              icon: const Icon(Icons.play_arrow),
              label: Text(
                widget.freeMode
                    ? 'Reproducir'
                    : ((_c.isRhythm || _pianoView)
                          ? 'Empezar a tocar'
                          : 'Empezar a cantar'),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: _c.stop,
              icon: const Icon(Icons.stop),
              label: Text(widget.freeMode ? 'Detener' : 'Terminar'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
            ),
        ],
      ),
    );
  }

  /// Encabezado del modo melódico: puntaje en vivo + indicador de afinación.
  Widget _melodicHeader() {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Puntos',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            Text(
              '${_c.liveScore}',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        _tuningChip(),
      ],
    );
  }

  Widget _tuningChip() {
    final theme = Theme.of(context);
    late final IconData icon;
    late final String text;
    late final Color color;

    if (!_c.running) {
      icon = Icons.multitrack_audio;
      text = '¡Preparate! 🎤';
      color = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    } else if (_c.livePitch == null) {
      icon = Icons.mic_none;
      text = '¡Cantá! 🎤';
      color = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    } else if (_c.direction == 0) {
      icon = Icons.check_circle;
      text = '¡Buenísimo! 😃';
      color = const Color(0xFF4AE3B5);
    } else if (_c.direction > 0) {
      icon = Icons.keyboard_arrow_down;
      text = 'Bajá un poquito';
      color = const Color(0xFFFFB74D);
    } else {
      icon = Icons.keyboard_arrow_up;
      text = 'Subí un poquito';
      color = const Color(0xFFFFB74D);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rhythmHeader() {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Golpes',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            Text(
              '${_c.hits}',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        Flexible(
          child: Text(
            _c.running
                ? 'Seguí los golpes que caen en cada pad'
                : 'Tocá "Empezar" y seguí el ritmo',
            textAlign: TextAlign.end,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }

  Widget _progressBar() {
    return StreamBuilder<Duration?>(
      stream: _c.player.durationStream,
      builder: (context, durSnap) {
        final total = durSnap.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: _c.player.positionStream,
          builder: (context, posSnap) {
            final pos = posSnap.data ?? Duration.zero;
            final value = total.inMilliseconds == 0
                ? 0.0
                : (pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
            return LinearProgressIndicator(value: value);
          },
        );
      },
    );
  }

  // ---------- Resultado ----------
  Widget _resultView() {
    final score = _c.isRhythm
        ? _c.rhythmResult!.score
        : _c.melodicResult!.score;

    final details = _c.isRhythm
        ? [
            _stat('En tiempo', _c.rhythmResult!.timing),
            _stat('Acertaste', _c.rhythmResult!.recall),
            _stat('Precisión', _c.rhythmResult!.precision),
          ]
        : [
            _stat('Afinación', _c.melodicResult!.pitchAccuracy),
            _stat('Sostenimiento', _c.melodicResult!.coverage),
          ];

    return Celebration(
      score: score,
      onBack: () => Navigator.of(context).pop(),
      onRetry: _c.start,
      details: details,
    );
  }

  Widget _stat(String label, double value01) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 130, child: Text(label)),
          Expanded(
            child: LinearProgressIndicator(
              value: value01.clamp(0.0, 1.0),
              minHeight: 8,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${(value01 * 100).toStringAsFixed(0)}%',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
