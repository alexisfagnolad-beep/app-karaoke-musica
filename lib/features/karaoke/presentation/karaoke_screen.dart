import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../pitch/domain/musical_note.dart';
import '../data/karaoke_controller.dart';
import '../domain/melody.dart';
import '../domain/rhythm.dart';
import '../domain/scoring.dart';

/// Pantalla de práctica con puntaje: reproduce el instrumental, muestra la guía
/// en vivo (nota objetivo vs tu nota, o los golpes) y al final el puntaje.
class KaraokeScreen extends StatefulWidget {
  const KaraokeScreen({
    super.key,
    required this.instrumentalPath,
    required this.title,
    this.melody,
    this.rhythm,
  });

  final String instrumentalPath;
  final String title;
  final Melody? melody;
  final Rhythm? rhythm;

  @override
  State<KaraokeScreen> createState() => _KaraokeScreenState();
}

class _KaraokeScreenState extends State<KaraokeScreen> {
  final KaraokeController _c = KaraokeController();

  @override
  void initState() {
    super.initState();
    if (widget.rhythm != null) {
      _c.loadRhythmic(widget.instrumentalPath, widget.rhythm!);
    } else if (widget.melody != null) {
      _c.loadMelodic(widget.instrumentalPath, widget.melody!);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static String _midiName(int midi) {
    final name = MusicalNote.noteNames[midi % 12];
    return '$name${midi ~/ 12 - 1}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        centerTitle: true,
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
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (_c.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_c.error!,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer)),
            ),
          const Spacer(),
          if (_c.isRhythm) _rhythmLive() else _melodicLive(),
          const Spacer(),
          _progressBar(),
          const SizedBox(height: 20),
          if (!_c.running)
            FilledButton.icon(
              onPressed: _c.start,
              icon: const Icon(Icons.play_arrow),
              label: Text(_c.isRhythm ? 'Empezar a tocar' : 'Empezar a cantar'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            )
          else
            OutlinedButton.icon(
              onPressed: _c.stop,
              icon: const Icon(Icons.stop),
              label: const Text('Terminar'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            ),
        ],
      ),
    );
  }

  Widget _melodicLive() {
    final theme = Theme.of(context);
    final target = _c.target;
    final sung = _c.sung;

    var close = false;
    if (target?.midi != null && sung != null) {
      close = octaveFoldedDiff(sung.midi.toDouble(), target!.midi!).abs() < 1.0;
    }
    final targetText =
        (target != null && target.voiced && target.midi != null)
            ? _midiName(target.midi!)
            : '–';
    final sungText = sung?.name != null ? '${sung!.name}${sung.octave}' : '–';

    return Column(
      children: [
        Text('Nota objetivo', style: theme.textTheme.titleMedium),
        Text(targetText,
            style: theme.textTheme.displayLarge?.copyWith(
                fontSize: 96, fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary)),
        const SizedBox(height: 24),
        Text('Tu voz', style: theme.textTheme.titleMedium),
        Text(sungText,
            style: theme.textTheme.displayMedium?.copyWith(
                fontSize: 64,
                color: close ? Colors.greenAccent : theme.colorScheme.onSurface)),
        const SizedBox(height: 8),
        Icon(close ? Icons.check_circle : Icons.circle_outlined,
            color: close ? Colors.greenAccent : theme.colorScheme.outline,
            size: 32),
      ],
    );
  }

  Widget _rhythmLive() {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(Icons.graphic_eq, size: 96, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text('Golpes: ${_c.hits}', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          _c.running
              ? 'Tocá siguiendo el ritmo de la canción'
              : 'Tocá "Empezar" y seguí el ritmo',
          style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
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
    final theme = Theme.of(context);
    final score = _c.isRhythm ? _c.rhythmResult!.score : _c.melodicResult!.score;
    final label = _c.isRhythm ? _c.rhythmResult!.label : _c.melodicResult!.label;

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

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(score.toStringAsFixed(0),
              style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: 120,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary)),
          Text('puntos', style: theme.textTheme.titleMedium),
          const SizedBox(height: 32),
          ...details,
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Volver'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _c.start,
                  icon: const Icon(Icons.replay),
                  label: const Text('Otra vez'),
                ),
              ),
            ],
          ),
        ],
      ),
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
          Text('${(value01 * 100).toStringAsFixed(0)}%',
              style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
