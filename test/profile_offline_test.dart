import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plano_parto_pet_saude/screens/profile/profile_screen.dart';
import 'package:plano_parto_pet_saude/services/storage_service.dart';

import 'support/offline_helpers.dart';

void main() {
  setUp(resetOfflineState);

  Future<void> openProfile(WidgetTester tester) async {
    setViewport(tester, const Size(1000, 1800));
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    final button = find.text('Salvar cadastro offline');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('empty and whitespace-only names do not persist a local profile',
      (tester) async {
    await openProfile(tester);
    await tester.enterText(find.byType(TextField).at(0), '   ');
    await tester.enterText(
        find.byType(TextField).at(1), 'test@example.invalid');
    await save(tester);
    expect(await StorageService().loadProfile(), isNull);
    expect(find.text('Informe nome e e-mail para preparar o cadastro local.'),
        findsOneWidget);
  });

  testWidgets(
      'manual UBS persists without an official routing code and can be restored and cleared',
      (tester) async {
    await openProfile(tester);
    await tester.enterText(find.byType(TextField).at(0), 'Gestante Sintetica');
    await tester.enterText(
        find.byType(TextField).at(1), 'test@example.invalid');
    await tester
        .tap(find.text('Minha UBS não está na lista / digitar manualmente'));
    await tester.pumpAndSettle();
    expect(find.text('UBS fora da lista oficial'), findsOneWidget);
    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField).at(3), 'UBS Sintetica Manual');
    await save(tester);
    final saved = await StorageService().loadProfile();
    expect(saved!.ubsCode, isNull);
    expect(saved.ubsName, 'UBS Sintetica Manual');
    expect(saved.role, 'patient');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Gestante Sintetica');
    expect(
        tester.widget<TextField>(find.byType(TextField).at(3)).controller!.text,
        'UBS Sintetica Manual');
    final clear = find.text('Limpar cadastro local');
    await tester.ensureVisible(clear);
    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(await StorageService().loadProfile(), isNull);
  });

  testWidgets(
      'switching manual UBS to official clears the manual value and retains local identity',
      (tester) async {
    await openProfile(tester);
    await tester.enterText(find.byType(TextField).at(0), 'Sintetica');
    await tester.enterText(
        find.byType(TextField).at(1), 'test@example.invalid');
    await tester.enterText(find.byType(TextField).at(3), 'UBS Sintetica');
    await save(tester);
    final original = (await StorageService().loadProfile())!;
    final radio = find.byType(RadioListTile<String>).first;
    await tester.ensureVisible(radio);
    final official = tester.widget<RadioListTile<String>>(radio).value;
    await tester.tap(radio);
    await tester.pumpAndSettle();
    await save(tester);
    final saved = (await StorageService().loadProfile())!;
    expect(saved.ubsCode, official);
    expect(saved.ubsName, isNot('UBS Sintetica'));
    expect(saved.id, original.id);
    expect(saved.createdAt, original.createdAt);
  });
}
