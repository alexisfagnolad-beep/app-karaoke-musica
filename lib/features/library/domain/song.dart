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
  /// cantar/tocar con puntaje melódico. `null` si no aplica.
  final String? melodyPath;

  /// Ruta a la referencia de ritmo (`rhythm.json`) si se cargó, para practicar
  /// batería/percusión con puntaje. `null` si no aplica.
  final String? rhythmPath;

  /// Id del proyecto remoto del que se sincronizó (de la PC), o `null` si se
  /// agregó a mano. Sirve para no importar dos veces la misma canción.
  final String? remoteId;

  final DateTime addedAt;

  const Song({
    required this.id,
    required this.title,
    required this.path,
    required this.genre,
    required this.instruments,
    required this.addedAt,
    this.melodyPath,
    this.rhythmPath,
    this.remoteId,
  });

  /// true si tiene alguna referencia → se puede practicar con puntaje.
  bool get canScore => melodyPath != null || rhythmPath != null;

  /// true si la práctica es de ritmo (batería) en vez de melódica.
  bool get isRhythm => rhythmPath != null && melodyPath == null;

  Song copyWith({
    String? title,
    String? genre,
    bool clearGenre = false,
    List<String>? instruments,
    String? melodyPath,
    bool clearMelody = false,
    String? rhythmPath,
    String? remoteId,
  }) => Song(
    id: id,
    title: title ?? this.title,
    path: path,
    genre: clearGenre ? null : (genre ?? this.genre),
    instruments: instruments ?? this.instruments,
    melodyPath: clearMelody ? null : (melodyPath ?? this.melodyPath),
    rhythmPath: rhythmPath ?? this.rhythmPath,
    remoteId: remoteId ?? this.remoteId,
    addedAt: addedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'path': path,
    'genre': genre,
    'instruments': instruments,
    'melodyPath': melodyPath,
    'rhythmPath': rhythmPath,
    'remoteId': remoteId,
    'addedAt': addedAt.toIso8601String(),
  };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
    id: json['id'] as String,
    title: json['title'] as String,
    path: json['path'] as String,
    genre: json['genre'] as String?,
    instruments: (json['instruments'] as List?)?.cast<String>() ?? const [],
    melodyPath: json['melodyPath'] as String?,
    rhythmPath: json['rhythmPath'] as String?,
    remoteId: json['remoteId'] as String?,
    addedAt:
        DateTime.tryParse(json['addedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}
