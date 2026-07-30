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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 14),
                      child: Text(
                        '¿Qué querés hacer?',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    LayoutBuilder(
                      builder: (context, cons) {
                        final w = (cons.maxWidth - 14) / 2;
                        return Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            _FunTile(
                              size: w,
                              icon: Icons.mic_external_on,
                              label: 'Cantar',
                              colors: const [
                                Color(0xFFFF6FA5),
                                Color(0xFFE0457B),
                              ],
                              onTap: () => _push(
                                const LibraryScreen(
                                  initialInstrument: 'Voz',
                                  titleOverride: 'Cantar',
                                ),
                              ),
                            ),
                            _FunTile(
                              size: w,
                              icon: Icons.piano,
                              label: 'Instrumentos',
                              colors: const [
                                Color(0xFF3DE0C6),
                                Color(0xFF1DB6A2),
                              ],
                              onTap: () => _push(
                                const LibraryScreen(titleOverride: 'Practicar'),
                              ),
                            ),
                            _FunTile(
                              size: w,
                              icon: Icons.graphic_eq,
                              label: 'Afinar',
                              colors: const [
                                Color(0xFF9D7BFF),
                                Color(0xFF7C4DFF),
                              ],
                              onTap: () => _push(const LivePitchScreen()),
                            ),
                            _FunTile(
                              size: w,
                              icon: Icons.library_music,
                              label: 'Biblioteca',
                              colors: const [
                                Color(0xFF6FB6FF),
                                Color(0xFF4D9BFF),
                              ],
                              onTap: () => _push(const LibraryScreen()),
                            ),
                            _FunTile(
                              size: w,
                              icon: Icons.audiotrack,
                              label: 'Reproducir',
                              colors: const [
                                Color(0xFFFFB05C),
                                Color(0xFFFF8A3D),
                              ],
                              onTap: () => _push(const PlayerScreen()),
                            ),
                            _FunTile(
                              size: w,
                              icon: Icons.settings,
                              label: 'Ajustes',
                              colors: const [
                                Color(0xFF8A90A6),
                                Color(0xFF636A80),
                              ],
                              onTap: _openSettings,
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text(
                  '🎵 Cantá, tocá y aprendé — sin internet',
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
                  '¡Hola! ¿Aprendemos música? 🎶',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
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
/// Tile grande y colorido del inicio (pensado para chicos): degradé, ícono
/// grande en un círculo y etiqueta corta. Botón bien tocable.
class _FunTile extends StatelessWidget {
  const _FunTile({
    required this.size,
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
  });

  final double size;
  final IconData icon;
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.82,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: colors.last.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 30, color: Colors.white),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
