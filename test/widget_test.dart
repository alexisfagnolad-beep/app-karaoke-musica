import 'package:flutter_test/flutter_test.dart';
import 'package:karaoke_musica/app.dart';

void main() {
  testWidgets('La app arranca en el inicio con sus tiles', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const KaraokeApp());

    // Título del inicio y algunos tiles del menú principal.
    expect(find.text('Karaoke Música'), findsOneWidget);
    expect(find.text('Cantar'), findsOneWidget);
    expect(find.text('Biblioteca'), findsOneWidget);
  });
}
