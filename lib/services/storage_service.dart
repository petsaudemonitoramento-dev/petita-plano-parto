import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/birth_plan_answer.dart';
import '../models/consent_record.dart';
import '../models/knowledge_document.dart';
import '../models/ubs_question.dart';
import '../models/ubs_unit.dart';
import '../models/user_profile.dart';
import '../models/treatment_preferences.dart';

class StorageService {
  static const _answersKey = 'birth_plan_answers';
  static const _treatmentKey = 'birth_plan_treatment_preferences_v1';
  static const _consentRecordKey = 'consent_record_v2';
  static const _legacyConsentKey = 'consent_accepted';
  static const _ubsQuestionsKey = 'ubs_questions';
  static const _profileKey = 'local_user_profile';
  static const _customUbsKey = 'custom_ubs_units';
  static const _documentsKey = 'knowledge_documents_local';

  Future<void> saveAnswers(List<BirthPlanAnswer> answers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_answersKey, jsonEncode(answers.map((a) => a.toJson()).toList()));
  }

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

  Future<void> clearAnswers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_answersKey);
    await prefs.remove(_treatmentKey);
  }

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

  Future<void> saveTreatmentPreferences(TreatmentPreferences value) async {
    final prefs = await SharedPreferences.getInstance();
    final success = await prefs.setString(_treatmentKey, jsonEncode(value.toJson()));
    if (!success) throw StateError('Não foi possível salvar a preferência de tratamento.');
  }

  Future<void> clearTreatmentPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_treatmentKey);
  }

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

  Future<void> saveConsentAcknowledgements() async {
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
    final saved = await prefs.setString(_consentRecordKey, jsonEncode(record.toJson()));
    if (!saved) throw StateError('Não foi possível salvar a ciência neste dispositivo.');
    await prefs.remove(_legacyConsentKey);
  }

  Future<void> revokeConsentAndClearPatientData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_consentRecordKey);
    await prefs.remove(_legacyConsentKey);
    await prefs.remove(_answersKey);
    await prefs.remove(_treatmentKey);
    await prefs.remove(_profileKey);
    // Ação local; não remove informações anteriormente sincronizadas na nuvem.
  }

  Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
  }

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

  Future<void> clearProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileKey);
  }

  Future<void> saveUbsQuestion(UbsQuestion question) async {
    final items = await loadUbsQuestions();
    items.add(question);
    await _saveUbsQuestions(items);
  }

  Future<List<UbsQuestion>> loadUbsQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_ubsQuestionsKey);
    if (raw == null) return [];
    final data = jsonDecode(raw) as List<dynamic>;
    return data.map((item) => UbsQuestion.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> answerUbsQuestion(String id, String answer) async {
    final items = await loadUbsQuestions();
    final updated = items.map((q) {
      if (q.id == id) return q.copyWith(answer: answer, answeredAt: DateTime.now());
      return q;
    }).toList();
    await _saveUbsQuestions(updated);
  }

  Future<void> _saveUbsQuestions(List<UbsQuestion> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ubsQuestionsKey, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  Future<List<UbsUnit>> loadCustomUbsUnits() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_customUbsKey);
    if (raw == null) return [];
    final data = jsonDecode(raw) as List<dynamic>;
    return data.map((item) => UbsUnit.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> addCustomUbsUnit(UbsUnit unit) async {
    final items = await loadCustomUbsUnits();
    items.add(unit);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customUbsKey, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  Future<List<KnowledgeDocument>> loadKnowledgeDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_documentsKey);
    if (raw == null) return [];
    final data = jsonDecode(raw) as List<dynamic>;
    return data.map((item) => KnowledgeDocument.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> addKnowledgeDocument(KnowledgeDocument document) async {
    final items = await loadKnowledgeDocuments();
    items.add(document);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_documentsKey, jsonEncode(items.map((e) => e.toJson()).toList()));
  }
}
