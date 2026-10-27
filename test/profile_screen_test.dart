import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plano_parto_pet_saude/screens/profile/profile_screen.dart';
import 'package:plano_parto_pet_saude/services/storage_service.dart';

void main() {
  testWidgets('official UBS radio selection persists in an offline profile',
      (tester) async {
    // No Supabase initialization: only local assets and mock preferences are used.
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Synthetic Example');
    await tester.enterText(
        find.byType(TextField).at(1), 'example@example.invalid');
    final radios = find.byType(RadioListTile<String>);
    expect(radios, findsAtLeastNWidgets(2));
    final second = tester.widget<RadioListTile<String>>(radios.at(1));
    await tester.tap(radios.at(0));
    await tester.pump();
    await tester.tap(radios.at(1));
    await tester.pump();
    final group =
        tester.widget<RadioGroup<String>>(find.byType(RadioGroup<String>));
    expect(group.groupValue, second.value);

    final save = find.text('Salvar cadastro offline');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    final profile = await StorageService().loadProfile();
    expect(profile!.ubsCode, second.value);
    expect(profile.name, 'Synthetic Example');
  });
}
