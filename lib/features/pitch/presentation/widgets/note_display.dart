import 'package:flutter/material.dart';

import '../../domain/musical_note.dart';

/// Muestra en grande la nota detectada (nombre + octava) y su frecuencia.
/// Cuando no hay nota, invita a cantar.
class NoteDisplay extends StatelessWidget {
  const NoteDisplay({super.key, required this.note});

  final MusicalNote? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = note;

    if (current == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '–',
            style: theme.textTheme.displayLarge?.copyWith(
              fontSize: 120,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Cantá una nota…',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      );
    }

    final inTune = current.isInTune();
    final color = inTune ? Colors.greenAccent : theme.colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Nombre de la nota + octava como subíndice.
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: current.name,
                style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: 120,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              TextSpan(
                text: '${current.octave}',
                style: theme.textTheme.displayMedium?.copyWith(
                  fontSize: 48,
                  color: color.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        Text(
          '${current.frequency.toStringAsFixed(1)} Hz',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
