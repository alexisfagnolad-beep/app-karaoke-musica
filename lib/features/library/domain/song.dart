/// Una canción de la biblioteca: archivo propio del usuario etiquetado por
/// género e instrumentos. Puede tener una melodía de referencia (de la PC)
/// para cantar con puntaje sin volver a elegir archivos.
class Song {
  final String id;
  final String title;

  /// Ruta al archivo de audio (copiado al almacenamiento de la app).
  final String path;

  /// Género, o `null` si no se asignó.
  final String? genre;

  /// Instrumentos disponibles para esta canción (Voz, Guitarra, etc.).
  final List<String> instruments;

  /// Ruta a la melodía de referencia (`melody.json`) si se cargó, para
  /// cantar con puntaje. `null` si es solo una canción para reproducir.
  final String? melodyPath;

  final DateTime addedAt;

  const Song({
    required this.id,
    required this.title,
    required this.path,
    required this.genre,
    required this.instruments,
    required this.addedAt,
    this.melodyPath,
  });

  /// true si tiene melodía de referencia → se puede cantar con puntaje.
  bool get canScore => melodyPath != null;

  Song copyWith({
    String? title,
    String? genre,
    bool clearGenre = false,
    List<String>? instruments,
    String? melodyPath,
    bool clearMelody = false,
  }) =>
      Song(
        id: id,
        title: title ?? this.title,
        path: path,
        genre: clearGenre ? null : (genre ?? this.genre),
        instruments: instruments ?? this.instruments,
        melodyPath: clearMelody ? null : (melodyPath ?? this.melodyPath),
        addedAt: addedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'path': path,
        'genre': genre,
        'instruments': instruments,
        'melodyPath': melodyPath,
        'addedAt': addedAt.toIso8601String(),
      };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
        id: json['id'] as String,
        title: json['title'] as String,
        path: json['path'] as String,
        genre: json['genre'] as String?,
        instruments:
            (json['instruments'] as List?)?.cast<String>() ?? const [],
        melodyPath: json['melodyPath'] as String?,
        addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}
