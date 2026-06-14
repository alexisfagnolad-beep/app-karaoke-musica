import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Abre un archivo de audio propio del celular y lo reproduce.
///
/// Paso 3 del README (Modo Karaoke Rápido): la app ABRE archivos del usuario,
/// no descarga de plataformas. Usa el selector nativo del sistema, así que no
/// necesita permisos de almacenamiento en Android moderno.
class AudioFileService extends ChangeNotifier {
  /// Reproductor expuesto para que la UI escuche sus streams
  /// (posición, duración, estado de reproducción).
  final AudioPlayer player = AudioPlayer();

  String? _fileName;

  /// Nombre del archivo cargado, o `null` si todavía no se abrió ninguno.
  String? get fileName => _fileName;

  String? _error;

  /// Mensaje de error legible, o `null` si todo va bien.
  String? get error => _error;

  /// true si hay una canción cargada lista para reproducir.
  bool get hasFile => _fileName != null;

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
      await player.setAudioSource(AudioSource.uri(Uri.file(path)));
      notifyListeners();
    } catch (e) {
      _error = 'No se pudo abrir el archivo: $e';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }
}
