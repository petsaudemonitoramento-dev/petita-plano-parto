import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:plano_parto_pet_saude/services/institutional/protected_patient_store.dart';
import 'package:plano_parto_pet_saude/services/storage_service.dart';
import 'package:plano_parto_pet_saude/models/birth_plan_answer.dart';
import 'support/institutional_fakes.dart';

class RefusedEnvelope extends InMemorySharedPreferencesStore {
  RefusedEnvelope() : super.empty();
  bool refuse = false;
  @override
  Future<bool> setValue(String type, String key, Object value) async =>
      refuse ? false : await super.setValue(type, key, value);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    StorageService.protectedStore = null;
    StorageService.protectionRequired = false;
  });
  test(
      'migrates snapshot, verifies decrypt, preserves legacy and encrypts all new data',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final vault = MemoryVault();
    await prefs.setString('birth_plan_answers',
        '[{"questionId":"fixture","values":["LEGACY-SYNTHETIC"]}]');
    final store = ProtectedPatientStore(vault, prefs);
    await store.initialize();
    expect(store.read('birth_plan_answers'), contains('LEGACY-SYNTHETIC'));
    expect(prefs.getString('birth_plan_answers'), contains('LEGACY-SYNTHETIC'));
    StorageService.protectedStore = store;
    StorageService.protectionRequired = true;
    await StorageService().saveAnswers([
      BirthPlanAnswer(questionId: 'fixture', values: ['NEW-SYNTHETIC'])
    ]);
    expect(prefs.getString(ProtectedPatientStore.recordKey),
        isNot(contains('NEW-SYNTHETIC')));
    expect(prefs.getString('birth_plan_answers'),
        isNot(contains('NEW-SYNTHETIC')));
    final reopened = ProtectedPatientStore(vault, prefs);
    await reopened.initialize();
    expect(reopened.read('birth_plan_answers'), contains('NEW-SYNTHETIC'));
  });
  test('missing key never replaces envelope or falls back to empty/legacy',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final vault = MemoryVault();
    final store = ProtectedPatientStore(vault, prefs);
    await store.initialize();
    final before = prefs.getString(ProtectedPatientStore.recordKey);
    vault.values.clear();
    await expectLater(
        ProtectedPatientStore(vault, prefs).initialize(), throwsStateError);
    expect(prefs.getString(ProtectedPatientStore.recordKey), before);
  });
  test('tampered tag is denied without rewriting evidence', () async {
    final prefs = await SharedPreferences.getInstance();
    final vault = MemoryVault();
    final store = ProtectedPatientStore(vault, prefs);
    await store.initialize();
    final raw =
        jsonDecode(prefs.getString(ProtectedPatientStore.recordKey)!) as Map;
    raw['tag'] = base64Encode(List.filled(16, 0));
    final changed = jsonEncode(raw);
    await prefs.setString(ProtectedPatientStore.recordKey, changed);
    await expectLater(
        ProtectedPatientStore(vault, prefs).initialize(), throwsA(anything));
    expect(prefs.getString(ProtectedPatientStore.recordKey), changed);
  });
  test(
      'failed ciphertext write preserves last verified snapshot and retries with fresh nonce',
      () async {
    final platform = RefusedEnvelope();
    SharedPreferencesStorePlatform.instance = platform;
    final prefs = await SharedPreferences.getInstance();
    final store = ProtectedPatientStore(MemoryVault(), prefs);
    await store.initialize();
    await store.write('birth_plan_consultation_notes_v1', 'PREVIOUS');
    final before = prefs.getString(ProtectedPatientStore.recordKey);
    platform.refuse = true;
    await expectLater(store.write('birth_plan_consultation_notes_v1', 'NEW'),
        throwsStateError);
    expect(store.read('birth_plan_consultation_notes_v1'), 'PREVIOUS');
    platform.refuse = false;
    await store.write('birth_plan_consultation_notes_v1', 'PREVIOUS');
    expect(prefs.getString(ProtectedPatientStore.recordKey), isNot(before));
  });
  test('explicit revocation erases protected fields and their legacy residue',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('birth_plan_consultation_notes_v1', 'LEGACY');
    final store = ProtectedPatientStore(MemoryVault(), prefs);
    await store.initialize();
    StorageService.protectedStore = store;
    StorageService.protectionRequired = true;
    await StorageService().revokeConsentAndClearPatientData();
    expect(store.read('birth_plan_consultation_notes_v1'), isNull);
    expect(prefs.containsKey('birth_plan_consultation_notes_v1'), false);
  });
}
