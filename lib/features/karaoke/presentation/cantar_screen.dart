import 'package:flutter/material.dart';

import '../../../shared/ui/app_ui.dart';
import '../../library/presentation/library_screen.dart';
import '../domain/built_in_songs.dart';
import 'karaoke_screen.dart';

/// "Cantar": elegí cantar canciones fáciles prediseñadas (sin PC) o tus propias
/// canciones desglosadas en la PC.
class CantarScreen extends StatelessWidget {
  const CantarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: gradientAppBar(
        context,
        'Cantar',
        colors: const [AppColors.pink, AppColors.purple],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _bigTile(
              context,
              icon: Icons.library_music,
              color: AppColors.blue,
              title: 'Mis canciones (de la PC)',
              subtitle: 'Las que procesaste en la computadora.',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const LibraryScreen(
                    initialInstrument: 'Voz',
                    titleOverride: 'Cantar',
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 16, 4, 8),
              child: Text(
                '🎤 Para empezar — canciones fáciles',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (final s in builtInSongs)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.pink.withValues(alpha: 0.2),
                    child: Icon(s.icon, color: AppColors.pink),
                  ),
                  title: Text(
                    s.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Cantá siguiendo las barras'),
                  trailing: const Icon(Icons.mic, size: 28),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => KaraokeScreen.builtIn(
                        title: s.title,
                        notes: s.notes,
                        duration: s.duration,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bigTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
