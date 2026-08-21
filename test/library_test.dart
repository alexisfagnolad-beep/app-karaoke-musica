import 'package:flutter_test/flutter_test.dart';
import 'package:karaoke_musica/features/library/data/library_repository.dart';
import 'package:karaoke_musica/features/library/domain/song.dart';

Song _song(String id, String? genre, List<String> instruments) => Song(
      id: id,
      title: 'Canción $id',
      path: '/tmp/$id.mp3',
      genre: genre,
      instruments: instruments,
      addedAt: DateTime(2026, 1, 1),
    );

void main() {
  test('Song round-trip JSON', () {
    final s = _song('1', 'Rock', ['Voz', 'Guitarra']);
    final back = Song.fromJson(s.toJson());
    expect(back.id, s.id);
    expect(back.title, s.title);
    expect(back.path, s.path);
    expect(back.genre, 'Rock');
    expect(back.instruments, ['Voz', 'Guitarra']);
  });

  group('LibraryRepository.filter', () {
    final songs = [
      _song('1', 'Rock', ['Voz', 'Guitarra']),
      _song('2', 'Jazz', ['Bajo']),
      _song('3', 'Rock', ['Bajo', 'Batería']),
      _song('4', null, ['Voz']),
    ];

    test('sin filtros devuelve todo', () {
      expect(LibraryRepository.filter(songs).length, 4);
    });

    test('filtra por género', () {
      final r = LibraryRepository.filter(songs, genre: 'Rock');
      expect(r.map((s) => s.id), ['1', '3']);
    });

    test('filtra por instrumento', () {
      final r = LibraryRepository.filter(songs, instrument: 'Bajo');
      expect(r.map((s) => s.id), ['2', '3']);
    });

    test('combina género e instrumento (AND)', () {
      final r =
          LibraryRepository.filter(songs, genre: 'Rock', instrument: 'Bajo');
      expect(r.map((s) => s.id), ['3']);
    });
  });
}
