import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:etnya_frontend/main.dart';

void main() {
  testWidgets('La app arranca sin errores', (WidgetTester tester) async {
    await tester.pumpWidget(const EtnyaApp());
    await tester.pumpAndSettle();

    // Solo verifica que la app haya montado un widget raíz sin tirar excepciones.
    expect(find.byType(EtnyaApp), findsOneWidget);
  });
}