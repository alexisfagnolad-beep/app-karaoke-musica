import 'package:flutter/material.dart';

import '../../pitch/presentation/live_pitch_screen.dart';
import '../../player/presentation/player_screen.dart';

/// Pantalla de inicio del Modo Karaoke Rápido. Por ahora ofrece las dos
/// funciones ya construidas; más adelante se integrarán en un único flujo
/// (abrir MP3 -> atenuar voz -> guía de afinación -> puntaje).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Karaoke Música'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 12),
              _MenuCard(
                icon: Icons.mic,
                title: 'Afinación en vivo',
                subtitle: 'Cantá y mirá tu nota y los cents en tiempo real.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const LivePitchScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _MenuCard(
                icon: Icons.music_note,
                title: 'Reproducir un MP3',
                subtitle: 'Abrí una canción propia desde tu celular.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PlayerScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 40, color: theme.colorScheme.primary),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
