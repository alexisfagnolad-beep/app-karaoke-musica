import 'package:flutter/material.dart';

import '../../../shared/ui/app_ui.dart';
import '../data/pitch_detection_service.dart';
import 'widgets/cents_meter.dart';
import 'widgets/note_display.dart';

/// Pantalla del paso 2 del README: detección de pitch en vivo.
/// Captura el micrófono y muestra en tiempo real la nota cantada y su
/// desviación en cents. Es el "hola mundo" que valida todo lo demás.
class LivePitchScreen extends StatefulWidget {
  const LivePitchScreen({super.key});

  @override
  State<LivePitchScreen> createState() => _LivePitchScreenState();
}

class _LivePitchScreenState extends State<LivePitchScreen> {
  final PitchDetectionService _service = PitchDetectionService();

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_service.isListening) {
      _service.stop();
    } else {
      _service.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: gradientAppBar(
        context,
        'Afinación en vivo',
        colors: const [AppColors.purple, AppColors.blue],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _service,
          builder: (context, _) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  if (_service.error != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _service.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  const Spacer(),
                  NoteDisplay(note: _service.note),
                  const SizedBox(height: 40),
                  CentsMeter(cents: _service.note?.cents),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _toggle,
                    icon: Icon(_service.isListening ? Icons.stop : Icons.mic),
                    label: Text(
                      _service.isListening ? 'Detener' : 'Empezar a escuchar',
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
