import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karaoke_musica/app.dart';

void main() {
  testWidgets('La app arranca en el inicio con las dos funciones',
      (WidgetTester tester) async {
    await tester.pumpWidget(const KaraokeApp());

    // Título del inicio y las dos opciones disponibles.
    expect(find.text('Karaoke Música'), findsOneWidget);
    expect(find.text('Afinación en vivo'), findsOneWidget);
    expect(find.text('Reproducir un MP3'), findsOneWidget);
  });
}
