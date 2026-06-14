import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Estado del proceso de actualización, para que la UI reaccione.
enum UpdateStatus {
  idle,
  needsToken,
  checking,
  upToDate,
  available,
  downloading,
  installing,
  error,
}

/// Actualizador integrado: revisa la última Release del repo en GitHub,
/// compara con la versión instalada y descarga/instala la nueva.
///
/// Funciona igual en celular y en PC (es la misma app Flutter). Como el repo
/// es privado, usa un token de GitHub que el usuario pega UNA vez y queda
/// guardado de forma segura en el dispositivo (NO va escrito en el código).
class UpdateService extends ChangeNotifier {
  // Coordenadas del repo y de la Release de canal fijo.
  static const String owner = 'alexisfagnolad-beep';
  static const String repo = 'app-karaoke-musica';
  static const String releaseTag = 'android-latest';
  static const String apkAssetName = 'karaoke-musica-debug.apk';
  static const String versionAssetName = 'version.json';

  static const String _tokenKey = 'github_token';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  UpdateStatus status = UpdateStatus.idle;
  String? message;

  int currentBuild = 0;
  String currentVersion = '';
  int? latestBuild;
  double downloadProgress = 0;
  bool hasToken = false;

  // URL (API) del asset del APK, cacheada tras el chequeo.
  String? _apkAssetUrl;

  /// Lee la versión instalada y si ya hay token guardado.
  Future<void> init() async {
    final info = await PackageInfo.fromPlatform();
    currentVersion = info.version;
    currentBuild = int.tryParse(info.buildNumber) ?? 0;
    final token = await _readToken();
    hasToken = token != null && token.isNotEmpty;
    status = hasToken ? UpdateStatus.idle : UpdateStatus.needsToken;
    notifyListeners();
  }

  Future<String?> _readToken() => _storage.read(key: _tokenKey);

  /// Guarda (o borra) el token de GitHub.
  Future<void> saveToken(String token) async {
    final value = token.trim();
    await _storage.write(key: _tokenKey, value: value);
    hasToken = value.isNotEmpty;
    status = hasToken ? UpdateStatus.idle : UpdateStatus.needsToken;
    notifyListeners();
  }

  Map<String, String> _ghHeaders({required bool binary}) => {
        'Accept':
            binary ? 'application/octet-stream' : 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        // GitHub rechaza con 403 las peticiones sin User-Agent.
        'User-Agent': 'karaoke-musica-app',
      };

  /// Busca si hay una versión más nueva en la Release.
  Future<void> checkForUpdate() async {
    final token = await _readToken();
    if (token == null || token.isEmpty) {
      _set(UpdateStatus.needsToken, 'Falta el token de GitHub.');
      return;
    }

    _set(UpdateStatus.checking, 'Buscando actualización…');
    try {
      final relUri = Uri.parse(
        'https://api.github.com/repos/$owner/$repo/releases/tags/$releaseTag',
      );
      final relRes = await http.get(
        relUri,
        headers: {..._ghHeaders(binary: false), 'Authorization': 'Bearer $token'},
      );
      if (relRes.statusCode == 401 || relRes.statusCode == 403) {
        _set(UpdateStatus.error,
            'GitHub rechazó el token (${relRes.statusCode}). Revisá que sea válido y tenga permiso de lectura del repo.');
        return;
      }
      if (relRes.statusCode != 200) {
        _set(UpdateStatus.error, 'GitHub respondió ${relRes.statusCode}.');
        return;
      }

      final rel = json.decode(relRes.body) as Map<String, dynamic>;
      final assets =
          (rel['assets'] as List).cast<Map<String, dynamic>>();

      final apkAsset = assets.where((a) => a['name'] == apkAssetName);
      final versionAsset = assets.where((a) => a['name'] == versionAssetName);

      if (apkAsset.isEmpty) {
        _set(UpdateStatus.error, 'La Release no tiene el APK todavía.');
        return;
      }
      _apkAssetUrl = apkAsset.first['url'] as String;

      if (versionAsset.isEmpty) {
        _set(UpdateStatus.error,
            'La Release todavía no tiene version.json (esperá al próximo build).');
        return;
      }

      final versionBytes =
          await _downloadAsset(versionAsset.first['url'] as String, token);
      final versionData =
          json.decode(utf8.decode(versionBytes)) as Map<String, dynamic>;
      latestBuild = (versionData['buildNumber'] as num?)?.toInt();

      if (latestBuild == null) {
        _set(UpdateStatus.error, 'No se pudo leer la versión remota.');
        return;
      }

      if (latestBuild! > currentBuild) {
        _set(UpdateStatus.available,
            'Hay una versión nueva (build $latestBuild). Tenés la $currentBuild.');
      } else {
        _set(UpdateStatus.upToDate,
            'Ya tenés la última versión (build $currentBuild).');
      }
    } catch (e) {
      _set(UpdateStatus.error, 'Error al buscar actualización: $e');
    }
  }

  /// Descarga el APK/instalador y lo abre para instalar.
  Future<void> downloadAndInstall() async {
    final token = await _readToken();
    final assetUrl = _apkAssetUrl;
    if (token == null || assetUrl == null) {
      _set(UpdateStatus.error, 'Primero buscá una actualización.');
      return;
    }

    _set(UpdateStatus.downloading, 'Descargando…');
    downloadProgress = 0;
    notifyListeners();

    try {
      final response = await _openAssetStream(assetUrl, token);
      if (response.statusCode != 200) {
        _set(UpdateStatus.error, 'La descarga falló (${response.statusCode}).');
        return;
      }

      final dir = await _downloadDir();
      final file = File('${dir.path}/$apkAssetName');
      final sink = file.openWrite();
      final total = response.contentLength ?? 0;
      var received = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          downloadProgress = received / total;
          notifyListeners();
        }
      }
      await sink.close();

      _set(UpdateStatus.installing, 'Descargado. Abriendo el instalador…');
      await OpenFilex.open(file.path);
    } catch (e) {
      _set(UpdateStatus.error, 'Error al descargar: $e');
    }
  }

  Future<Directory> _downloadDir() async {
    if (Platform.isAndroid) {
      return (await getExternalStorageDirectory()) ??
          await getApplicationSupportDirectory();
    }
    return (await getDownloadsDirectory()) ??
        await getApplicationSupportDirectory();
  }

  /// Descarga completa de un asset (para archivos chicos como version.json).
  Future<List<int>> _downloadAsset(String assetApiUrl, String token) async {
    final response = await _openAssetStream(assetApiUrl, token);
    return response.stream.toBytes();
  }

  /// Abre el stream de un asset privado de GitHub.
  ///
  /// La API redirige a una URL firmada (S3). Importante: NO reenviar el header
  /// Authorization de GitHub a esa URL, porque S3 lo rechaza. Por eso seguimos
  /// el redirect a mano sin las credenciales.
  Future<http.StreamedResponse> _openAssetStream(
      String assetApiUrl, String token) async {
    final client = http.Client();
    final request = http.Request('GET', Uri.parse(assetApiUrl))
      ..followRedirects = false
      ..headers.addAll({
        ..._ghHeaders(binary: true),
        'Authorization': 'Bearer $token',
      });

    var response = await client.send(request);

    final isRedirect = response.statusCode == 301 ||
        response.statusCode == 302 ||
        response.statusCode == 307 ||
        response.statusCode == 308;
    final location = response.headers['location'];
    if (isRedirect && location != null) {
      // Segunda petición a S3, ya sin el token de GitHub.
      final signed = http.Request('GET', Uri.parse(location))
        ..followRedirects = true;
      response = await client.send(signed);
    }
    return response;
  }

  void _set(UpdateStatus newStatus, String msg) {
    status = newStatus;
    message = msg;
    notifyListeners();
  }
}
