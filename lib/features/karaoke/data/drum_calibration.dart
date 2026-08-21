import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Calibración de la batería física, GUARDADA PARA SIEMPRE (persistente).
///
/// Se calibra una vez (la app aprende la "huella" de sonido de cada pieza) y
/// queda en disco; todas las prácticas de batería la usan sin volver a calibrar.
class DrumCalibration {
  /// Perfil estandarizado por pieza (id -> vector de rasgos).
  static Map<String, List<double>> profiles = {};

  /// Media y desvío global por dimensión (para estandarizar cada golpe nuevo).
  static List<double> featMean = [];
  static List<double> featStd = [];

  static bool get isCalibrated => profiles.isNotEmpty;

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/drum_calibration.json');
  }

  /// Carga la calibración guardada (al iniciar la app). Silencioso si no hay.
  static Future<void> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return;
      final m = json.decode(await f.readAsString()) as Map<String, dynamic>;
      featMean = _toDoubles(m['mean']);
      featStd = _toDoubles(m['std']);
      final p = (m['profiles'] as Map?) ?? const {};
      profiles = {
        for (final e in p.entries) e.key as String: _toDoubles(e.value),
      };
    } catch (_) {
      // Si el archivo está corrupto, arrancamos sin calibración.
    }
  }

  /// Guarda una nueva calibración (reemplaza la anterior) en memoria y disco.
  static Future<void> save(
    Map<String, List<double>> prof,
    List<double> mean,
    List<double> std,
  ) async {
    profiles = prof;
    featMean = mean;
    featStd = std;
    try {
      final f = await _file();
      await f.writeAsString(
        json.encode({'mean': mean, 'std': std, 'profiles': prof}),
      );
    } catch (_) {}
  }

  /// Borra la calibración (memoria y disco).
  static Future<void> clear() async {
    profiles = {};
    featMean = [];
    featStd = [];
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  static List<double> _toDoubles(dynamic v) =>
      ((v as List?) ?? const []).map((e) => (e as num).toDouble()).toList();
}
