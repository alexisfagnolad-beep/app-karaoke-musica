import 'package:flutter/material.dart';

import '../../library/data/library_repository.dart';
import '../../library/presentation/library_screen.dart';
import '../../pitch/presentation/live_pitch_screen.dart';
import '../../player/presentation/player_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../sync/data/sync_service.dart';
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
  final LibraryRepository _libraryRepo = LibraryRepository();
  late final SyncService _syncService = SyncService(_libraryRepo);

  @override
  void initState() {
    super.initState();
    _checkUpdatesOnStart();
    _autoSyncOnStart();
  }

  /// Sincronización automática al abrir: baja e importa a la Biblioteca las
  /// canciones nuevas que se publicaron desde la PC. Así "enviar al celular"
  /// se siente automático: aparecen solas la próxima vez que abrís la app.
  Future<void> _autoSyncOnStart() async {
    try {
      await _libraryRepo.load();
      final added = await _syncService.autoDownloadNew();
      if (!mounted || added <= 0) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            added == 1
                ? 'Se agregó 1 canción nueva desde la PC.'
                : 'Se agregaron $added canciones nuevas desde la PC.',
          ),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Ver',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const LibraryScreen())),
          ),
        ),
      );
    } catch (_) {
      // Silencioso: si no hay internet o falla, no rompe el inicio.
    }
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
      MaterialPageRoute(builder: (_) => UpdateScreen(service: _updateService)),
    );
  }

  void _openSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  void dispose() {
    _updateService.dispose();
    _syncService.dispose();
    _libraryRepo.dispose();
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
              _Header(onSettings: _openSettings),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('Cantar y practicar'),
                    _MenuCard(
                      icon: Icons.mic_external_on,
                      color: const Color(0xFFE0457B),
                      title: 'Cantar (Karaoke)',
                      subtitle:
                          'Elegí una canción y cantá con puntaje o letra.',
                      onTap: () => _push(
                        const LibraryScreen(
                          initialInstrument: 'Voz',
                          titleOverride: 'Cantar',
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _MenuCard(
                      icon: Icons.music_note,
                      color: const Color(0xFF1DB6A2),
                      title: 'Practicar instrumentos',
                      subtitle: 'Bajo, guitarra o batería con puntaje.',
                      onTap: () => _push(
                        const LibraryScreen(titleOverride: 'Practicar'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _MenuCard(
                      icon: Icons.graphic_eq,
                      color: const Color(0xFF7C4DFF),
                      title: 'Afinación en vivo',
                      subtitle: 'Mirá tu nota y los cents en tiempo real.',
                      onTap: () => _push(const LivePitchScreen()),
                    ),
                    const SizedBox(height: 24),
                    const _SectionTitle('Tu música'),
                    _MenuCard(
                      icon: Icons.library_music,
                      color: const Color(0xFF4D9BFF),
                      title: 'Biblioteca',
                      subtitle:
                          'Todas tus canciones, por género e instrumento.',
                      onTap: () => _push(const LibraryScreen()),
                    ),
                    const SizedBox(height: 14),
                    _MenuCard(
                      icon: Icons.audiotrack,
                      color: const Color(0xFFFF8A3D),
                      title: 'Reproducir un MP3',
                      subtitle: 'Abrí una canción propia desde tu celular.',
                      onTap: () => _push(const PlayerScreen()),
                    ),
                    const SizedBox(height: 24),
                    const _SectionTitle('Más'),
                    _MenuCard(
                      icon: Icons.settings,
                      color: const Color(0xFF9AA0B4),
                      title: 'Ajustes',
                      subtitle:
                          'Sincronizar con la PC, actualizar y compartir.',
                      onTap: _openSettings,
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
  const _Header({required this.onSettings});

  final VoidCallback onSettings;

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
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: onSettings,
          ),
        ],
      ),
    );
  }
}

/// Título de sección en el inicio.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
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
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
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
