import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/song.dart';

/// Maneja la biblioteca: lista de canciones, géneros e instrumentos, con
/// persistencia local en un JSON. Los archivos se copian al almacenamiento de
/// la app para que no se pierdan (los del selector suelen ser temporales).
class LibraryRepository extends ChangeNotifier {
  static const List<String> defaultGenres = [
    'Rock',
    'Folclore',
    'Jazz',
    'Balada',
    'Internacional',
    'Folclore mexicano',
  ];

  static const List<String> instrumentsCatalog = [
    'Voz',
    'Guitarra',
    'Bajo',
    'Teclado',
    'Batería',
  ];

  List<String> genres = List.of(defaultGenres);
  List<Song> songs = [];
  bool loaded = false;

  Future<File> _indexFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/library.json');
  }

  Future<Directory> _mediaDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final media = Directory('${dir.path}/library_media');
    if (!media.existsSync()) media.createSync(recursive: true);
    return media;
  }

  /// Carga la biblioteca del disco.
  Future<void> load() async {
    try {
      final file = await _indexFile();
      if (file.existsSync()) {
        final data = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
        final loadedGenres = (data['genres'] as List?)?.cast<String>();
        if (loadedGenres != null && loadedGenres.isNotEmpty) {
          genres = loadedGenres;
        }
        songs = ((data['songs'] as List?) ?? [])
            .map((e) => Song.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Si el índice está dañado, arrancamos vacío.
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final file = await _indexFile();
    file.writeAsStringSync(json.encode({
      'genres': genres,
      'songs': songs.map((s) => s.toJson()).toList(),
    }));
  }

  /// Agrega una canción copiando el archivo [sourcePath] al almacenamiento
  /// propio de la app.
  Future<void> addSong({
    required String sourcePath,
    required String title,
    String? genre,
    required List<String> instruments,
  }) async {
    final media = await _mediaDir();
    final ext = sourcePath.contains('.') ? sourcePath.split('.').last : 'mp3';
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final dest = '${media.path}/$id.$ext';
    File(sourcePath).copySync(dest);

    songs.insert(
      0,
      Song(
        id: id,
        title: title,
        path: dest,
        genre: genre,
        instruments: instruments,
        addedAt: DateTime.now(),
      ),
    );
    if (genre != null && genre.isNotEmpty && !genres.contains(genre)) {
      genres.add(genre);
    }
    await _save();
    notifyListeners();
  }

  Future<void> deleteSong(Song song) async {
    try {
      final f = File(song.path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
    songs.removeWhere((s) => s.id == song.id);
    await _save();
    notifyListeners();
  }

  void addGenre(String genre) {
    final g = genre.trim();
    if (g.isNotEmpty && !genres.contains(g)) {
      genres.add(g);
      _save();
      notifyListeners();
    }
  }

  /// Filtra por género y/o instrumento (AND). `null` = sin filtrar por ese eje.
  /// Función pura: testeable.
  static List<Song> filter(
    List<Song> all, {
    String? genre,
    String? instrument,
  }) {
    return all
        .where((s) =>
            (genre == null || s.genre == genre) &&
            (instrument == null || s.instruments.contains(instrument)))
        .toList();
  }
}
