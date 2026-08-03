import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/tone_synth.dart';

/// Reproduce sonidos de instrumento para tocar en pantalla desde el celular:
///  - Piano: notas SOSTENIDAS (una por dedo, multitáctil). Suenan mientras se
///    mantiene la tecla y se cortan al soltar.
///  - Batería: golpes "de a uno" (una pileta que rota).
///
/// Los tonos se sintetizan una sola vez (ToneSynth) y se guardan como WAV en la
/// carpeta temporal; no suma archivos al APK.
class InstrumentAudio {
  static const int _drumPoolSize = 4;
  static const int _heldPoolSize = 8;

  final List<AudioPlayer> _drumPool = [];
  int _drumNext = 0;
  bool _drumInited = false;

  final List<AudioPlayer> _heldFree = []; // reproductores libres
  final Map<int, AudioPlayer> _heldByPointer = {}; // dedo -> reproductor en uso
  bool _heldInited = false;

  final Map<int, String> _notePaths = {};
  final Map<int, String> _drumPaths = {};
  final Map<String, String> _piecePaths = {};
  Directory? _dir;

  Future<Directory> _tmp() async => _dir ??= await getTemporaryDirectory();

  void _ensureDrums() {
    if (_drumInited) return;
    _drumInited = true;
    for (var i = 0; i < _drumPoolSize; i++) {
      _drumPool.add(AudioPlayer());
    }
  }

  void _ensureHeld() {
    if (_heldInited) return;
    _heldInited = true;
    for (var i = 0; i < _heldPoolSize; i++) {
      _heldFree.add(AudioPlayer());
    }
  }

  /// Prepara de antemano el rango del teclado (notas sostenidas).
  Future<void> preloadNotes(Iterable<int> midis) async {
    try {
      final dir = await _tmp();
      for (final m in midis) {
        if (_notePaths.containsKey(m)) continue;
        final f = File('${dir.path}/note_s$m.wav');
        if (!await f.exists()) {
          await f.writeAsBytes(ToneSynth.sustainedTone(m));
        }
        _notePaths[m] = f.path;
      }
      _ensureHeld();
    } catch (_) {}
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
      _ensureDrums();
    } catch (_) {}
  }

  Future<String?> _notePath(int midi) async {
    final cached = _notePaths[midi];
    if (cached != null) return cached;
    try {
      final dir = await _tmp();
      final f = File('${dir.path}/note_s$midi.wav');
      if (!await f.exists()) {
        await f.writeAsBytes(ToneSynth.sustainedTone(midi));
      }
      return _notePaths[midi] = f.path;
    } catch (_) {
      return null;
    }
  }

  /// Aprieta una nota (dedo [pointer]): empieza a sonar sostenida.
  Future<void> noteOn(int pointer, int midi) async {
    final path = await _notePath(midi);
    if (path == null) return;
    _ensureHeld();
    await noteOff(pointer); // por si ese dedo ya tenía una nota
    if (_heldFree.isEmpty) return;
    final p = _heldFree.removeLast();
    _heldByPointer[pointer] = p;
    try {
      await p.setAudioSource(AudioSource.uri(Uri.file(path)));
      await p.seek(Duration.zero);
      p.play();
    } catch (_) {}
  }

  /// Suelta la nota del dedo [pointer]: corta el sonido y libera el reproductor.
  Future<void> noteOff(int pointer) async {
    final p = _heldByPointer.remove(pointer);
    if (p == null) return;
    try {
      await p.stop();
    } catch (_) {}
    _heldFree.add(p);
  }

  /// Corta todas las notas sostenidas.
  Future<void> allOff() async {
    for (final p in _heldByPointer.values.toList()) {
      try {
        await p.stop();
      } catch (_) {}
      _heldFree.add(p);
    }
    _heldByPointer.clear();
  }

  Future<void> playDrum(int band) async {
    final path = _drumPaths[band.clamp(0, 2)];
    if (path == null) return;
    await _playOneShot(path);
  }

  /// Toca el sonido propio de una pieza (tom1, crash, ride, …).
  Future<void> playPiece(String id) async {
    var path = _piecePaths[id];
    if (path == null) {
      try {
        final dir = await _tmp();
        final f = File('${dir.path}/tone_p$id.wav');
        if (!await f.exists()) {
          await f.writeAsBytes(ToneSynth.drumPieceTone(id));
        }
        path = _piecePaths[id] = f.path;
      } catch (_) {
        return;
      }
    }
    await _playOneShot(path);
  }

  Future<void> _playOneShot(String path) async {
    _ensureDrums();
    final p = _drumPool[_drumNext];
    _drumNext = (_drumNext + 1) % _drumPoolSize;
    try {
      await p.setAudioSource(AudioSource.uri(Uri.file(path)));
      await p.seek(Duration.zero);
      p.play();
    } catch (_) {}
  }

  Future<void> dispose() async {
    for (final p in [..._drumPool, ..._heldFree, ..._heldByPointer.values]) {
      try {
        await p.dispose();
      } catch (_) {}
    }
    _drumPool.clear();
    _heldFree.clear();
    _heldByPointer.clear();
  }
}
