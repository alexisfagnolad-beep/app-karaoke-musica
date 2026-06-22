import 'dart:math' as math;

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
  String? _decodedPath; // WAV decodificado (cacheado para reprocesar rápido)
  String? _processedPath;

  bool _voiceAttenuated = false;
  bool _processing = false;
  double _strength = 0.9; // intensidad de la atenuación (0..1)
  int _semitones = 0; // cambio de tono (sin alterar la velocidad)
  String? _error;

  /// Nombre del archivo cargado, o `null` si todavía no se abrió ninguno.
  String? get fileName => _fileName;

  /// true si hay una canción cargada lista para reproducir.
  bool get hasFile => _fileName != null;

  /// true si está sonando con la voz atenuada (modo karaoke).
  bool get voiceAttenuated => _voiceAttenuated;

  /// true mientras se procesa la atenuación (la primera vez).
  bool get processing => _processing;

  /// Intensidad actual de la atenuación (0..1).
  double get strength => _strength;

  /// Cambio de tono en semitonos (negativo = más grave, positivo = más agudo).
  int get semitones => _semitones;

  /// Aplica el tono actual al reproductor (factor = 2^(semitonos/12)).
  /// Cambia la altura SIN alterar la velocidad. Soportado en Android.
  Future<void> _applyPitch() async {
    try {
      await player.setPitch(math.pow(2, _semitones / 12).toDouble());
    } catch (_) {
      // Si la plataforma no soporta pitch, lo ignoramos.
    }
  }

  /// Cambia el tono en semitonos (rango -6..+6) sin cambiar la velocidad.
  Future<void> setSemitones(int value) async {
    _semitones = value.clamp(-6, 6);
    notifyListeners();
    await _applyPitch();
  }

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
      _decodedPath = null;
      _processedPath = null;
      _voiceAttenuated = false;
      await player.setAudioSource(AudioSource.uri(Uri.file(path)));
      await _applyPitch();
      notifyListeners();
    } catch (e) {
      _error = 'No se pudo abrir el archivo: $e';
      notifyListeners();
    }
  }

  /// Carga directamente una canción por su ruta (p. ej. desde la biblioteca).
  Future<void> loadPath(String path, String name) async {
    _error = null;
    _fileName = name;
    _originalPath = path;
    _decodedPath = null;
    _processedPath = null;
    _voiceAttenuated = false;
    try {
      await player.setAudioSource(AudioSource.uri(Uri.file(path)));
      await _applyPitch();
    } catch (e) {
      _error = 'No se pudo abrir la canción: $e';
    }
    notifyListeners();
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
        _processing = true;
        notifyListeners();
        // Decodificamos una sola vez y cacheamos el WAV.
        _decodedPath ??= await _processor.decode(original);
        _processedPath = await _processor.attenuate(_decodedPath!, _strength);
        _processing = false;
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
      await _applyPitch();
      if (wasPlaying) player.play();
    } catch (e) {
      _processing = false;
      _voiceAttenuated = false;
      _error = 'No se pudo atenuar la voz: $e';
      notifyListeners();
    }
  }

  /// Cambia la intensidad de la atenuación. Si está activada, reprocesa
  /// (rápido, sin re-decodificar) y recarga conservando la posición.
  Future<void> setStrength(double value) async {
    _strength = value.clamp(0.0, 1.0);
    notifyListeners();
    if (!_voiceAttenuated || _processing || _decodedPath == null) return;

    final wasPlaying = player.playing;
    final position = player.position;
    try {
      _processing = true;
      notifyListeners();
      _processedPath = await _processor.attenuate(_decodedPath!, _strength);
      _processing = false;
      notifyListeners();
      await player.setAudioSource(
        AudioSource.uri(Uri.file(_processedPath!)),
        initialPosition: position,
      );
      await _applyPitch();
      if (wasPlaying) player.play();
    } catch (e) {
      _processing = false;
      _error = 'No se pudo aplicar la intensidad: $e';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }
}
