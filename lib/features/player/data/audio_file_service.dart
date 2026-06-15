import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'voice_attenuation_processor.dart';

/// Abre un archivo de audio propio del celular y lo reproduce, con opción de
/// atenuar la voz (modo karaoke) por cancelación de fase.
///
/// Paso 3 y 4 del README (Modo Karaoke Rápido): la app ABRE archivos del
/// usuario (no descarga de plataformas) y baja la voz con un filtro liviano.
class AudioFileService extends ChangeNotifier {
  /// Reproductor expuesto para que la UI escuche sus streams
  /// (posición, duración, estado de reproducción).
  final AudioPlayer player = AudioPlayer();

  final VoiceAttenuationProcessor _processor = VoiceAttenuationProcessor();

  String? _fileName;
  String? _originalPath;
  String? _processedPath;

  bool _voiceAttenuated = false;
  bool _processing = false;
  double _processingProgress = 0;
  String? _error;

  /// Nombre del archivo cargado, o `null` si todavía no se abrió ninguno.
  String? get fileName => _fileName;

  /// true si hay una canción cargada lista para reproducir.
  bool get hasFile => _fileName != null;

  /// true si está sonando con la voz atenuada (modo karaoke).
  bool get voiceAttenuated => _voiceAttenuated;

  /// true mientras se procesa la atenuación (la primera vez).
  bool get processing => _processing;

  /// Avance del procesamiento, de 0 a 1.
  double get processingProgress => _processingProgress;

  /// Mensaje de error legible, o `null` si todo va bien.
  String? get error => _error;

  /// Abre el selector del sistema, deja elegir un audio y lo carga.
  Future<void> pickAndLoad() async {
    _error = null;
    notifyListeners();

    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.audio);
      final path = result?.files.single.path;
      if (path == null) {
        // El usuario canceló la selección.
        return;
      }

      _fileName = result!.files.single.name;
      _originalPath = path;
      _processedPath = null;
      _voiceAttenuated = false;
      await player.setAudioSource(AudioSource.uri(Uri.file(path)));
      notifyListeners();
    } catch (e) {
      _error = 'No se pudo abrir el archivo: $e';
      notifyListeners();
    }
  }

  /// Activa o desactiva la atenuación de voz, recargando la pista que suena
  /// y conservando la posición y si estaba reproduciendo.
  Future<void> setVoiceAttenuated(bool value) async {
    final original = _originalPath;
    if (original == null || _processing) return;

    _error = null;
    final wasPlaying = player.playing;
    final position = player.position;

    try {
      String target;
      if (value) {
        if (_processedPath == null) {
          _processing = true;
          _processingProgress = 0;
          notifyListeners();
          _processedPath = await _processor.process(
            original,
            onProgress: (p) {
              _processingProgress = p;
              notifyListeners();
            },
          );
          _processing = false;
        }
        target = _processedPath!;
      } else {
        target = original;
      }

      _voiceAttenuated = value;
      notifyListeners();

      await player.setAudioSource(
        AudioSource.uri(Uri.file(target)),
        initialPosition: position,
      );
      if (wasPlaying) player.play();
    } catch (e) {
      _processing = false;
      _voiceAttenuated = false;
      _error = 'No se pudo atenuar la voz: $e';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }
}
