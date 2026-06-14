import 'package:flutter/material.dart';

import '../../pitch/presentation/live_pitch_screen.dart';
import '../../player/presentation/player_screen.dart';
import '../../update/data/update_service.dart';
import '../../update/presentation/update_screen.dart';

/// Pantalla de inicio del Modo Karaoke Rápido. Por ahora ofrece las dos
/// funciones ya construidas; más adelante se integrarán en un único flujo
/// (abrir MP3 -> atenuar voz -> guía de afinación -> puntaje).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final UpdateService _updateService = UpdateService();

  @override
  void initState() {
    super.initState();
    _checkUpdatesOnStart();
  }

  /// Chequeo silencioso al arrancar: si hay token y una versión nueva,
  /// avisa con un cartel para actualizar con un toque.
  Future<void> _checkUpdatesOnStart() async {
    // Protegido: en entornos sin plugins (tests) no debe romper la pantalla.
    try {
      await _updateService.init();
      if (!_updateService.hasToken) return;
      await _updateService.checkForUpdate();
      if (!mounted) return;
      if (_updateService.status == UpdateStatus.available) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_updateService.message ?? 'Hay una versión nueva'),
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Actualizar',
              onPressed: _openUpdates,
            ),
          ),
        );
      }
    } catch (_) {
      // Silencioso: el usuario igual puede chequear a mano desde el inicio.
    }
  }

  void _openUpdates() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UpdateScreen(service: _updateService),
      ),
    );
  }

  @override
  void dispose() {
    _updateService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Karaoke Música'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Actualizaciones',
            icon: const Icon(Icons.system_update),
            onPressed: _openUpdates,
          ),
        ],
      ),
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
              const SizedBox(height: 16),
              _MenuCard(
                icon: Icons.system_update,
                title: 'Actualizaciones',
                subtitle: 'Buscar e instalar la última versión de la app.',
                onTap: _openUpdates,
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
