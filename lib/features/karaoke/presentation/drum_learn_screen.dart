import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/ui/app_ui.dart';
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
  });

  final String instrumentalPath;
  final String title;
  final Rhythm rhythm;

  @override
  State<DrumLearnScreen> createState() => _DrumLearnScreenState();
}

class _DrumLearnScreenState extends State<DrumLearnScreen> {
  final KaraokeController _c = KaraokeController();

  @override
  void initState() {
    super.initState();
    _c.loadRhythmic(widget.instrumentalPath, widget.rhythm);
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
              DrumLearnView(controller: _c),
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
                TempoButton(controller: _c, dark: true),
                Text(
                  'Golpes: ${_c.hits}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
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

  Widget _result() {
    final r = _c.rhythmResult!;
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              ScoreRing(score: r.score, label: r.label, size: 170),
              const SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Volver'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _c.start,
                    icon: const Icon(Icons.replay),
                    label: const Text('Otra vez'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
