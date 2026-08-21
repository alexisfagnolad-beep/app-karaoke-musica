import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/karaoke_controller.dart';
import '../domain/lyrics.dart';
import 'lyrics_view.dart';
import 'pitch_roll_view.dart';

/// Modo Escenario: vista horizontal a pantalla completa (barras + letra
/// grandes, sin botones), pensada para proyectar/espejar a un TV o proyector.
/// Comparte el mismo controlador que la práctica, así va sincronizada.
class StageScreen extends StatefulWidget {
  const StageScreen({
    super.key,
    required this.controller,
    required this.title,
    this.lyrics,
  });

  final KaraokeController controller;
  final String title;
  final Lyrics? lyrics;

  @override
  State<StageScreen> createState() => _StageScreenState();
}

class _StageScreenState extends State<StageScreen> {
  @override
  void initState() {
    super.initState();
    // Horizontal + pantalla completa (oculta barras del sistema).
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // Restauramos vertical y las barras del sistema.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Salir del modo escenario',
                    icon: const Icon(
                      Icons.close_fullscreen,
                      color: Colors.white70,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(child: PitchRollView(controller: widget.controller)),
              if (widget.lyrics != null && !widget.lyrics!.isEmpty) ...[
                const SizedBox(height: 8),
                LyricsView(
                  controller: widget.controller,
                  lyrics: widget.lyrics!,
                  big: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
