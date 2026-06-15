import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../player/presentation/player_screen.dart';
import '../data/library_repository.dart';
import '../domain/song.dart';

/// Biblioteca de canciones agrupadas por género y filtrables por instrumento.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final LibraryRepository _repo = LibraryRepository();
  String? _genre;
  String? _instrument;

  @override
  void initState() {
    super.initState();
    _repo.load();
  }

  @override
  void dispose() {
    _repo.dispose();
    super.dispose();
  }

  Future<void> _addSong() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    final path = result?.files.single.path;
    if (path == null) return;
    final defaultTitle = result!.files.single.name;
    if (!mounted) return;

    final data = await showModalBottomSheet<_NewSongData>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddSongSheet(repo: _repo, defaultTitle: defaultTitle),
    );
    if (data == null) return;

    await _repo.addSong(
      sourcePath: path,
      title: data.title,
      genre: data.genre,
      instruments: data.instruments,
    );
  }

  void _openSong(Song song) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlayerScreen(initialPath: song.path, initialName: song.title),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Biblioteca'), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSong,
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _repo,
          builder: (context, _) {
            if (!_repo.loaded) {
              return const Center(child: CircularProgressIndicator());
            }
            final songs = LibraryRepository.filter(
              _repo.songs,
              genre: _genre,
              instrument: _instrument,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _filtersBar(),
                const Divider(height: 1),
                Expanded(
                  child: songs.isEmpty
                      ? _emptyState()
                      : ListView.builder(
                          itemCount: songs.length,
                          itemBuilder: (context, i) => _songTile(songs[i]),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _filtersBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 4),
            child: Text('Género'),
          ),
          Wrap(
            spacing: 8,
            children: [
              _choice('Todos', _genre == null, () => setState(() => _genre = null)),
              for (final g in _repo.genres)
                _choice(g, _genre == g, () => setState(() => _genre = g)),
            ],
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 4),
            child: Text('Instrumento'),
          ),
          Wrap(
            spacing: 8,
            children: [
              _choice('Todos', _instrument == null,
                  () => setState(() => _instrument = null)),
              for (final ins in LibraryRepository.instrumentsCatalog)
                _choice(ins, _instrument == ins,
                    () => setState(() => _instrument = ins)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _choice(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }

  Widget _songTile(Song song) {
    final subtitle = [
      if (song.genre != null) song.genre!,
      if (song.instruments.isNotEmpty) song.instruments.join(', '),
    ].join('  •  ');
    return ListTile(
      leading: const Icon(Icons.music_note),
      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      onTap: () => _openSong(song),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _confirmDelete(song),
      ),
    );
  }

  Future<void> _confirmDelete(Song song) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Quitar de la biblioteca'),
        content: Text('¿Quitar "${song.title}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Quitar')),
        ],
      ),
    );
    if (ok == true) await _repo.deleteSong(song);
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.library_music,
                size: 64,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              _repo.songs.isEmpty
                  ? 'Tu biblioteca está vacía.\nTocá "Agregar" para sumar canciones.'
                  : 'No hay canciones con ese filtro.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NewSongData {
  _NewSongData(this.title, this.genre, this.instruments);
  final String title;
  final String? genre;
  final List<String> instruments;
}

/// Hoja inferior para cargar título, género e instrumentos de una canción.
class _AddSongSheet extends StatefulWidget {
  const _AddSongSheet({required this.repo, required this.defaultTitle});

  final LibraryRepository repo;
  final String defaultTitle;

  @override
  State<_AddSongSheet> createState() => _AddSongSheetState();
}

class _AddSongSheetState extends State<_AddSongSheet> {
  late final TextEditingController _title =
      TextEditingController(text: widget.defaultTitle);
  String? _genre;
  final Set<String> _instruments = {};

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _newGenre() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nuevo género'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ej. Cumbia'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Agregar')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      widget.repo.addGenre(name);
      setState(() => _genre = name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Agregar canción',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Título',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Género'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final g in widget.repo.genres)
                  ChoiceChip(
                    label: Text(g),
                    selected: _genre == g,
                    onSelected: (_) => setState(() => _genre = g),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Nuevo'),
                  onPressed: _newGenre,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Instrumentos disponibles'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final ins in LibraryRepository.instrumentsCatalog)
                  FilterChip(
                    label: Text(ins),
                    selected: _instruments.contains(ins),
                    onSelected: (sel) => setState(() {
                      if (sel) {
                        _instruments.add(ins);
                      } else {
                        _instruments.remove(ins);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final title = _title.text.trim().isEmpty
                      ? widget.defaultTitle
                      : _title.text.trim();
                  Navigator.pop(
                    context,
                    _NewSongData(title, _genre, _instruments.toList()),
                  );
                },
                child: const Text('Guardar en la biblioteca'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
