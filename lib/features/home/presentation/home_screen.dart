import 'package:flutter/material.dart';

import '../../karaoke/presentation/practice_setup_screen.dart';
import '../../library/presentation/library_screen.dart';
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
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(onUpdates: _openUpdates),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  children: [
                    _MenuCard(
                      icon: Icons.mic,
                      color: const Color(0xFF7C4DFF),
                      title: 'Afinación en vivo',
                      subtitle: 'Cantá y mirá tu nota y los cents en tiempo real.',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LivePitchScreen()),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _MenuCard(
                      icon: Icons.library_music,
                      color: const Color(0xFF1DB6A2),
                      title: 'Biblioteca',
                      subtitle: 'Tus canciones por género e instrumento.',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LibraryScreen()),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _MenuCard(
                      icon: Icons.stars,
                      color: const Color(0xFFE0457B),
                      title: 'Práctica con puntaje',
                      subtitle: 'Cantá o tocá sobre un proyecto de la PC y puntuá.',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const PracticeSetupScreen()),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _MenuCard(
                      icon: Icons.music_note,
                      color: const Color(0xFFFF8A3D),
                      title: 'Reproducir un MP3',
                      subtitle: 'Abrí una canción propia desde tu celular.',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PlayerScreen()),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _MenuCard(
                      icon: Icons.system_update,
                      color: const Color(0xFF4D9BFF),
                      title: 'Actualizaciones',
                      subtitle: 'Buscar e instalar la última versión de la app.',
                      onTap: _openUpdates,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text(
                  'Modo Karaoke Rápido — funciona sin internet',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
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

/// Encabezado con degradé, nombre y subtítulo de la app.
class _Header extends StatelessWidget {
  const _Header({required this.onUpdates});

  final VoidCallback onUpdates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 12, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7C4DFF), Color(0xFF4D9BFF)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.graphic_eq, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Karaoke Música',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Cantá, practicá y afiná',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Actualizaciones',
            icon: const Icon(Icons.system_update, color: Colors.white),
            onPressed: onUpdates,
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
