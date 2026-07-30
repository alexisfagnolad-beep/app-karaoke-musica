import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../shared/ui/app_ui.dart';
import '../domain/melody.dart';
import '../domain/rhythm.dart';
import 'karaoke_screen.dart';

/// Elegís el instrumental (de un proyecto de la PC) y su referencia
/// (`melody.json` para voz/instrumento melódico, o `rhythm.json` para batería),
/// y arrancás la práctica con puntaje.
class PracticeSetupScreen extends StatefulWidget {
  const PracticeSetupScreen({super.key});

  @override
  State<PracticeSetupScreen> createState() => _PracticeSetupScreenState();
}

class _PracticeSetupScreenState extends State<PracticeSetupScreen> {
  String? _instrumentalPath;
  String? _instrumentalName;
  String? _refName;
  Melody? _melody;
  Rhythm? _rhythm;
  String? _error;

  Future<void> _pickInstrumental() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() {
      _instrumentalPath = path;
      _instrumentalName = result!.files.single.name;
    });
  }

  Future<void> _pickReference() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    try {
      final data =
          json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;
      Melody? melody;
      Rhythm? rhythm;
      if (data.containsKey('frames')) {
        melody = Melody.fromJson(data);
      } else if (data.containsKey('onsets')) {
        rhythm = Rhythm.fromJson(data);
      } else {
        throw Exception('El JSON no es una melodía ni un ritmo.');
      }
      setState(() {
        _melody = melody;
        _rhythm = rhythm;
        _refName = result!.files.single.name;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'No pude leer la referencia: $e');
    }
  }

  bool get _ready =>
      _instrumentalPath != null && (_melody != null || _rhythm != null);

  void _start() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KaraokeScreen(
          instrumentalPath: _instrumentalPath!,
          title: _instrumentalName ?? 'Práctica',
          melody: _melody,
          rhythm: _rhythm,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mode = _rhythm != null
        ? 'Ritmo (batería)'
        : _melody != null
        ? 'Melódico (voz / instrumento)'
        : null;

    return Scaffold(
      appBar: gradientAppBar(
        context,
        'Práctica con puntaje',
        colors: const [AppColors.pink, AppColors.purple],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Usá un proyecto procesado en la PC: elegí el instrumental y su '
              'referencia (melody.json o rhythm.json).',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 20),
            _pickTile(
              icon: Icons.music_note,
              color: AppColors.orange,
              title: 'Instrumental',
              value: _instrumentalName,
              onTap: _pickInstrumental,
            ),
            const SizedBox(height: 12),
            _pickTile(
              icon: Icons.timeline,
              color: AppColors.teal,
              title: 'Referencia (.json)',
              value: _refName == null ? null : '$_refName  •  $mode',
              onTap: _pickReference,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _ready ? _start : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Empezar'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pickTile({
    required IconData icon,
    required Color color,
    required String title,
    required String? value,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final chosen = value != null;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.18),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Text(value ?? 'Tocá para elegir'),
        trailing: Icon(
          chosen ? Icons.check_circle : Icons.folder_open,
          color: chosen ? AppColors.good : null,
        ),
        onTap: onTap,
        subtitleTextStyle: theme.textTheme.bodySmall,
      ),
    );
  }
}
