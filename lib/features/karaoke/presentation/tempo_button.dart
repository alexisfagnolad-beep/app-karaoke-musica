import 'package:flutter/material.dart';

import '../data/karaoke_controller.dart';

/// Botón para bajar la velocidad (tempo) desde cualquier modo. El tono no
/// cambia (no suena grave); todo sigue sincronizado con la reproducción.
class TempoButton extends StatelessWidget {
  const TempoButton({super.key, required this.controller, this.dark = false});

  final KaraokeController controller;

  /// true en overlays oscuros (piano/batería a pantalla completa).
  final bool dark;

  static const List<double> _speeds = [1.0, 0.75, 0.5];
  static const Map<double, String> _labels = {
    1.0: 'Normal (1x)',
    0.75: 'Lento (0.75x)',
    0.5: 'Muy lento (0.5x)',
  };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      tooltip: 'Velocidad',
      icon: Icon(Icons.speed, color: dark ? Colors.white : null),
      onSelected: controller.setTempo,
      itemBuilder: (_) => [
        for (final s in _speeds)
          CheckedPopupMenuItem(
            value: s,
            checked: (controller.tempo - s).abs() < 0.01,
            child: Text(_labels[s]!),
          ),
      ],
    );
  }
}
