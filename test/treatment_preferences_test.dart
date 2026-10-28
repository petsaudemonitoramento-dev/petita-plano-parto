import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plano_parto_pet_saude/models/treatment_preferences.dart';
import 'package:plano_parto_pet_saude/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('pronomes são opcionais e não entram no PDF por padrão', () async {
    final storage = StorageService();
    expect(await storage.loadTreatmentPreferences(), isNull);
    await storage.saveTreatmentPreferences(
      const TreatmentPreferences(pronouns: 'Elu/delu'),
    );
    final reloaded = await StorageService().loadTreatmentPreferences();
    expect(reloaded!.pronouns, 'Elu/delu');
    expect(reloaded.includeInPdf, isFalse);
    await storage.saveTreatmentPreferences(reloaded.copyWith(includeInPdf: true));
    expect((await storage.loadTreatmentPreferences())!.includeInPdf, isTrue);
    await storage.clearAnswers();
    expect(await storage.loadTreatmentPreferences(), isNull);
  });

  test('revogação do consentimento remove preferência de tratamento', () async {
    final storage = StorageService();
    await storage.saveTreatmentPreferences(
      const TreatmentPreferences(pronouns: 'Prefiro que usem meu nome', includeInPdf: true),
    );
    await storage.revokeConsentAndClearPatientData();
    expect(await storage.loadTreatmentPreferences(), isNull);
  });
}
