import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/ui/app_ui.dart';
import '../../../shared/ui/celebration.dart';
import '../data/karaoke_controller.dart';
import '../domain/melody.dart';
import 'piano_learn_view.dart';
import 'tempo_button.dart';

/// Pantalla de piano estilo Yousician: horizontal, a pantalla completa, con
/// pentagrama arriba y teclado de colores abajo. Comparte la lógica del
/// KaraokeController (reproduce, escucha el micrófono y puntúa).
class PianoLearnScreen extends StatefulWidget {
  const PianoLearnScreen({
    super.key,
    required this.instrumentalPath,
    required this.title,
    required this.melody,
  }) : builtInNotes = null,
       builtInDuration = null;

  /// Canción prediseñada (sin audio, con metrónomo interno).
  const PianoLearnScreen.builtIn({
    super.key,
    required this.title,
    required List<MelodyNote> notes,
    required double duration,
  }) : builtInNotes = notes,
       builtInDuration = duration,
       instrumentalPath = null,
       melody = null;

  final String? instrumentalPath;
  final String title;
  final Melody? melody;
  final List<MelodyNote>? builtInNotes;
  final double? builtInDuration;

  @override
  State<PianoLearnScreen> createState() => _PianoLearnScreenState();
}

class _PianoLearnScreenState extends State<PianoLearnScreen> {
  final KaraokeController _c = KaraokeController();

  @override
  void initState() {
    super.initState();
    // Arranca en Fácil (melodía principal resumida, para empezar de cero).
    if (widget.builtInNotes != null) {
      _c.loadBuiltInMelodic(widget.builtInNotes!, widget.builtInDuration!);
    } else {
      _c.loadMelodic(widget.instrumentalPath!, widget.melody!, difficulty: 0);
    }
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _c.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          if (_c.finished) return _result();
          return Stack(
            fit: StackFit.expand,
            children: [
              PianoLearnView(controller: _c),
              _overlay(),
            ],
          );
        },
      ),
    );
  }

  Widget _overlay() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_c.playAlong) _soundButton(),
                TempoButton(controller: _c, dark: true),
                if (_c.playAlong)
                  const SizedBox.shrink()
                else if (_c.running)
                  Text(
                    '${_c.liveScore} pts',
                    style: const TextStyle(
                      color: Color(0xFF4AE3B5),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  )
                else
                  _difficultyMenu(),
                // "Terminar" arriba, para que no tape las teclas.
                if (_c.running) ...[const SizedBox(width: 6), _stopButton()],
              ],
            ),
            if (_c.playAlong && !_c.running)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _physicalToggle('piano'),
              ),
            const Spacer(),
            // Solo "Empezar" abajo (antes de tocar, cuando no molesta).
            if (!_c.running)
              Align(
                alignment: Alignment.bottomRight,
                child: FloatingActionButton.extended(
                  heroTag: 'play',
                  backgroundColor: AppColors.pink,
                  foregroundColor: Colors.white,
                  onPressed: _c.start,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Empezar a tocar'),
                ),
              ),
            if (_c.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _c.error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _stopButton() {
    return FilledButton.icon(
      onPressed: _c.stop,
      icon: const Icon(Icons.stop, size: 18),
      label: const Text('Terminar'),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white24,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _soundButton() {
    final on = KaraokeController.builtInSoundEnabled;
    return IconButton(
      tooltip: on ? 'Silenciar' : 'Activar sonido',
      icon: Icon(
        on ? Icons.volume_up : Icons.volume_off,
        color: Colors.white,
      ),
      onPressed: () {
        KaraokeController.builtInSoundEnabled = !on;
        _c.applySound();
      },
    );
  }

  /// Toggle bien visible: tocar con instrumento REAL (micrófono). Antes de
  /// empezar. Al activarlo, la app escucha tu piano físico.
  Widget _physicalToggle(String instrumento) {
    final on = _c.micPractice;
    return ElevatedButton.icon(
      onPressed: () => _c.setMicPractice(!on),
      icon: Icon(on ? Icons.mic : Icons.mic_none),
      label: Text(
        on
            ? '$instrumento real: ACTIVADO 🎤'
            : 'Tocar $instrumento real (micrófono)',
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: on ? const Color(0xFF1DB6A2) : Colors.white24,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _difficultyMenu() {
    return PopupMenuButton<int>(
      tooltip: 'Dificultad',
      icon: const Icon(Icons.tune, color: Colors.white),
      onSelected: _c.setDifficulty,
      itemBuilder: (_) => [
        for (final e in const [
          [0, 'Fácil'],
          [1, 'Normal'],
          [2, 'Exigente'],
        ])
          CheckedPopupMenuItem(
            value: e[0] as int,
            checked: _c.difficulty == e[0],
            child: Text(e[1] as String),
          ),
      ],
    );
  }

  Widget _result() {
    return SafeArea(
      child: Celebration(
        score: _c.melodicResult!.score,
        onBack: () => Navigator.of(context).pop(),
        onRetry: _c.start,
      ),
    );
  }
}
