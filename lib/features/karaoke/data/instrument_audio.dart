import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/tone_synth.dart';

/// Reproduce sonidos de instrumento "de a un toque" (baja latencia) para que,
/// al tocar el piano o la batería en pantalla, se escuche directamente desde el
/// celular. Usa una pequeña pileta de reproductores que rota, así dos toques
/// seguidos no se cortan entre sí.
///
/// Los tonos se sintetizan una sola vez (ToneSynth) y se guardan como WAV en la
/// carpeta temporal; no suma archivos al APK.
class InstrumentAudio {
  static const int _poolSize = 4;

  final List<AudioPlayer> _pool = [];
  int _next = 0;
  bool _inited = false;

  final Map<int, String> _notePaths = {};
  final Map<int, String> _drumPaths = {};
  Directory? _dir;

  Future<Directory> _tmp() async => _dir ??= await getTemporaryDirectory();

  Future<void> _ensurePool() async {
    if (_inited) return;
    _inited = true;
    for (var i = 0; i < _poolSize; i++) {
      _pool.add(AudioPlayer());
    }
  }

  /// Prepara de antemano las notas (rango del teclado) para que el primer toque
  /// no tenga demora.
  Future<void> preloadNotes(Iterable<int> midis) async {
    try {
      final dir = await _tmp();
      for (final m in midis) {
        if (_notePaths.containsKey(m)) continue;
        final f = File('${dir.path}/tone_n$m.wav');
        if (!await f.exists()) await f.writeAsBytes(ToneSynth.noteTone(m));
        _notePaths[m] = f.path;
      }
      await _ensurePool();
    } catch (_) {
      // Si falla la preparación, los toques simplemente no sonarán.
    }
  }

  Future<void> preloadDrums() async {
    try {
      final dir = await _tmp();
      for (var b = 0; b < 3; b++) {
        if (_drumPaths.containsKey(b)) continue;
        final f = File('${dir.path}/tone_d$b.wav');
        if (!await f.exists()) await f.writeAsBytes(ToneSynth.drumTone(b));
        _drumPaths[b] = f.path;
      }
      await _ensurePool();
    } catch (_) {}
  }

  Future<void> playNote(int midi) async {
    var path = _notePaths[midi];
    if (path == null) {
      try {
        final dir = await _tmp();
        final f = File('${dir.path}/tone_n$midi.wav');
        if (!await f.exists()) await f.writeAsBytes(ToneSynth.noteTone(midi));
        path = _notePaths[midi] = f.path;
      } catch (_) {
        return;
      }
    }
    await _play(path);
  }

  Future<void> playDrum(int band) async {
    final path = _drumPaths[band.clamp(0, 2)];
    if (path == null) return;
    await _play(path);
  }

  Future<void> _play(String path) async {
    try {
      await _ensurePool();
      final p = _pool[_next];
      _next = (_next + 1) % _poolSize;
      await p.setAudioSource(AudioSource.uri(Uri.file(path)));
      await p.seek(Duration.zero);
      p.play();
    } catch (_) {}
  }

  Future<void> dispose() async {
    for (final p in _pool) {
      try {
        await p.dispose();
      } catch (_) {}
    }
    _pool.clear();
  }
}
