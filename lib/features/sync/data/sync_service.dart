import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../library/data/library_repository.dart';

/// Un proyecto disponible en la PC (publicado en la Release `proyectos`).
class RemoteProject {
  RemoteProject({
    required this.id,
    required this.title,
    this.genre,
    this.instruments = const [],
    required this.instrumentalUrl,
    this.melodyUrl,
    this.rhythmUrl,
    this.imported = false,
    this.downloading = false,
  });

  final String id;
  final String title;
  final String? genre;
  final List<String> instruments;

  /// URLs (API) de los assets para descargar.
  final String instrumentalUrl;
  final String? melodyUrl;
  final String? rhythmUrl;

  bool imported;
  bool downloading;

  bool get canScore => melodyUrl != null || rhythmUrl != null;
  bool get isRhythm => rhythmUrl != null && melodyUrl == null;
}

enum SyncStatus { idle, loading, ready, error }

/// Sincroniza la Biblioteca del celular con lo que la PC publica en GitHub.
///
/// La PC sube los proyectos a una Release fija (tag `proyectos`) con un índice
/// `proyectos.json`. Como el repo es público, el celular los baja sin token,
/// sin cables y sin elegir archivos a mano.
class SyncService extends ChangeNotifier {
  SyncService(this._repo);

  final LibraryRepository _repo;

  static const String owner = 'alexisfagnolad-beep';
  static const String repo = 'app-karaoke-musica';
  static const String releaseTag = 'proyectos';
  static const String indexName = 'proyectos.json';

  SyncStatus status = SyncStatus.idle;
  String? message;
  List<RemoteProject> projects = [];

  Map<String, String> get _headers => {
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': 'karaoke-musica-app',
  };

  void _set(SyncStatus s, [String? msg]) {
    status = s;
    message = msg;
    notifyListeners();
  }

  /// Trae la lista de proyectos publicados por la PC.
  Future<void> refresh() async {
    _set(SyncStatus.loading, 'Buscando canciones en la PC…');
    try {
      final relUri = Uri.parse(
        'https://api.github.com/repos/$owner/$repo/releases/tags/$releaseTag',
      );
      final relRes = await http.get(relUri, headers: _headers);
      if (relRes.statusCode == 404) {
        projects = [];
        _set(
          SyncStatus.ready,
          'Todavía no hay canciones publicadas desde la PC.',
        );
        return;
      }
      if (relRes.statusCode != 200) {
        _set(SyncStatus.error, 'GitHub respondió ${relRes.statusCode}.');
        return;
      }

      final rel = json.decode(relRes.body) as Map<String, dynamic>;
      final assets = (rel['assets'] as List).cast<Map<String, dynamic>>();
      final urlByName = <String, String>{
        for (final a in assets) a['name'] as String: a['url'] as String,
      };

      final indexAsset = assets.where((a) => a['name'] == indexName);
      if (indexAsset.isEmpty) {
        projects = [];
        _set(
          SyncStatus.ready,
          'Todavía no hay canciones publicadas desde la PC.',
        );
        return;
      }

      final indexBytes = await _downloadAsset(
        indexAsset.first['url'] as String,
      );
      final index =
          json.decode(utf8.decode(indexBytes)) as Map<String, dynamic>;
      final rawProjects = (index['projects'] as List?) ?? const [];

      final imported = _repo.importedRemoteIds();
      final list = <RemoteProject>[];
      for (final e in rawProjects) {
        final m = e as Map<String, dynamic>;
        final instName = m['instrumental'] as String?;
        final instUrl = instName == null ? null : urlByName[instName];
        if (instUrl == null) continue; // sin instrumental no sirve.
        final melName = m['melody'] as String?;
        final rhyName = m['rhythm'] as String?;
        list.add(
          RemoteProject(
            id: m['id'] as String,
            title: m['title'] as String? ?? m['id'] as String,
            genre: m['genre'] as String?,
            instruments:
                (m['instruments'] as List?)?.cast<String>() ?? const [],
            instrumentalUrl: instUrl,
            melodyUrl: melName == null ? null : urlByName[melName],
            rhythmUrl: rhyName == null ? null : urlByName[rhyName],
            imported: imported.contains(m['id']),
          ),
        );
      }
      projects = list;
      _set(
        SyncStatus.ready,
        list.isEmpty ? 'No hay canciones para sincronizar.' : null,
      );
    } catch (e) {
      _set(SyncStatus.error, 'Error al sincronizar: $e');
    }
  }

  /// Descarga un proyecto y lo agrega a la Biblioteca.
  Future<void> download(RemoteProject p) async {
    if (p.imported || p.downloading) return;
    p.downloading = true;
    notifyListeners();
    try {
      final tmp = await getTemporaryDirectory();
      final base = '${tmp.path}/sync_${p.id}';
      final instPath = '$base.instrumental.wav';
      await _downloadToFile(p.instrumentalUrl, instPath);

      String? melodyPath;
      if (p.melodyUrl != null) {
        melodyPath = '$base.melody.json';
        await _downloadToFile(p.melodyUrl!, melodyPath);
      }

      String? rhythmPath;
      if (p.rhythmUrl != null) {
        rhythmPath = '$base.rhythm.json';
        await _downloadToFile(p.rhythmUrl!, rhythmPath);
      }

      await _repo.addSong(
        sourcePath: instPath,
        title: p.title,
        genre: p.genre,
        instruments: p.instruments,
        melodySourcePath: melodyPath,
        rhythmSourcePath: rhythmPath,
        remoteId: p.id,
      );

      // Limpieza de temporales.
      for (final path in [instPath, melodyPath, rhythmPath]) {
        if (path == null) continue;
        try {
          final f = File(path);
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
      }

      p.imported = true;
      p.downloading = false;
      _set(SyncStatus.ready, '"${p.title}" se agregó a tu Biblioteca.');
    } catch (e) {
      p.downloading = false;
      _set(SyncStatus.error, 'No pude bajar "${p.title}": $e');
    }
  }

  /// Sincronización automática: busca proyectos nuevos y los baja e importa
  /// a la Biblioteca. Devuelve cuántas canciones nuevas se agregaron.
  Future<int> autoDownloadNew() async {
    await refresh();
    if (status == SyncStatus.error) return 0;
    final pending = projects.where((p) => !p.imported).toList();
    var added = 0;
    for (final p in pending) {
      await download(p);
      if (p.imported) added++;
    }
    return added;
  }

  Future<List<int>> _downloadAsset(String assetApiUrl) async {
    final res = await _openAssetStream(assetApiUrl);
    return res.stream.toBytes();
  }

  Future<void> _downloadToFile(String assetApiUrl, String destPath) async {
    final res = await _openAssetStream(assetApiUrl);
    if (res.statusCode != 200) {
      throw Exception('descarga falló (${res.statusCode})');
    }
    final file = File(destPath);
    final sink = file.openWrite();
    await res.stream.pipe(sink);
  }

  /// Abre el asset siguiendo el redirect a S3 sin reenviar headers de GitHub.
  Future<http.StreamedResponse> _openAssetStream(String assetApiUrl) async {
    final client = http.Client();
    final request = http.Request('GET', Uri.parse(assetApiUrl))
      ..followRedirects = false
      ..headers.addAll({..._headers, 'Accept': 'application/octet-stream'});

    var response = await client.send(request);
    final isRedirect =
        response.statusCode == 301 ||
        response.statusCode == 302 ||
        response.statusCode == 307 ||
        response.statusCode == 308;
    final location = response.headers['location'];
    if (isRedirect && location != null) {
      final signed = http.Request('GET', Uri.parse(location))
        ..followRedirects = true;
      response = await client.send(signed);
    }
    return response;
  }
}
