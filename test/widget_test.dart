// Prueba basica: la app arranca y, sin organizacion configurada,
// lleva a la pantalla de organizacion.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capturas/main.dart';

void main() {
  testWidgets('App loads and shows organization screen',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const CapturasApp());
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Tu organizacion'), findsOneWidget);
  });
}
