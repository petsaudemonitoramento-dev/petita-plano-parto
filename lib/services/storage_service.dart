import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/birth_plan_answer.dart';
import '../models/consent_record.dart';
import '../models/knowledge_document.dart';
import '../models/ubs_question.dart';
import '../models/ubs_unit.dart';
import '../models/user_profile.dart';
import '../models/treatment_preferences.dart';

class LocalPersistenceException extends StateError {
  LocalPersistenceException() : super(
    'Não foi possível confirmar a alteração neste aparelho. Tente novamente.',
  );
}

class StorageService {
  static Future<void> _pendingMutation = Future<void>.value();

  // One queue across service instances, including reset/revocation operations.
  Future<void> _serialize(Future<void> Function() action) {
    final result = _pendingMutation.then((_) => action());
    _pendingMutation = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  static const _answersKey = 'birth_plan_answers';
  static const _deferredConsultationKey = 'birth_plan_consultation_deferred_v1';
  static const _consultationNotesKey = 'birth_plan_consultation_notes_v1';
  static const _treatmentKey = 'birth_plan_treatment_preferences_v1';
  static const _consentRecordKey = 'consent_record_v2';
  static const _legacyConsentKey = 'consent_accepted';
  static const _ubsQuestionsKey = 'ubs_questions';
  static const _profileKey = 'local_user_profile';
  static const _customUbsKey = 'custom_ubs_units';
  static const _documentsKey = 'knowledge_documents_local';

  // SharedPreferences updates its cache even when the platform rejects a write.
  // Reload on success and failure so callers never mistake that cache for storage.
  Future<void> _confirm(SharedPreferences prefs, Future<bool> Function() write,
      bool Function() matches) async {
    try {
      if (!await write()) throw LocalPersistenceException();
      await prefs.reload();
      if (!matches()) throw LocalPersistenceException();
    } catch (_) {
      try { await prefs.reload(); } catch (_) { /* Never claim a successful write. */ }
      throw LocalPersistenceException();
    }
  }

  Future<void> _putString(SharedPreferences prefs, String key, String value) =>
      _confirm(prefs, () => prefs.setString(key, value), () => prefs.getString(key) == value);

  Future<void> _putList(SharedPreferences prefs, String key, List<String> value) =>
      _confirm(prefs, () => prefs.setStringList(key, value),
          () => jsonEncode(prefs.getStringList(key)) == jsonEncode(value));

  Future<void> _remove(SharedPreferences prefs, String key) =>
      _confirm(prefs, () => prefs.remove(key), () => !prefs.containsKey(key));

  Future<void> saveAnswers(List<BirthPlanAnswer> answers) => _serialize(() async {
    final prefs = await SharedPreferences.getInstance();
    await _putString(prefs, _answersKey, jsonEncode(answers.map((a) => a.toJson()).toList()));
  });

  Future<List<BirthPlanAnswer>> loadAnswers() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(_answersKey);
      if (raw == null) return [];
      final data = jsonDecode(raw) as List<dynamic>;
      return data.map((item) => BirthPlanAnswer.fromJson(item as Map<String, dynamic>)).toList();
    } on FormatException {
      return [];
    } on TypeError {
      return [];
    }
  }

  Future<Set<String>> loadConsultationPending() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_deferredConsultationKey) ?? <String>[]).toSet();
  }

  Future<void> deferQuestionForConsultation(String questionId) => _serialize(() async {
    final ids = await loadConsultationPending();
    ids.add(questionId);
    final prefs = await SharedPreferences.getInstance();
    await _putList(prefs, _deferredConsultationKey, ids.toList());
  });

  Future<void> resolveQuestionForConsultation(String questionId) => _serialize(() async {
    final ids = await loadConsultationPending();
    ids.remove(questionId);
    final prefs = await SharedPreferences.getInstance();
    await _putList(prefs, _deferredConsultationKey, ids.toList());
  });

  Future<String> loadConsultationNotes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_consultationNotesKey) ?? '';
  }

  Future<void> saveConsultationNotes(String notes) => _serialize(() async {
    final prefs = await SharedPreferences.getInstance();
    await _putString(prefs, _consultationNotesKey, notes.trim());
  });

  Future<void> clearAnswers() => _serialize(() async {
    final prefs = await SharedPreferences.getInstance();
    await _remove(prefs, _answersKey);
    await _remove(prefs, _treatmentKey);
    await _remove(prefs, _deferredConsultationKey);
    await _remove(prefs, _consultationNotesKey);
  });

  Future<TreatmentPreferences?> loadTreatmentPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_treatmentKey);
    if (raw == null) return null;
    try {
      return TreatmentPreferences.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveTreatmentPreferences(TreatmentPreferences value) => _serialize(() async {
    final prefs = await SharedPreferences.getInstance();
    await _putString(prefs, _treatmentKey, jsonEncode(value.toJson()));
  });

  Future<void> clearTreatmentPreferences() => _serialize(() async {
    final prefs = await SharedPreferences.getInstance();
    await _remove(prefs, _treatmentKey);
  });

  Future<bool> hasConsent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_consentRecordKey);
    if (raw == null) return false;
    try {
      final record = ConsentRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return record.isCurrentAndComplete;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveConsentAcknowledgements() => _serialize(() async {
    final prefs = await SharedPreferences.getInstance();
    final record = ConsentRecord(
      acceptedTerms: true,
      acceptedPrivacy: true,
      acceptedResponsibility: true,
      acceptedPlanScience: true,
      acceptedHealthData: true,
      termsVersion: ConsentRecord.currentVersion,
      acceptedAt: DateTime.now(),
    );
    await _putString(prefs, _consentRecordKey, jsonEncode(record.toJson()));
    await _remove(prefs, _legacyConsentKey);
  });

  Future<void> revokeConsentAndClearPatientData() => _serialize(() async {
    final prefs = await SharedPreferences.getInstance();
    await _remove(prefs, _consentRecordKey);
    await _remove(prefs, _legacyConsentKey);
    await _remove(prefs, _answersKey);
    await _remove(prefs, _treatmentKey);
    await _remove(prefs, _deferredConsultationKey);
    await _remove(prefs, _consultationNotesKey);
    await _remove(prefs, _profileKey);
    await _remove(prefs, _ubsQuestionsKey);
    // Ação local; não remove informações anteriormente sincronizadas na nuvem.
  });

  Future<void> saveProfile(UserProfile profile) => _serialize(() async {
    final prefs = await SharedPreferences.getInstance();
    await _putString(prefs, _profileKey, jsonEncode(profile.toJson()));
  });

  Future<UserProfile?> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(_profileKey);
      if (raw == null) return null;
      return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> clearProfile() => _serialize(() async {
    final prefs = await SharedPreferences.getInstance();
    await _remove(prefs, _profileKey);
  });

  Future<void> saveUbsQuestion(UbsQuestion question) => _serialize(() async {
    final items = await loadUbsQuestions();
    items.add(question);
    await _saveUbsQuestions(items);
  });

  Future<List<UbsQuestion>> loadUbsQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_ubsQuestionsKey);
    if (raw == null) return [];
    final data = jsonDecode(raw) as List<dynamic>;
    return data.map((item) => UbsQuestion.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> answerUbsQuestion(String id, String answer) => _serialize(() async {
    final items = await loadUbsQuestions();
    final updated = items.map((q) {
      if (q.id == id) return q.copyWith(answer: answer, answeredAt: DateTime.now());
      return q;
    }).toList();
    await _saveUbsQuestions(updated);
  });

  Future<void> _saveUbsQuestions(List<UbsQuestion> items) async {
    final prefs = await SharedPreferences.getInstance();
    await _putString(prefs, _ubsQuestionsKey, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  Future<List<UbsUnit>> loadCustomUbsUnits() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_customUbsKey);
    if (raw == null) return [];
    final data = jsonDecode(raw) as List<dynamic>;
    return data.map((item) => UbsUnit.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> addCustomUbsUnit(UbsUnit unit) => _serialize(() async {
    final items = await loadCustomUbsUnits();
    items.add(unit);
    final prefs = await SharedPreferences.getInstance();
    await _putString(prefs, _customUbsKey, jsonEncode(items.map((e) => e.toJson()).toList()));
  });

  Future<List<KnowledgeDocument>> loadKnowledgeDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_documentsKey);
    if (raw == null) return [];
    final data = jsonDecode(raw) as List<dynamic>;
    return data.map((item) => KnowledgeDocument.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> addKnowledgeDocument(KnowledgeDocument document) => _serialize(() async {
    final items = await loadKnowledgeDocuments();
    items.add(document);
    final prefs = await SharedPreferences.getInstance();
    await _putString(prefs, _documentsKey, jsonEncode(items.map((e) => e.toJson()).toList()));
  });
}
