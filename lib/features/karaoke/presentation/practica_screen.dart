import 'package:flutter/material.dart';

import '../../../shared/ui/app_ui.dart';
import '../../library/presentation/library_screen.dart';
import 'built_in_screen.dart';

/// "Práctica de instrumento": elegí practicar con lo prediseñado (piano y
/// batería fáciles, sin PC) o con los instrumentos que desglosaste en la PC.
class PracticaScreen extends StatelessWidget {
  const PracticaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: gradientAppBar(
        context,
        'Práctica de instrumento',
        colors: const [AppColors.teal, AppColors.blue],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _bigTile(
              context,
              icon: Icons.auto_awesome,
              color: AppColors.orange,
              title: 'Para empezar',
              subtitle: 'Piano y batería fáciles, listos para tocar (sin PC).',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BuiltInScreen()),
              ),
            ),
            _bigTile(
              context,
              icon: Icons.piano,
              color: AppColors.teal,
              title: 'De la PC',
              subtitle: 'Practicá con los instrumentos que procesaste en la PC.',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      const LibraryScreen(titleOverride: 'Practicar'),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
