import 'package:flutter/material.dart';

import '../../../shared/ui/app_ui.dart';
import '../data/update_service.dart';

/// Pantalla del actualizador integrado: configurar token, buscar versión
/// nueva y descargar/instalar. Sirve en celular y en PC.
class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key, this.service});

  /// Permite reutilizar un servicio ya creado (p. ej. el del inicio).
  final UpdateService? service;

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  late final UpdateService _service;
  late final bool _ownsService;
  final TextEditingController _tokenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ownsService = widget.service == null;
    _service = widget.service ?? UpdateService();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (_ownsService) {
      await _service.init();
    }
    // Repo público: se puede chequear sin token.
    await _service.checkForUpdate();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    if (_ownsService) _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: gradientAppBar(
        context,
        'Actualizaciones',
        colors: const [AppColors.blue, AppColors.purple],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _service,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Versión instalada: ${_service.currentVersion} '
                  '(build ${_service.currentBuild})',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 24),
                ..._buildUpdateArea(theme),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTokenSetup(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Token de GitHub', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Como el repositorio es privado, pegá un token de GitHub (con permiso '
          'de lectura del repo) una sola vez. Se guarda en este dispositivo de '
          'forma segura, no se comparte ni queda en el código.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _tokenController,
          obscureText: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Pegá tu token aquí',
            hintText: 'ghp_…',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () async {
            await _service.saveToken(_tokenController.text);
            _tokenController.clear();
            if (_service.hasToken) await _service.checkForUpdate();
          },
          child: const Text('Guardar token'),
        ),
      ],
    );
  }

  List<Widget> _buildUpdateArea(ThemeData theme) {
    final s = _service;
    final available = s.status == UpdateStatus.available;
    final downloading = s.status == UpdateStatus.downloading;
    final installing = s.status == UpdateStatus.installing;
    final busy = s.status == UpdateStatus.checking || downloading || installing;

    return [
      if (s.message != null)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: s.status == UpdateStatus.error
                ? theme.colorScheme.errorContainer
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(s.message!),
        ),
      const SizedBox(height: 16),
      if (downloading)
        Column(
          children: [
            LinearProgressIndicator(value: s.downloadProgress),
            const SizedBox(height: 8),
            Text('${(s.downloadProgress * 100).toStringAsFixed(0)} %'),
          ],
        ),
      if (available)
        FilledButton.icon(
          onPressed: s.downloadAndInstall,
          icon: const Icon(Icons.download),
          label: const Text('Descargar e instalar'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        ),
      if (available) const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: busy ? null : s.checkForUpdate,
        icon: const Icon(Icons.refresh),
        label: const Text('Buscar actualización'),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: () => _service.saveToken(''),
        child: const Text('Borrar token guardado'),
      ),
    ];
  }
}
