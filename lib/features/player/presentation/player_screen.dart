import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../data/audio_file_service.dart';

/// Pantalla del paso 3: abrir y reproducir un MP3 propio desde el celular,
/// con play/pausa y barra de progreso.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final AudioFileService _service = AudioFileService();

  // Valor mientras se arrastra la barra de progreso (para que no "salte").
  double? _dragSeconds;

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
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  if (_service.error != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 16),
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
                  const Spacer(),
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
                  const SizedBox(height: 16),
                  if (_service.hasFile) _buildProgress(player),
                  if (_service.hasFile) _buildControls(player),
                  const Spacer(),
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
      return Column(
        children: [
          const Text('Atenuando la voz…'),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: _service.processingProgress),
          const SizedBox(height: 4),
          Text('${(_service.processingProgress * 100).toStringAsFixed(0)} %'),
        ],
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      child: SwitchListTile(
        secondary: const Icon(Icons.mic_off),
        title: const Text('Atenuar voz (karaoke)'),
        subtitle: const Text('Baja la voz para cantar encima. Es instantáneo '
            'pero imperfecto según la grabación.'),
        value: _service.voiceAttenuated,
        onChanged: (v) => _service.setVoiceAttenuated(v),
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
