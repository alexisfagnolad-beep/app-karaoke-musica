import 'package:flutter/material.dart';

/// Paleta y componentes compartidos para que todas las pantallas tengan el
/// mismo lenguaje visual (degradés, acentos, tarjetas).
class AppColors {
  static const purple = Color(0xFF7C4DFF);
  static const blue = Color(0xFF4D9BFF);
  static const teal = Color(0xFF1DB6A2);
  static const pink = Color(0xFFE0457B);
  static const orange = Color(0xFFFF8A3D);

  static const good = Color(0xFF4AE3B5);
  static const warn = Color(0xFFFFB74D);
  static const bad = Color(0xFFFF6B6B);

  /// Degradé por defecto de los encabezados.
  static const headerGradient = [purple, blue];
}

/// AppBar con degradé, para darle identidad a las pantallas internas.
PreferredSizeWidget gradientAppBar(
  BuildContext context,
  String title, {
  List<Widget>? actions,
  List<Color> colors = AppColors.headerGradient,
  Widget? leading,
}) {
  return AppBar(
    title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
    centerTitle: true,
    actions: actions,
    leading: leading,
    foregroundColor: Colors.white,
    backgroundColor: Colors.transparent,
    elevation: 0,
    flexibleSpace: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
    ),
  );
}

/// Color del puntaje según qué tan bien salió (0..100).
Color scoreColor(double score) {
  if (score >= 75) return AppColors.good;
  if (score >= 50) return AppColors.warn;
  return AppColors.bad;
}

/// Anillo circular con el puntaje grande en el centro.
class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.score,
    this.label,
    this.size = 200,
  });

  /// Puntaje 0..100.
  final double score;
  final String? label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = scoreColor(score);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: (score / 100).clamp(0.0, 1.0),
              strokeWidth: 14,
              strokeCap: StrokeCap.round,
              backgroundColor: theme.colorScheme.onSurface.withValues(
                alpha: 0.10,
              ),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score.toStringAsFixed(0),
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                'puntos',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              if (label != null) ...[
                const SizedBox(height: 4),
                Text(
                  label!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
