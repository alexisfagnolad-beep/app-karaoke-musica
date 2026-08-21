import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/drum_calibration.dart';
import '../data/karaoke_controller.dart';
import 'drum_learn_view.dart' show kDrumPieces, kDefaultPieces;

/// Pantalla para CALIBRAR la batería física una vez (queda guardada para
/// siempre). Se entra desde la sección de batería, antes de elegir un patrón.
class DrumCalibrationScreen extends StatefulWidget {
  const DrumCalibrationScreen({super.key});

  @override
  State<DrumCalibrationScreen> createState() => _DrumCalibrationScreenState();
}

class _DrumCalibrationScreenState extends State<DrumCalibrationScreen> {
  final KaraokeController _c = KaraokeController();
  final Set<String> _pieces = {...kDefaultPieces};

  @override
  void initState() {
    super.initState();
    _c.loadForCalibration();
  }

  @override
  void dispose() {
    _c.cancelCalibration();
    _c.dispose();
    super.dispose();
  }

  List<String> _ordered() =>
      [for (final d in kDrumPieces) if (_pieces.contains(d.id)) d.id];

  String _label(String id) {
    for (final d in kDrumPieces) {
      if (d.id == id) return d.label;
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calibrar mi batería')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            if (_c.calibrating) return _calibrating();
            return _intro();
          },
        ),
      ),
    );
  }

  Widget _intro() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: const Color(0x143DE0C6),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🥁 Calibración de tu batería',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Se hace UNA vez y queda guardada para siempre. La app aprende '
                  'el sonido de cada pieza de TU batería para reconocerla con '
                  'precisión cuando la toques de verdad (con el micrófono).\n\n'
                  'Hacelo en un lugar sin ruido, con el celu cerca, y tocá cada '
                  'pieza siempre con la misma fuerza.',
                ),
                if (DrumCalibration.isCalibrated) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF1DB6A2)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Ya tenés una calibración guardada. Podés rehacerla '
                          'cuando quieras.',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await DrumCalibration.clear();
                          if (mounted) setState(() {});
                        },
                        child: const Text('Borrar'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '¿Qué piezas tiene tu batería?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        for (final d in kDrumPieces)
          CheckboxListTile(
            dense: true,
            value: _pieces.contains(d.id),
            title: Text(d.label),
            secondary: CircleAvatar(backgroundColor: d.color, radius: 12),
            onChanged: (v) => setState(() {
              if (v == true) {
                _pieces.add(d.id);
              } else {
                _pieces.remove(d.id);
              }
            }),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _pieces.isEmpty
              ? null
              : () => _c.startCalibration(_ordered()),
          icon: const Icon(Icons.graphic_eq),
          label: const Text('Empezar calibración'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
        if (_c.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _c.error!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
      ],
    );
  }

  Widget _calibrating() {
    final id = _c.calibTarget;
    final done = id == null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (done) ...[
              const Text('🎉', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 8),
              const Text(
                '¡Batería calibrada!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Ya queda guardada. Podés practicar cuando quieras.'),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Listo'),
              ),
            ] else ...[
              Text(
                'Pieza ${_c.calibStep} de ${_c.calibTotal}',
                style: const TextStyle(fontSize: 15, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              Text(
                'Tocá: ${_label(id)}',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1DB6A2),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${_c.calibCount} / ${KaraokeController.calibPerPiece} golpes',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 260,
                child: LinearProgressIndicator(
                  value: _c.micLevel.clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: Colors.black12,
                  color: const Color(0xFFFFCA28),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tocala varias veces, parejo y clarito.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: _c.cancelCalibration,
                child: const Text('Cancelar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
