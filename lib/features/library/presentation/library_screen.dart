import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../shared/ui/app_ui.dart';
import '../../karaoke/domain/lyrics.dart';
import '../../karaoke/domain/melody.dart';
import '../../karaoke/domain/rhythm.dart';
import '../../karaoke/presentation/drum_learn_screen.dart';
import '../../karaoke/presentation/karaoke_screen.dart';
import '../../karaoke/presentation/piano_learn_screen.dart';
import '../../player/presentation/player_screen.dart';
import '../data/library_repository.dart';
import '../domain/song.dart';

/// Biblioteca de canciones agrupadas por género y filtrables por instrumento.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, this.initialInstrument, this.titleOverride});

  /// Filtro de instrumento inicial (ej. 'Voz' para Cantar). null = sin filtro.
  final String? initialInstrument;

  /// Título de la barra (ej. 'Cantar', 'Practicar'). null = 'Biblioteca'.
  final String? titleOverride;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final LibraryRepository _repo = LibraryRepository();
  final TextEditingController _searchCtrl = TextEditingController();
  String? _genre;
  String? _instrument;
  String _search = '';
  bool _sortByTitle = false; // false = más recientes primero

  @override
  void initState() {
    super.initState();
    _instrument = widget.initialInstrument;
    _repo.load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _repo.dispose();
    super.dispose();
  }

  List<Song> _visibleSongs() {
    var list = LibraryRepository.filter(
      _repo.songs,
      genre: _genre,
      instrument: _instrument,
    );
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((s) => s.title.toLowerCase().contains(q)).toList();
    }
    list.sort(
      (a, b) => _sortByTitle
          ? a.title.toLowerCase().compareTo(b.title.toLowerCase())
          : b.addedAt.compareTo(a.addedAt),
    );
    return list;
  }

  Future<void> _editSong(Song song) async {
    final data = await showModalBottomSheet<_NewSongData>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddSongSheet(repo: _repo, existing: song),
    );
    if (data == null) return;
    await _repo.updateSong(
      song.copyWith(
        title: data.title,
        genre: data.genre,
        clearGenre: data.genre == null,
        instruments: data.instruments,
      ),
    );
    // Si eligieron una melodía de referencia en la edición, la asociamos.
    if (data.melodyPath != null) {
      await _repo.attachMelody(song, data.melodyPath!);
    }
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
      melodySourcePath: data.melodyPath,
    );
  }

  /// Al tocar una canción: si tiene melodía de referencia, ofrecemos cantar con
  /// puntaje o solo reproducir; si no, abrimos el reproductor directo.
  void _openSong(Song song) {
    if (!song.canScore) {
      _play(song);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                song.isRhythm ? Icons.graphic_eq : Icons.stars,
                color: const Color(0xFFE0457B),
              ),
              title: Text(
                song.isRhythm ? 'Tocar con puntaje' : 'Cantar con puntaje',
              ),
              subtitle: Text(
                song.isRhythm
                    ? 'Seguí el ritmo sobre la pista y recibí un puntaje.'
                    : 'Cantá sobre la pista y recibí un puntaje.',
              ),
              onTap: () {
                Navigator.pop(sheetCtx);
                _practice(song);
              },
            ),
            if (!song.isRhythm)
              ListTile(
                leading: const Icon(Icons.lyrics, color: Color(0xFF4D9BFF)),
                title: const Text('Solo letra'),
                subtitle: const Text(
                  'Cantá tranqui con la letra, sin puntaje.',
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _practice(song, freeMode: true);
                },
              ),
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Reproducir'),
              subtitle: const Text('Solo escuchar la canción.'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _play(song);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _play(Song song) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PlayerScreen(initialPath: song.path, initialName: song.title),
      ),
    );
  }

  void _practice(Song song, {bool freeMode = false}) {
    Melody? melody;
    Rhythm? rhythm;
    Lyrics? lyrics;
    try {
      if (song.rhythmPath != null) {
        rhythm = Rhythm.fromJson(
          json.decode(File(song.rhythmPath!).readAsStringSync())
              as Map<String, dynamic>,
        );
      } else if (song.melodyPath != null) {
        melody = Melody.parse(File(song.melodyPath!).readAsStringSync());
      } else {
        return;
      }
      // Letra sincronizada opcional (solo aplica al modo melódico).
      if (melody != null && song.lyricsPath != null) {
        lyrics = Lyrics.parse(File(song.lyricsPath!).readAsStringSync());
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pude leer la referencia de puntaje.')),
      );
      return;
    }
    // Batería: pantalla dedicada estilo Guitar Hero (horizontal).
    if (rhythm != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DrumLearnScreen(
            instrumentalPath: song.path,
            title: song.title,
            rhythm: rhythm!,
          ),
        ),
      );
      return;
    }
    // Piano/teclado: pantalla dedicada estilo Yousician (horizontal).
    final isPiano = song.instruments.any((i) => i == 'Piano' || i == 'Teclado');
    if (melody != null && !freeMode && isPiano) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PianoLearnScreen(
            instrumentalPath: song.path,
            title: song.title,
            melody: melody!,
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KaraokeScreen(
          instrumentalPath: song.path,
          title: song.title,
          melody: melody,
          rhythm: rhythm,
          lyrics: lyrics,
          freeMode: freeMode,
          pianoView: isPiano,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: gradientAppBar(
        context,
        widget.titleOverride ?? 'Biblioteca',
        colors: const [AppColors.teal, AppColors.blue],
        actions: [
          PopupMenuButton<bool>(
            icon: const Icon(Icons.sort),
            tooltip: 'Ordenar',
            onSelected: (v) => setState(() => _sortByTitle = v),
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: false,
                checked: !_sortByTitle,
                child: const Text('Más recientes'),
              ),
              CheckedPopupMenuItem(
                value: true,
                checked: _sortByTitle,
                child: const Text('A–Z (título)'),
              ),
            ],
          ),
        ],
      ),
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
            final songs = _visibleSongs();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Buscar por nombre',
                      border: const OutlineInputBorder(),
                      suffixIcon: _search.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _search = '');
                              },
                            ),
                    ),
                  ),
                ),
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
              _choice(
                'Todos',
                _genre == null,
                () => setState(() => _genre = null),
              ),
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
              _choice(
                'Todos',
                _instrument == null,
                () => setState(() => _instrument = null),
              ),
              for (final ins in LibraryRepository.instrumentsCatalog)
                _choice(
                  ins,
                  _instrument == ins,
                  () => setState(() => _instrument = ins),
                ),
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
    final tags = [
      if (song.genre != null) song.genre!,
      if (song.instruments.isNotEmpty) song.instruments.join(', '),
    ].join('  •  ');
    final subtitleText = [
      if (song.canScore) 'Con puntaje',
      if (tags.isNotEmpty) tags,
    ].join('  •  ');
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: song.canScore
            ? const Color(0xFFE0457B).withValues(alpha: 0.15)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          song.canScore ? Icons.stars : Icons.music_note,
          color: song.canScore
              ? const Color(0xFFE0457B)
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitleText.isEmpty
          ? null
          : Text(subtitleText, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => _openSong(song),
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'edit') _editSong(song);
          if (v == 'delete') _confirmDelete(song);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Editar etiquetas')),
          PopupMenuItem(value: 'delete', child: Text('Quitar')),
        ],
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
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar'),
          ),
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
            Icon(
              Icons.library_music,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
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
  _NewSongData(this.title, this.genre, this.instruments, this.melodyPath);
  final String title;
  final String? genre;
  final List<String> instruments;

  /// Ruta al `melody.json` elegido (opcional), para cantar con puntaje.
  final String? melodyPath;
}

/// Hoja inferior para cargar título, género e instrumentos de una canción.
class _AddSongSheet extends StatefulWidget {
  const _AddSongSheet({
    required this.repo,
    this.defaultTitle = '',
    this.existing,
  });

  final LibraryRepository repo;
  final String defaultTitle;

  /// Si se pasa, la hoja edita esta canción (prefill).
  final Song? existing;

  @override
  State<_AddSongSheet> createState() => _AddSongSheetState();
}

class _AddSongSheetState extends State<_AddSongSheet> {
  late final TextEditingController _title = TextEditingController(
    text: widget.existing?.title ?? widget.defaultTitle,
  );
  late String? _genre = widget.existing?.genre;
  late final Set<String> _instruments = {...?widget.existing?.instruments};

  /// `melody.json` recién elegido en esta hoja (ruta de origen).
  String? _melodyPath;

  bool get _isEditing => widget.existing != null;

  /// true si ya hay melodía: la que traía la canción o una recién elegida.
  bool get _hasMelody =>
      _melodyPath != null || widget.existing?.canScore == true;

  Future<void> _pickMelody() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() => _melodyPath = path);
  }

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
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Agregar'),
          ),
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
            Text(
              _isEditing ? 'Editar canción' : 'Agregar canción',
              style: Theme.of(context).textTheme.titleLarge,
            ),
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
                    // Tocar el seleccionado lo deselecciona (sin género).
                    onSelected: (_) =>
                        setState(() => _genre = _genre == g ? null : g),
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
            const SizedBox(height: 20),
            const Text('Melodía de referencia (opcional)'),
            const SizedBox(height: 4),
            Text(
              'Es el archivo melody.json que genera la PC. Si lo agregás, vas a '
              'poder "Cantar con puntaje" directo desde la biblioteca.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickMelody,
              icon: Icon(_hasMelody ? Icons.check_circle : Icons.stars),
              label: Text(
                _melodyPath != null
                    ? 'Melodía elegida ✓'
                    : (widget.existing?.canScore == true
                          ? 'Reemplazar melodía'
                          : 'Elegir melody.json'),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: _hasMelody ? const Color(0xFFE0457B) : null,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  var title = _title.text.trim();
                  if (title.isEmpty) {
                    title = widget.existing?.title.isNotEmpty == true
                        ? widget.existing!.title
                        : (widget.defaultTitle.isEmpty
                              ? 'Canción'
                              : widget.defaultTitle);
                  }
                  Navigator.pop(
                    context,
                    _NewSongData(
                      title,
                      _genre,
                      _instruments.toList(),
                      _melodyPath,
                    ),
                  );
                },
                child: Text(
                  _isEditing ? 'Guardar cambios' : 'Guardar en la biblioteca',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
