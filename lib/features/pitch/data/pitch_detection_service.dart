import 'package:flutter/foundation.dart';
import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';

import '../domain/musical_note.dart';

/// Servicio que captura el micrófono en vivo y detecta el pitch (afinación)
/// usando el algoritmo YIN, exponiendo la [MusicalNote] actual.
///
/// Es un [ChangeNotifier]: la UI escucha los cambios y se redibuja sola.
/// No usa el motor pesado de PC (Demucs/transcripción): corre 100% en el
/// celular, como pide el Modo Karaoke Rápido del README.
class PitchDetectionService extends ChangeNotifier {
  PitchDetectionService();

  /// Frecuencia de muestreo del micrófono.
  static const int sampleRate = 44100;

  /// Tamaño del buffer de muestras por callback. Más grande = más estable
  /// pero con algo más de latencia. ~2000 es un buen punto medio para voz.
  static const int bufferSize = 2000;

  final FlutterAudioCapture _audioCapture = FlutterAudioCapture();
  final PitchDetector _pitchDetector = PitchDetector(
    audioSampleRate: sampleRate.toDouble(),
    bufferSize: bufferSize,
  );

  bool _isInitialized = false;
  bool _isListening = false;
  MusicalNote? _note;
  String? _error;

  /// true mientras el micrófono está capturando.
  bool get isListening => _isListening;

  /// Última nota detectada, o `null` si no hay un tono claro (silencio/ruido).
  MusicalNote? get note => _note;

  /// Mensaje de error legible, o `null` si todo va bien.
  String? get error => _error;

  /// Pide permiso de micrófono y empieza a escuchar.
  Future<void> start() async {
    if (_isListening) return;

    _error = null;
    notifyListeners();

    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      _error = 'Permiso de micrófono denegado. Activalo en Ajustes.';
      notifyListeners();
      return;
    }

    try {
      // flutter_audio_capture exige init() una vez antes de start().
      if (!_isInitialized) {
        await _audioCapture.init();
        _isInitialized = true;
      }
      await _audioCapture.start(
        _onAudio,
        _onError,
        sampleRate: sampleRate,
        bufferSize: bufferSize,
      );
      _isListening = true;
      notifyListeners();
    } catch (e) {
      _error = 'No se pudo iniciar el micrófono: $e';
      notifyListeners();
    }
  }

  /// Detiene la captura del micrófono.
  Future<void> stop() async {
    if (!_isListening) return;
    await _audioCapture.stop();
    _isListening = false;
    _note = null;
    notifyListeners();
  }

  /// Callback con cada buffer de muestras PCM (Float64, normalizadas -1..1).
  Future<void> _onAudio(dynamic obj) async {
    final List<double> samples = (obj as List).cast<double>();

    final result = await _pitchDetector.getPitchFromFloatBuffer(samples);

    // result.pitched es false cuando no hay un tono lo bastante claro.
    if (result.pitched && result.pitch > 0) {
      _note = MusicalNote.fromFrequency(result.pitch);
    } else {
      _note = null;
    }
    notifyListeners();
  }

  void _onError(Object e) {
    _error = 'Error de audio: $e';
    notifyListeners();
  }

  @override
  void dispose() {
    if (_isListening) {
      _audioCapture.stop();
    }
    super.dispose();
  }
}
