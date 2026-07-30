import 'package:flutter/material.dart';

import '../../../shared/ui/app_ui.dart';
import '../../library/data/library_repository.dart';
import '../data/sync_service.dart';

/// Pantalla de sincronización con la PC: muestra las canciones que la PC
/// publicó en GitHub y permite bajarlas a la Biblioteca con un toque.
class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final LibraryRepository _repo = LibraryRepository();
  late final SyncService _sync = SyncService(_repo);

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _repo.load();
    await _sync.refresh();
  }

  @override
  void dispose() {
    _sync.dispose();
    _repo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: gradientAppBar(
        context,
        'Sincronizar con la PC',
        colors: const [AppColors.teal, AppColors.blue],
        actions: [
          IconButton(
            tooltip: 'Actualizar lista',
            icon: const Icon(Icons.refresh),
            onPressed: _sync.refresh,
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _sync,
          builder: (context, _) {
            if (_sync.status == SyncStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            return Column(
              children: [
                if (_sync.message != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _sync.status == SyncStatus.error
                          ? Theme.of(context).colorScheme.errorContainer
                          : Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_sync.message!),
                  ),
                Expanded(
                  child: _sync.projects.isEmpty
                      ? _empty()
                      : ListView.builder(
                          itemCount: _sync.projects.length,
                          itemBuilder: (context, i) => _tile(_sync.projects[i]),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tile(RemoteProject p) {
    final subtitle = [
      if (p.canScore) 'Con puntaje',
      if (p.genre != null) p.genre!,
      if (p.instruments.isNotEmpty) p.instruments.join(', '),
    ].join('  •  ');

    Widget trailing;
    if (p.downloading) {
      trailing = const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    } else if (p.imported) {
      trailing = const Icon(Icons.check_circle, color: Color(0xFF1DB6A2));
    } else {
      trailing = FilledButton.icon(
        onPressed: () => _sync.download(p),
        icon: const Icon(Icons.download, size: 18),
        label: const Text('Bajar'),
      );
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF1DB6A2).withValues(alpha: 0.15),
        child: Icon(
          p.canScore ? Icons.stars : Icons.music_note,
          color: const Color(0xFF1DB6A2),
        ),
      ),
      title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: trailing,
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_sync,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'No hay canciones publicadas todavía.\n\n'
              'En la PC, procesá una canción y tocá "Enviar al celular". '
              'Después volvé acá y tocá actualizar.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
