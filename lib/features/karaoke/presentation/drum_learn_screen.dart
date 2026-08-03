import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/ui/app_ui.dart';
import '../../../shared/ui/celebration.dart';
import '../data/karaoke_controller.dart';
import '../domain/rhythm.dart';
import 'drum_learn_view.dart';
import 'karaoke_backdrop.dart';
import 'tempo_button.dart';

/// Pantalla de batería estilo Guitar Hero: horizontal, a pantalla completa,
/// con carriles que caen a una batería dibujada que se ilumina al golpear.
class DrumLearnScreen extends StatefulWidget {
  const DrumLearnScreen({
    super.key,
    required this.instrumentalPath,
    required this.title,
    required this.rhythm,
  }) : builtInDuration = null,
       builtInPieces = null;

  /// Patrón rítmico prediseñado (sin audio, con metrónomo interno).
  const DrumLearnScreen.builtIn({
    super.key,
    required this.title,
    required this.rhythm,
    required double duration,
    this.builtInPieces,
  }) : instrumentalPath = null,
       builtInDuration = duration;

  final String? instrumentalPath;
  final String title;
  final Rhythm rhythm;
  final double? builtInDuration;

  /// Piezas que arma este patrón (toms/platillos según corresponda).
  final Set<String>? builtInPieces;

  @override
  State<DrumLearnScreen> createState() => _DrumLearnScreenState();
}

class _DrumLearnScreenState extends State<DrumLearnScreen> {
  final KaraokeController _c = KaraokeController();
  final Set<String> _pieces = {...kDefaultPieces};

  @override
  void initState() {
    super.initState();
    if (widget.builtInPieces != null) {
      _pieces
        ..clear()
        ..addAll(widget.builtInPieces!);
    }
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
              const KaraokeBackdrop(),
              Container(color: Colors.black.withValues(alpha: 0.45)),
              DrumLearnView(controller: _c, pieces: _pieces),
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
                if (_c.running) ...[const SizedBox(width: 6), _stopButton()],
                _optionsMenu(),
              ],
            ),
            if (_c.playAlong && !_c.running)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _physicalToggle('batería'),
              ),
            const Spacer(),
            if (!_c.running)
              Align(
                alignment: Alignment.bottomRight,
                child: FloatingActionButton.extended(
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

  /// Menú de opciones (⋮): modo estricto y elección de piezas de la batería.
  Widget _optionsMenu() {
    return PopupMenuButton<String>(
      tooltip: 'Opciones',
      icon: const Icon(Icons.more_vert, color: Colors.white),
      onSelected: (v) {
        switch (v) {
          case 'strict':
            setState(() => _c.strictDrums = !_c.strictDrums);
            break;
          case 'pieces':
            _choosePieces();
            break;
        }
      },
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
          value: 'strict',
          checked: _c.strictDrums,
          child: const Text('Modo estricto (exigir la pieza correcta)'),
        ),
        const PopupMenuItem(
          value: 'pieces',
          child: Text('Elegir piezas de la batería…'),
        ),
      ],
    );
  }

  /// Diálogo con casillas para tildar qué piezas tiene la batería.
  Future<void> _choosePieces() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Piezas de la batería'),
          content: SizedBox(
            width: double.maxFinite,
            child: StatefulBuilder(
              builder: (ctx, setD) => ListView(
                shrinkWrap: true,
                children: [
                  for (final p in kDrumPieces)
                    CheckboxListTile(
                      dense: true,
                      title: Text(p.label),
                      subtitle: Text(_bandName(p.band)),
                      value: _pieces.contains(p.id),
                      onChanged: (v) => setD(() {
                        if (v == true) {
                          _pieces.add(p.id);
                        } else {
                          _pieces.remove(p.id);
                        }
                        setState(() {});
                      }),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _pieces
                    ..clear()
                    ..addAll(kDefaultPieces);
                });
                Navigator.pop(ctx);
              },
              child: const Text('Restablecer'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Listo'),
            ),
          ],
        );
      },
    );
  }

  String _bandName(int band) => switch (band) {
    0 => 'suena como bombo (grave)',
    1 => 'suena como redoblante (medio)',
    _ => 'suena como hi-hat (agudo)',
  };

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
