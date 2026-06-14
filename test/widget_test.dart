import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karaoke_musica/app.dart';

void main() {
  testWidgets('La app arranca en la pantalla de afinación en vivo',
      (WidgetTester tester) async {
    await tester.pumpWidget(const KaraokeApp());

    // Título de la pantalla y botón inicial para empezar a escuchar.
    expect(find.text('Afinación en vivo'), findsOneWidget);
    expect(find.text('Empezar a escuchar'), findsOneWidget);

    // Sin sonido todavía: invita a cantar.
    expect(find.text('Cantá una nota…'), findsOneWidget);
  });
}
