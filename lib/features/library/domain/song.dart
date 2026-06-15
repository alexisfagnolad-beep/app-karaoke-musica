/// Una canción de la biblioteca: archivo propio del usuario etiquetado por
/// género e instrumentos disponibles.
class Song {
  final String id;
  final String title;

  /// Ruta al archivo de audio (copiado al almacenamiento de la app).
  final String path;

  /// Género, o `null` si no se asignó.
  final String? genre;

  /// Instrumentos disponibles para esta canción (Voz, Guitarra, etc.).
  final List<String> instruments;

  final DateTime addedAt;

  const Song({
    required this.id,
    required this.title,
    required this.path,
    required this.genre,
    required this.instruments,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'path': path,
        'genre': genre,
        'instruments': instruments,
        'addedAt': addedAt.toIso8601String(),
      };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
        id: json['id'] as String,
        title: json['title'] as String,
        path: json['path'] as String,
        genre: json['genre'] as String?,
        instruments:
            (json['instruments'] as List?)?.cast<String>() ?? const [],
        addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}
