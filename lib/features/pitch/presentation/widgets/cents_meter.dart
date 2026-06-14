import 'package:flutter/material.dart';

/// Medidor horizontal de desviación en cents (-50..+50), estilo afinador.
/// Una aguja se mueve hacia los lados; queda verde y centrada cuando afinás.
class CentsMeter extends StatelessWidget {
  const CentsMeter({super.key, required this.cents, this.range = 50.0});

  /// Desviación actual en cents. `null` = sin nota (aguja al centro, gris).
  final double? cents;

  /// Rango visible a cada lado del centro, en cents.
  final double range;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = cents;
    final hasNote = value != null;

    // Posición normalizada -1..1 para alinear la aguja.
    final normalized = hasNote ? (value / range).clamp(-1.0, 1.0) : 0.0;
    final inTune = hasNote && value.abs() < 5.0;
    final needleColor = !hasNote
        ? theme.colorScheme.onSurface.withValues(alpha: 0.2)
        : inTune
            ? Colors.greenAccent
            : theme.colorScheme.primary;

    return Column(
      children: [
        SizedBox(
          height: 60,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Línea base.
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Marca central (afinación exacta).
                  Container(
                    width: 2,
                    height: 28,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  // Aguja.
                  Align(
                    alignment: Alignment(normalized.toDouble(), 0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 80),
                      width: 6,
                      height: 48,
                      decoration: BoxDecoration(
                        color: needleColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          hasNote
              ? '${value >= 0 ? '+' : ''}${value.toStringAsFixed(0)} cents'
              : '— cents',
          style: theme.textTheme.titleSmall?.copyWith(
            color: needleColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('♭ bajo', style: theme.textTheme.bodySmall),
            Text('alto ♯', style: theme.textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}
