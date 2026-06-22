import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../data/audio_file_service.dart';

/// Pantalla del paso 3: abrir y reproducir un MP3 propio desde el celular,
/// con play/pausa y barra de progreso.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, this.initialPath, this.initialName});

  /// Si se pasan, la pantalla abre directamente esta canción (desde la
  /// biblioteca) en vez de pedir un archivo.
  final String? initialPath;
  final String? initialName;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final AudioFileService _service = AudioFileService();

  // Valor mientras se arrastra la barra de progreso (para que no "salte").
  double? _dragSeconds;

  @override
  void initState() {
    super.initState();
    if (widget.initialPath != null) {
      _service.loadPath(widget.initialPath!, widget.initialName ?? 'Canción');
    }
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = _service.player;

    return Scaffold(
      appBar: AppBar(title: const Text('Reproducir MP3'), centerTitle: true),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _service,
          builder: (context, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                children: [
                  if (_service.error != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _service.error!,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Icon(
                    Icons.music_note,
                    size: 96,
                    color: theme.colorScheme.primary
                        .withValues(alpha: _service.hasFile ? 1 : 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _service.fileName ?? 'Ningún archivo abierto',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 24),
                  if (_service.hasFile) _buildKaraokeToggle(theme),
                  const SizedBox(height: 12),
                  if (_service.hasFile) _buildPitchControl(theme),
                  const SizedBox(height: 16),
                  if (_service.hasFile) _buildProgress(player),
                  if (_service.hasFile) _buildControls(player),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _service.pickAndLoad,
                    icon: const Icon(Icons.folder_open),
                    label: Text(
                      _service.hasFile ? 'Abrir otro MP3' : 'Abrir un MP3',
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildKaraokeToggle(ThemeData theme) {
    if (_service.processing) {
      return const Column(
        children: [
          Text('Atenuando la voz… (decodificando la canción)'),
          SizedBox(height: 12),
          LinearProgressIndicator(),
        ],
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.mic_off),
            title: const Text('Atenuar voz (modo fiesta)'),
            subtitle: const Text('Calidad básica: baja la voz al instante, pero '
                'puede sonar metálico. Para divertirse suele bastar dejarlo '
                'apagado y cantar sobre la canción original. La separación '
                'limpia llega con la versión de PC (Demucs).'),
            value: _service.voiceAttenuated,
            onChanged: (v) => _service.setVoiceAttenuated(v),
          ),
          if (_service.voiceAttenuated)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  const Text('Intensidad'),
                  Expanded(
                    child: Slider(
                      value: _service.strength,
                      min: 0.0,
                      max: 1.0,
                      divisions: 10,
                      label: '${(_service.strength * 100).round()}%',
                      onChanged: (v) => _service.setStrength(v),
                    ),
                  ),
                  Text('${(_service.strength * 100).round()}%'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPitchControl(ThemeData theme) {
    final n = _service.semitones;
    final label = n == 0 ? '0' : (n > 0 ? '+$n' : '$n');
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.music_note),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Tono (sin cambiar la velocidad)'),
            ),
            IconButton.outlined(
              onPressed: n > -6 ? () => _service.setSemitones(n - 1) : null,
              icon: const Icon(Icons.remove),
            ),
            SizedBox(
              width: 44,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
            ),
            IconButton.outlined(
              onPressed: n < 6 ? () => _service.setSemitones(n + 1) : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress(AudioPlayer player) {
    return StreamBuilder<Duration?>(
      stream: player.durationStream,
      builder: (context, durationSnapshot) {
        final total = durationSnapshot.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final totalSeconds = total.inMilliseconds / 1000.0;
            final currentSeconds =
                _dragSeconds ?? (position.inMilliseconds / 1000.0);

            return Column(
              children: [
                Slider(
                  value: currentSeconds.clamp(0.0, totalSeconds),
                  max: totalSeconds > 0 ? totalSeconds : 1.0,
                  onChanged: (value) => setState(() => _dragSeconds = value),
                  onChangeEnd: (value) {
                    player.seek(Duration(milliseconds: (value * 1000).round()));
                    setState(() => _dragSeconds = null);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(position)),
                      Text(_fmt(total)),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildControls(AudioPlayer player) {
    return StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final playing = state?.playing ?? false;
        final completed = state?.processingState == ProcessingState.completed;

        return IconButton.filled(
          iconSize: 48,
          onPressed: () {
            if (completed) {
              player.seek(Duration.zero);
              player.play();
            } else if (playing) {
              player.pause();
            } else {
              player.play();
            }
          },
          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
        );
      },
    );
  }
}
