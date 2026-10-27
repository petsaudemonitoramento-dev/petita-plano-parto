import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plano_parto_pet_saude/screens/consent/consent_gate_screen.dart';
import 'package:plano_parto_pet_saude/services/storage_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('protected route opens only after all five acknowledgements',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
      home: ConsentRequiredScreen(
        child: Scaffold(body: Text('Protected content')),
      ),
    ));
    await tester.pumpAndSettle();

    final button = find.widgetWithText(ElevatedButton, 'Concordar e começar');
    expect(find.text('Protected content'), findsNothing);
    expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
    expect(find.byType(CheckboxListTile), findsNWidgets(5));
    for (var index = 0; index < 5; index++) {
      await tester.tap(find.descendant(
        of: find.byType(CheckboxListTile).at(index),
        matching: find.byType(Checkbox),
      ));
      await tester.pump();
      expect(tester.widget<ElevatedButton>(button).onPressed,
          index < 4 ? isNull : isNotNull);
    }

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(await StorageService().hasConsent(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Protected content'), findsOneWidget);
  });

  testWidgets('existing current consent opens the protected route',
      (tester) async {
    await StorageService().saveConsentAcknowledgements();
    await tester.pumpWidget(const MaterialApp(
      home: ConsentRequiredScreen(
        child: Scaffold(body: Text('Protected content')),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Protected content'), findsOneWidget);
    expect(find.byType(ConsentGateScreen), findsNothing);
  });
}
