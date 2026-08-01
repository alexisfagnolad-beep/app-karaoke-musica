import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/ui/app_ui.dart';
import '../../../shared/ui/celebration.dart';
import '../data/karaoke_controller.dart';
import '../domain/rhythm.dart';
import 'drum_learn_view.dart';
import 'tempo_button.dart';

/// Pantalla de batería estilo Guitar Hero: horizontal, a pantalla completa,
/// con carriles que caen a una batería dibujada que se ilumina al golpear.
class DrumLearnScreen extends StatefulWidget {
  const DrumLearnScreen({
    super.key,
    required this.instrumentalPath,
    required this.title,
    required this.rhythm,
  }) : builtInDuration = null;

  /// Patrón rítmico prediseñado (sin audio, con metrónomo interno).
  const DrumLearnScreen.builtIn({
    super.key,
    required this.title,
    required this.rhythm,
    required double duration,
  }) : instrumentalPath = null,
       builtInDuration = duration;

  final String? instrumentalPath;
  final String title;
  final Rhythm rhythm;
  final double? builtInDuration;

  @override
  State<DrumLearnScreen> createState() => _DrumLearnScreenState();
}

class _DrumLearnScreenState extends State<DrumLearnScreen> {
  final KaraokeController _c = KaraokeController();
  bool _fullKit = false;

  @override
  void initState() {
    super.initState();
    if (widget.builtInDuration != null) {
      _c.loadBuiltInRhythm(widget.rhythm, widget.builtInDuration!);
    } else {
      _c.loadRhythmic(widget.instrumentalPath!, widget.rhythm);
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
              DrumLearnView(controller: _c, fullKit: _fullKit),
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
                if (!_c.playAlong)
                  Text(
                    'Golpes: ${_c.hits}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                _optionsMenu(),
              ],
            ),
            if (_c.playAlong && !_c.running)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _physicalToggle('batería'),
              ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: _c.running
                  ? FloatingActionButton.extended(
                      heroTag: 'stopd',
                      backgroundColor: Colors.white24,
                      onPressed: _c.stop,
                      icon: const Icon(Icons.stop),
                      label: const Text('Terminar'),
                    )
                  : FloatingActionButton.extended(
                      heroTag: 'playd',
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

  /// Menú de opciones (⋮): modo estricto y cantidad de elementos de la batería.
  Widget _optionsMenu() {
    return PopupMenuButton<String>(
      tooltip: 'Opciones',
      icon: const Icon(Icons.more_vert, color: Colors.white),
      onSelected: (v) => setState(() {
        switch (v) {
          case 'strict':
            _c.strictDrums = !_c.strictDrums;
            break;
          case 'kit_simple':
            _fullKit = false;
            break;
          case 'kit_full':
            _fullKit = true;
            break;
        }
      }),
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
          value: 'strict',
          checked: _c.strictDrums,
          child: const Text('Modo estricto (exigir la pieza correcta)'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          enabled: false,
          child: Text('Elementos de la batería'),
        ),
        CheckedPopupMenuItem(
          value: 'kit_simple',
          checked: !_fullKit,
          child: const Text('Set simple (3 piezas)'),
        ),
        CheckedPopupMenuItem(
          value: 'kit_full',
          checked: _fullKit,
          child: const Text('Batería completa'),
        ),
      ],
    );
  }

  /// Toggle bien visible: tocar con instrumento REAL (micrófono). Antes de
  /// empezar. Al activarlo, la app escucha tu batería/piano físico.
  Widget _physicalToggle(String instrumento) {
    final on = _c.micPractice;
    return ElevatedButton.icon(
      onPressed: () => _c.setMicPractice(!on),
      icon: Icon(on ? Icons.mic : Icons.mic_none),
      label: Text(
        on
            ? '$instrumento real: ACTIVADA 🎤'
            : 'Tocar $instrumento real (micrófono)',
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: on ? const Color(0xFF1DB6A2) : Colors.white24,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _result() {
    return SafeArea(
      child: Celebration(
        score: _c.rhythmResult!.score,
        onBack: () => Navigator.of(context).pop(),
        onRetry: _c.start,
      ),
    );
  }
}
