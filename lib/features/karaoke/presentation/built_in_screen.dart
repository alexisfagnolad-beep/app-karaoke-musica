import 'package:flutter/material.dart';

import '../../../shared/ui/app_ui.dart';
import '../domain/built_in_songs.dart';
import 'drum_learn_screen.dart';
import 'piano_learn_screen.dart';

/// "Para empezar": canciones y patrones prediseñados, listos para tocar sin
/// PC. Ideal para arrancar de cero.
class BuiltInScreen extends StatelessWidget {
  const BuiltInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: gradientAppBar(
        context,
        'Para empezar',
        colors: const [AppColors.pink, AppColors.orange],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const Card(
              color: Color(0x143DE0C6),
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  '🔊 Suenan solas y podés tocar las teclas o la batería en la '
                  'pantalla para acompañar. Bajá la velocidad o silenciá el '
                  'sonido con los botones de arriba.',
                ),
              ),
            ),
            _section(context, '🎹 Canciones para piano'),
            for (final s in builtInSongs)
              _tile(
                context,
                icon: s.icon,
                color: AppColors.teal,
                title: s.title,
                subtitle: 'Escuchá y tocá la melodía en el piano',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PianoLearnScreen.builtIn(
                      title: s.title,
                      notes: s.notes,
                      duration: s.duration,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            _section(context, '🥁 Patrones de batería'),
            for (final p in builtInPatterns)
              _tile(
                context,
                icon: p.icon,
                color: AppColors.pink,
                title: p.title,
                subtitle: 'Escuchá y tocá el patrón en la batería',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DrumLearnScreen.builtIn(
                      title: p.title,
                      rhythm: p.rhythm,
                      duration: p.duration,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.play_circle_fill, size: 32),
        onTap: onTap,
      ),
    );
  }
}
