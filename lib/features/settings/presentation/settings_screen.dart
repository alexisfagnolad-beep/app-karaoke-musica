import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/ui/app_ui.dart';
import '../../karaoke/data/karaoke_controller.dart';
import '../../sync/presentation/sync_screen.dart';
import '../../update/presentation/update_screen.dart';

/// Ajustes: junta lo técnico (sincronizar con la PC, actualizar, compartir la
/// app) para despejar el inicio.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  /// Link de descarga de la app (Release de canal fijo en GitHub).
  static const String appDownloadUrl =
      'https://github.com/alexisfagnolad-beep/app-karaoke-musica/releases/download/android-latest/karaoke-musica-debug.apk';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: gradientAppBar(
        context,
        'Ajustes',
        colors: const [AppColors.blue, AppColors.purple],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              child: StatefulBuilder(
                builder: (context, setState) => SwitchListTile(
                  secondary: const CircleAvatar(
                    backgroundColor: Color(0x33FF8A3D),
                    child: Icon(Icons.vibration, color: AppColors.orange),
                  ),
                  title: const Text('Efectos (vibración)'),
                  subtitle: const Text('Vibra al acertar notas y golpes.'),
                  value: KaraokeController.effectsEnabled,
                  onChanged: (v) =>
                      setState(() => KaraokeController.effectsEnabled = v),
                ),
              ),
            ),
            _tile(
              context,
              icon: Icons.cloud_sync,
              color: AppColors.teal,
              title: 'Sincronizar con la PC',
              subtitle: 'Bajá las canciones que procesaste en la PC.',
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SyncScreen())),
            ),
            _tile(
              context,
              icon: Icons.system_update,
              color: AppColors.blue,
              title: 'Actualizaciones',
              subtitle: 'Buscar e instalar la última versión.',
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const UpdateScreen())),
            ),
            _tile(
              context,
              icon: Icons.share,
              color: AppColors.orange,
              title: 'Compartir la app',
              subtitle: 'Copiá el link de descarga para pasarle a alguien.',
              onTap: () => _shareApp(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareApp(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: appDownloadUrl));
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Compartir la app'),
        content: const Text(
          'Copié el link de descarga al portapapeles. Pegalo en WhatsApp o '
          'donde quieras; quien lo abra puede instalar la app:\n\n'
          '$appDownloadUrl',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Listo'),
          ),
        ],
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.18),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
