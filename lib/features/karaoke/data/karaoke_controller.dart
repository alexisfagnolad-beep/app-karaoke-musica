import 'dart:math' as math;

import 'package:flutter/foundation.dart';
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

  KaraokeResult? melodicResult;
  RhythmResult? rhythmResult;

  bool get running => _running;
  String? get error => _error;
  MusicalNote? get sung => _sung;
  MelodyFrame? get target => _target;
  int get hits => _hits;
  bool get finished => melodicResult != null || rhythmResult != null;

  Future<void> loadMelodic(String instrumentalPath, Melody melody) async {
    _melody = melody;
    _rhythm = null;
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
    notifyListeners();

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
      await _capture.start(_onAudio, _onError,
          sampleRate: sampleRate, bufferSize: bufferSize);
      _running = true;
      await player.seek(Duration.zero);
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
      _samples.add(PerformanceSample(t, midi));
      _target = _melody!.frameAt(t);
    }
    notifyListeners();
  }

  void _onError(Object e) {
    _error = 'Error de audio: $e';
    notifyListeners();
  }

  Future<void> finish() async {
    if (!_running) return;
    _running = false;
    try {
      await _capture.stop();
    } catch (_) {}
    await player.stop();

    if (isRhythm) {
      rhythmResult = scoreRhythm(_rhythm!.onsets, _userOnsets);
    } else {
      melodicResult = scorePerformance(_melody!, _samples);
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
