import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';

import '../../pitch/domain/musical_note.dart';
import '../domain/melody.dart';
import '../domain/rhythm.dart';
import '../domain/scoring.dart';

/// Orquesta la práctica con puntaje: reproduce el instrumental, escucha el
/// micrófono (voz/instrumento) y, al terminar, puntúa contra la referencia.
///
/// Dos modos según la referencia cargada:
/// - melódico (Melody): compara afinación.
/// - rítmico (Rhythm): compara el tiempo de los golpes.
class KaraokeController extends ChangeNotifier {
  static const int sampleRate = 44100;
  static const int bufferSize = 2000;

  final AudioPlayer player = AudioPlayer();
  final FlutterAudioCapture _capture = FlutterAudioCapture();
  final PitchDetector _pitch = PitchDetector(
    audioSampleRate: sampleRate.toDouble(),
    bufferSize: bufferSize,
  );

  Melody? _melody;
  Rhythm? _rhythm;
  bool get isRhythm => _rhythm != null;

  final List<PerformanceSample> _samples = [];
  final List<double> _userOnsets = [];
  final OnsetDetector _onset = OnsetDetector();

  bool _capInited = false;
  bool _running = false;
  String? _error;

  MusicalNote? _sung;
  MelodyFrame? _target;
  int _hits = 0;

  // --- Estado del juego melódico en vivo (barras estilo karaoke) ---
  /// Notas de la melodía como barras (fraseo). Vacío en modo rítmico.
  List<MelodyNote> notes = const [];

  /// Cuánto se "iluminó" cada barra (0..1): fracción de su duración cantada
  /// afinada. Paralelo a [notes].
  List<double> noteLit = const [];

  /// Índice de la barra activa (la que suena ahora), o null.
  int? activeNote;

  /// Nota MIDI continua que está cantando el usuario ahora, o null.
  double? _livePitch;

  /// Puntaje en vivo, va sumando mientras cantás sobre la barra.
  double _liveScore = 0;

  /// Afinación respecto de la barra activa: -1 grave (abajo), +1 agudo
  /// (arriba), 0 afinado.
  int _direction = 0;

  double? _lastT;

  /// Semitonos de tolerancia para considerar que "pegaste" la barra.
  /// Amable a propósito (es un juego): con estar cerca, cuenta.
  static const double onPitchTolerance = 2.5;

  /// Efectos (vibración al acertar). Se puede silenciar desde Ajustes.
  static bool effectsEnabled = true;
  int _lastHapticNote = -1;

  KaraokeResult? melodicResult;
  RhythmResult? rhythmResult;

  /// Tiempo (seg) del último golpe del usuario (para el flash de la vista de
  /// batería). -1 si todavía no golpeó.
  double lastUserHitT = -1;

  /// Velocidad de reproducción (1.0 = normal). Bajarla ayuda a aprender; como
  /// todo se sincroniza con la posición del reproductor, las barras/notas
  /// siguen alineadas con el audio.
  double tempo = 1.0;

  /// Cambia el tempo (0.5..1.0). El tono se mantiene (no suena grave).
  Future<void> setTempo(double value) async {
    tempo = value.clamp(0.5, 1.0);
    try {
      await player.setSpeed(tempo);
    } catch (_) {}
    notifyListeners();
  }

  bool get running => _running;
  String? get error => _error;
  MusicalNote? get sung => _sung;
  MelodyFrame? get target => _target;
  Rhythm? get rhythmRef => _rhythm;
  int get hits => _hits;
  double? get livePitch => _livePitch;
  int get liveScore => _liveScore.floor();
  int get direction => _direction;
  bool get finished => melodicResult != null || rhythmResult != null;

  /// Modo libre ("Solo letra"): reproduce la pista con las barras y la letra
  /// como guía, pero SIN micrófono ni puntaje.
  bool freeMode = false;

  /// Dificultad: 0 = Fácil (barras muy resumidas), 1 = Normal, 2 = Exigente
  /// (sigue la melodía más de cerca). Cambia cuánto se simplifica la línea.
  int difficulty = 1;
  static const List<double> _diffMinDur = [0.30, 0.14, 0.09];
  static const List<double> _diffThresh = [1.0, 0.8, 0.6];
  static const List<int> _diffSmooth = [11, 9, 5];
  static const List<double> _diffMaxGap = [0.40, 0.35, 0.30];

  void _rebuildNotes() {
    final m = _melody;
    if (m == null) {
      notes = const [];
      noteLit = const [];
      return;
    }
    notes = m.notes(
      minDuration: _diffMinDur[difficulty],
      changeThreshold: _diffThresh[difficulty],
      smoothWindow: _diffSmooth[difficulty],
      maxGap: _diffMaxGap[difficulty],
    );
    noteLit = List<double>.filled(notes.length, 0);
  }

  /// Cambia la dificultad (rehace las barras). Solo cuando no está corriendo.
  void setDifficulty(int level) {
    if (_running) return;
    difficulty = level.clamp(0, 2);
    _rebuildNotes();
    notifyListeners();
  }

  Future<void> loadMelodic(
    String instrumentalPath,
    Melody melody, {
    bool freeMode = false,
    int difficulty = 1,
  }) async {
    _melody = melody;
    _rhythm = null;
    this.freeMode = freeMode;
    this.difficulty = difficulty.clamp(0, 2);
    _rebuildNotes();
    await player.setAudioSource(AudioSource.uri(Uri.file(instrumentalPath)));
    player.playerStateStream.listen(_onPlayerState);
  }

  Future<void> loadRhythmic(String instrumentalPath, Rhythm rhythm) async {
    _rhythm = rhythm;
    _melody = null;
    await player.setAudioSource(AudioSource.uri(Uri.file(instrumentalPath)));
    player.playerStateStream.listen(_onPlayerState);
  }

  void _onPlayerState(PlayerState state) {
    if (state.processingState == ProcessingState.completed && _running) {
      finish();
    }
  }

  Future<void> start() async {
    if (_running) return;
    _error = null;
    melodicResult = null;
    rhythmResult = null;
    _samples.clear();
    _userOnsets.clear();
    _onset.reset();
    _hits = 0;
    lastUserHitT = -1;
    _lastHapticNote = -1;
    _liveScore = 0;
    _direction = 0;
    _lastT = null;
    activeNote = null;
    _livePitch = null;
    if (noteLit.isNotEmpty) noteLit = List<double>.filled(notes.length, 0);
    notifyListeners();

    // Modo libre: solo reproducir (sin micrófono ni puntaje).
    if (freeMode) {
      try {
        _running = true;
        await player.seek(Duration.zero);
        await player.setSpeed(tempo);
        player.play();
        notifyListeners();
      } catch (e) {
        _error = 'No se pudo iniciar: $e';
        notifyListeners();
      }
      return;
    }

    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      _error = 'Necesito permiso de micrófono para puntuar.';
      notifyListeners();
      return;
    }

    try {
      if (!_capInited) {
        await _capture.init();
        _capInited = true;
      }
      await _capture.start(
        _onAudio,
        _onError,
        sampleRate: sampleRate,
        bufferSize: bufferSize,
      );
      _running = true;
      await player.seek(Duration.zero);
      await player.setSpeed(tempo);
      player.play();
      notifyListeners();
    } catch (e) {
      _error = 'No se pudo iniciar: $e';
      notifyListeners();
    }
  }

  Future<void> _onAudio(dynamic obj) async {
    if (!_running) return;
    final block = (obj as List).cast<double>();
    final t = player.position.inMilliseconds / 1000.0;

    if (isRhythm) {
      if (_onset.process(block, t)) {
        _userOnsets.add(t);
        _hits++;
        lastUserHitT = t;
        if (effectsEnabled) HapticFeedback.lightImpact();
      }
    } else {
      final result = await _pitch.getPitchFromFloatBuffer(block);
      double? midi;
      if (result.pitched && result.pitch > 0) {
        midi = 69 + 12 * (math.log(result.pitch / 440.0) / math.ln2);
        _sung = MusicalNote.fromFrequency(result.pitch);
      } else {
        _sung = null;
      }
      _livePitch = midi;
      _samples.add(PerformanceSample(t, midi));
      _target = _melody!.frameAt(t);
      _updateLiveGame(t, midi);
    }
    notifyListeners();
  }

  /// Actualiza barras activas, iluminación y puntaje en vivo.
  void _updateLiveGame(double t, double? midi) {
    final dt = _lastT == null ? 0.0 : (t - _lastT!).clamp(0.0, 0.25);
    _lastT = t;

    final idx = _noteIndexAt(t);
    activeNote = idx;

    if (idx == null || midi == null) {
      _direction = 0;
      return;
    }

    final diff = octaveFoldedDiff(midi, notes[idx].midi);
    if (diff.abs() <= onPitchTolerance) {
      _direction = 0;
      // Vibración corta al "enganchar" una barra nueva afinado.
      if (effectsEnabled && idx != _lastHapticNote) {
        _lastHapticNote = idx;
        HapticFeedback.selectionClick();
      }
      // Iluminar la barra en proporción al tiempo cantado afinado.
      final dur = notes[idx].duration;
      if (dur > 0) {
        noteLit[idx] = (noteLit[idx] + dt / dur).clamp(0.0, 1.0);
      }
      // Sumar puntos: más cerca de la nota y más sostenido = más puntaje.
      final closeness = (1.0 - diff.abs() / onPitchTolerance).clamp(0.0, 1.0);
      _liveScore += dt * (60 + 40 * closeness);
    } else {
      _direction = diff > 0 ? 1 : -1; // agudo (arriba) / grave (abajo).
    }
  }

  /// Índice de la barra que suena en el instante [t], o null.
  int? _noteIndexAt(double t) {
    for (var i = 0; i < notes.length; i++) {
      if (t >= notes[i].startT && t < notes[i].endT) return i;
    }
    return null;
  }

  void _onError(Object e) {
    _error = 'Error de audio: $e';
    notifyListeners();
  }

  Future<void> finish() async {
    if (!_running) return;
    _running = false;
    if (!freeMode) {
      try {
        await _capture.stop();
      } catch (_) {}
    }
    await player.stop();

    // Modo libre: no hay puntaje, solo termina.
    if (freeMode) {
      notifyListeners();
      return;
    }

    if (isRhythm) {
      rhythmResult = scoreRhythm(_rhythm!.onsets, _userOnsets);
    } else {
      // Puntúa contra las barras que se ven (coherente con la guía en pantalla).
      melodicResult = scoreAgainstNotes(notes, _samples);
    }
    notifyListeners();
  }

  Future<void> stop() => finish();

  @override
  void dispose() {
    if (_running) {
      _capture.stop();
    }
    player.dispose();
    super.dispose();
  }
}
