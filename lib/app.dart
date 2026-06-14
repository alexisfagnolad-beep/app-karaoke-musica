import 'package:flutter/material.dart';

import 'features/pitch/presentation/live_pitch_screen.dart';

/// Raíz de la app de Karaoke / Práctica Musical.
/// Por ahora arranca directo en la detección de pitch en vivo (paso 2 del
/// README). Más adelante esta pantalla pasará a ser parte del flujo del
/// Modo Karaoke Rápido (abrir MP3, atenuar voz, guía y puntaje).
class KaraokeApp extends StatelessWidget {
  const KaraokeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF7C4DFF),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'Karaoke Música',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFF12101A),
      ),
      home: const LivePitchScreen(),
    );
  }
}
