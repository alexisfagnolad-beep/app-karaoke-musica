import 'package:flutter/material.dart';

import 'app.dart';
import 'features/karaoke/data/drum_calibration.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Carga la calibración de batería guardada (persistente), si existe.
  await DrumCalibration.load();
  runApp(const KaraokeApp());
}
