// Characterization of open findings, not proof of safe persistence.
import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:plano_parto_pet_saude/models/birth_plan_answer.dart';
import 'package:plano_parto_pet_saude/models/ubs_question.dart';
import 'package:plano_parto_pet_saude/services/storage_service.dart';
import 'package:plano_parto_pet_saude/screens/birth_plan/birth_plan_summary_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class ControlledWrites extends InMemorySharedPreferencesStore {
  ControlledWrites() : super.empty();
  bool reject = false;
  bool throwError = false;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (reject) {
      if (throwError) throw StateError('fixture write failure');
      return false;
    }
    return super.setValue(type, key, value);
  }
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

  test('revocation removes synthetic legacy UBS question from device', () async {
    final storage = StorageService();
    await storage.saveUbsQuestion(UbsQuestion(
      id: 'fixture-q-a', anonymousUserId: 'fixture-patient-a',
      question: 'SYNTHETIC-QUESTION', ubsCode: 'FIXTURE-UBS-A',
      createdAt: DateTime.utc(2026),
    ));
    await storage.revokeConsentAndClearPatientData();
    await (await SharedPreferences.getInstance()).reload();
    expect(await StorageService().loadUbsQuestions(), isEmpty);
    // No current screen calls this legacy API; assess existing installs separately.
  });

  for (final throwsError in [false, true]) {
    test('refused answer write preserves previous answers and reports failure ($throwsError)', () async {
      final store = ControlledWrites();
      SharedPreferencesStorePlatform.instance = store;
      await StorageService().saveAnswers([
        BirthPlanAnswer(questionId: 'old', values: ['PREVIOUS']),
      ]);
      store.reject = true;
      store.throwError = throwsError;
      await expectLater(StorageService().saveAnswers([
        BirthPlanAnswer(questionId: 'new', values: ['NEW']),
      ]), throwsA(isA<StateError>()));
      expect((await StorageService().loadAnswers()).single.questionId, 'old');
      await (await SharedPreferences.getInstance()).reload();
      expect((await StorageService().loadAnswers()).single.values, ['PREVIOUS']);
    });
  }

  test('refused note write retains durable previous note and reports failure', () async {
    final store = ControlledWrites();
    SharedPreferencesStorePlatform.instance = store;
    await StorageService().saveConsultationNotes('PREVIOUS');
    store.reject = true;
    await expectLater(StorageService().saveConsultationNotes('NEW'),
        throwsA(isA<StateError>()));
    expect(await StorageService().loadConsultationNotes(), 'PREVIOUS');
    await (await SharedPreferences.getInstance()).reload();
    expect(await StorageService().loadConsultationNotes(), 'PREVIOUS');
  });

  test('overlapping deferrals preserve both pending questions', () async {
    final storage = StorageService();
    await Future.wait([
      storage.deferQuestionForConsultation('fixture-a'),
      storage.deferQuestionForConsultation('fixture-b'),
    ]);
    final pending = await storage.loadConsultationPending();
    expect(pending, hasLength(2));
    expect(pending.difference({'fixture-a', 'fixture-b'}), isEmpty);
  });

  testWidgets('notes UI keeps typed text and shows failure instead of saved confirmation', (tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = ControlledWrites();
    SharedPreferencesStorePlatform.instance = store;
    await StorageService().saveConsultationNotes('PREVIOUS');
    await tester.pumpWidget(const MaterialApp(home: BirthPlanSummaryScreen()));
    await tester.pumpAndSettle();
    final field = find.byType(TextField).first;
    await tester.enterText(field, 'NEW-UNSAVED');
    store.reject = true;
    final save = find.text('Salvar minhas dúvidas');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Dúvidas para a consulta salvas neste aparelho.'), findsNothing);
    expect(find.textContaining('Não foi possível confirmar a alteração'), findsOneWidget);
    expect(tester.widget<TextField>(field).controller!.text, 'NEW-UNSAVED');
    expect(await StorageService().loadConsultationNotes(), 'PREVIOUS');
  });
}
