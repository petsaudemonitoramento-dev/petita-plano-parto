import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plano_parto_pet_saude/services/birth_plan_flow_service.dart';
import 'package:plano_parto_pet_saude/services/storage_service.dart';
import 'package:plano_parto_pet_saude/models/user_profile.dart';

import 'support/offline_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final raw in [
    'not json',
    '{}',
    '[{}]',
    '[{"questionId":7,"values":[]}]'
  ]) {
    test('malformed answers recover as empty without erasing raw storage: $raw',
        () async {
      SharedPreferences.setMockInitialValues({'birth_plan_answers': raw});
      expect(await StorageService().loadAnswers(), isEmpty);
      expect(
          (await SharedPreferences.getInstance())
              .getString('birth_plan_answers'),
          raw);
    });
  }
  for (final raw in ['not json', '[]', '{}', '{"createdAt":"invalid"}']) {
    test('malformed profile recovers without blocking local use: $raw',
        () async {
      SharedPreferences.setMockInitialValues({'local_user_profile': raw});
      expect(await StorageService().loadProfile(), isNull);
      expect(
          (await SharedPreferences.getInstance())
              .getString('local_user_profile'),
          raw);
    });
  }

  test(
      'full local data survives backing-store reload; clearing plan preserves profile and consent',
      () async {
    final storage = StorageService();
    final questions = await BirthPlanFlowService().loadQuestions();
    await storage.saveAnswers(syntheticAnswers(questions));
    await storage.saveConsentAcknowledgements();
    await storage.saveProfile(UserProfile(
        id: 'synthetic',
        name: 'Sintetica',
        email: 'test@example.invalid',
        role: 'patient',
        ubsCode: 'UBS-EV-001',
        createdAt: DateTime(2026, 10, 28)));
    final prefs = await SharedPreferences.getInstance();
    final snapshot = {for (final key in prefs.getKeys()) key: prefs.get(key)!};
    SharedPreferences.setMockInitialValues(snapshot);
    final restarted = StorageService();
    expect((await restarted.loadAnswers()).map((a) => a.toJson()).toList(),
        syntheticAnswers(questions).map((a) => a.toJson()).toList());
    expect(await restarted.hasConsent(), isTrue);
    expect((await restarted.loadProfile())!.ubsCode, 'UBS-EV-001');
    await restarted.clearAnswers();
    expect(await StorageService().loadAnswers(), isEmpty);
    expect(await StorageService().hasConsent(), isTrue);
    expect(await StorageService().loadProfile(), isNotNull);
  });
}
