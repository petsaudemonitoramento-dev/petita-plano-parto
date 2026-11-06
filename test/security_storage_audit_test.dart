// Characterization of open findings, not proof of safe persistence.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:plano_parto_pet_saude/models/birth_plan_answer.dart';
import 'package:plano_parto_pet_saude/models/ubs_question.dart';
import 'package:plano_parto_pet_saude/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class RejectingWrites extends InMemorySharedPreferencesStore {
  RejectingWrites() : super.empty();
  @override
  Future<bool> setValue(String type, String key, Object value) async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => SharedPreferences.setMockInitialValues({}));

  test('[finding] local health answer and note are directly readable JSON/text', () async {
    final storage = StorageService();
    await storage.saveAnswers([
      BirthPlanAnswer(questionId: 'fixture-question', values: ['SYNTHETIC-HEALTH']),
    ]);
    await storage.saveConsultationNotes('SYNTHETIC-NOTE');
    final prefs = await SharedPreferences.getInstance();
    final decoded = jsonDecode(prefs.getString('birth_plan_answers')!) as List;
    expect(decoded.single['values'], ['SYNTHETIC-HEALTH']);
    expect(prefs.getString('birth_plan_consultation_notes_v1'), 'SYNTHETIC-NOTE');
  });

  test('[finding] revocation leaves synthetic legacy UBS question on device', () async {
    final storage = StorageService();
    await storage.saveUbsQuestion(UbsQuestion(
      id: 'fixture-q-a', anonymousUserId: 'fixture-patient-a',
      question: 'SYNTHETIC-QUESTION', ubsCode: 'FIXTURE-UBS-A',
      createdAt: DateTime.utc(2026),
    ));
    await storage.revokeConsentAndClearPatientData();
    await (await SharedPreferences.getInstance()).reload();
    expect((await StorageService().loadUbsQuestions()).single.question, 'SYNTHETIC-QUESTION');
    // No current screen calls this legacy API; assess existing installs separately.
  });

  test('[finding] rejected answer write reports success but disappears after reload', () async {
    await SharedPreferences.getInstance();
    SharedPreferencesStorePlatform.instance = RejectingWrites();
    await StorageService().saveAnswers([
      BirthPlanAnswer(questionId: 'fixture-question', values: ['SYNTHETIC-ANSWER']),
    ]); // Completes normally despite underlying false result.
    expect(await StorageService().loadAnswers(), hasLength(1)); // cache masks failure
    await (await SharedPreferences.getInstance()).reload();
    expect(await StorageService().loadAnswers(), isEmpty);
  });

  test('[finding] rejected note write completes but is not durable', () async {
    await SharedPreferences.getInstance();
    SharedPreferencesStorePlatform.instance = RejectingWrites();
    await StorageService().saveConsultationNotes('SYNTHETIC-NOTE');
    await (await SharedPreferences.getInstance()).reload();
    expect(await StorageService().loadConsultationNotes(), isEmpty);
  });

  test('[finding] overlapping deferrals lose one pending question', () async {
    final storage = StorageService();
    await Future.wait([
      storage.deferQuestionForConsultation('fixture-a'),
      storage.deferQuestionForConsultation('fixture-b'),
    ]);
    final pending = await storage.loadConsultationPending();
    expect(pending, hasLength(1));
    expect(pending.difference({'fixture-a', 'fixture-b'}), isEmpty);
  });
}
