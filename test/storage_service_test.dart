import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plano_parto_pet_saude/models/birth_plan_answer.dart';
import 'package:plano_parto_pet_saude/models/consent_record.dart';
import 'package:plano_parto_pet_saude/models/user_profile.dart';
import 'package:plano_parto_pet_saude/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageService storage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
  });

  test('empty local storage has no answers, profile or consent', () async {
    expect(await storage.loadAnswers(), isEmpty);
    expect(await storage.loadProfile(), isNull);
    expect(await storage.hasConsent(), isFalse);
  });

  test('answers survive a new service instance and can be cleared', () async {
    final answers = [
      BirthPlanAnswer(questionId: 'example', values: ['A', 'B']),
    ];
    await storage.saveAnswers(answers);
    final restored = await StorageService().loadAnswers();

    expect(restored.map((answer) => answer.toJson()).toList(),
        answers.map((answer) => answer.toJson()).toList());
    await storage.clearAnswers();
    expect(await storage.loadAnswers(), isEmpty);
  });

  test('acceptance persists every acknowledgement and the current version',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('consent_accepted', true);
    final before = DateTime.now();
    await storage.saveConsentAcknowledgements();
    final record = ConsentRecord.fromJson(
      jsonDecode(prefs.getString('consent_record_v2')!) as Map<String, dynamic>,
    );

    expect(record.isCurrentAndComplete, isTrue);
    expect(record.acceptedAt.isBefore(before), isFalse);
    expect(record.acceptedAt.isAfter(DateTime.now()), isFalse);
    expect(prefs.containsKey('consent_accepted'), isFalse);
    expect(await StorageService().hasConsent(), isTrue);
  });

  for (final flag in [
    'acceptedTerms',
    'acceptedPrivacy',
    'acceptedResponsibility',
    'acceptedPlanScience',
    'acceptedHealthData',
  ]) {
    test('consent remains invalid without $flag', () async {
      await storage.saveConsentAcknowledgements();
      final prefs = await SharedPreferences.getInstance();
      final record = jsonDecode(prefs.getString('consent_record_v2')!)
          as Map<String, dynamic>;
      record[flag] = false;
      await prefs.setString('consent_record_v2', jsonEncode(record));

      expect(await storage.hasConsent(), isFalse);
    });
  }

  test('outdated consent is rejected', () async {
    await storage.saveConsentAcknowledgements();
    final prefs = await SharedPreferences.getInstance();
    final record = jsonDecode(prefs.getString('consent_record_v2')!)
        as Map<String, dynamic>;
    record['termsVersion'] = 'outdated';
    await prefs.setString('consent_record_v2', jsonEncode(record));

    expect(await storage.hasConsent(), isFalse);
  });

  test('legacy consent alone and malformed records never grant access',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('consent_accepted', true);
    expect(await storage.hasConsent(), isFalse);
    for (final raw in ['not json', '{}']) {
      await prefs.setString('consent_record_v2', raw);
      expect(await storage.hasConsent(), isFalse);
    }
  });

  test('revocation clears consent, answers and synthetic local profile',
      () async {
    final profile = UserProfile(
      id: 'test-local',
      name: 'Synthetic Example',
      email: 'example@example.invalid',
      role: 'patient',
      createdAt: DateTime.utc(2026),
    );
    await storage.saveProfile(profile);
    expect((await storage.loadProfile())!.toJson(), profile.toJson());
    await storage.saveAnswers([
      BirthPlanAnswer(questionId: 'example', values: ['A']),
    ]);
    await storage.saveConsentAcknowledgements();
    await storage.revokeConsentAndClearPatientData();

    expect(await storage.hasConsent(), isFalse);
    expect(await storage.loadAnswers(), isEmpty);
    expect(await storage.loadProfile(), isNull);
  });
}
