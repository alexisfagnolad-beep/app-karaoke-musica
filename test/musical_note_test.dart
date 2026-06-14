import 'package:flutter_test/flutter_test.dart';
import 'package:karaoke_musica/features/pitch/domain/musical_note.dart';

void main() {
  group('MusicalNote.fromFrequency', () {
    test('440 Hz es A4 perfectamente afinado', () {
      final note = MusicalNote.fromFrequency(440.0)!;
      expect(note.name, 'A');
      expect(note.octave, 4);
      expect(note.midi, 69);
      expect(note.cents.abs(), lessThan(0.01));
      expect(note.isInTune(), isTrue);
    });

    test('261.63 Hz es C4 (Do central)', () {
      final note = MusicalNote.fromFrequency(261.63)!;
      expect(note.name, 'C');
      expect(note.octave, 4);
      expect(note.midi, 60);
      expect(note.cents.abs(), lessThan(2.0));
    });

    test('466.16 Hz es A#4', () {
      final note = MusicalNote.fromFrequency(466.16)!;
      expect(note.name, 'A#');
      expect(note.octave, 4);
      expect(note.midi, 70);
    });

    test('un poco por encima de A4 da cents positivos (alto)', () {
      final note = MusicalNote.fromFrequency(445.0)!;
      expect(note.name, 'A');
      expect(note.cents, greaterThan(0));
    });

    test('un poco por debajo de A4 da cents negativos (bajo)', () {
      final note = MusicalNote.fromFrequency(435.0)!;
      expect(note.name, 'A');
      expect(note.cents, lessThan(0));
    });

    test('frecuencias no válidas devuelven null', () {
      expect(MusicalNote.fromFrequency(0), isNull);
      expect(MusicalNote.fromFrequency(-10), isNull);
      expect(MusicalNote.fromFrequency(double.nan), isNull);
    });

    test('una octava arriba de A4 es A5 (880 Hz)', () {
      final note = MusicalNote.fromFrequency(880.0)!;
      expect(note.name, 'A');
      expect(note.octave, 5);
      expect(note.midi, 81);
    });
  });
}
