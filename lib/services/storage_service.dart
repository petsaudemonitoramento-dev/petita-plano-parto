import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/birth_plan_answer.dart';
import '../models/ubs_question.dart';

class StorageService {
  static const _answersKey = 'birth_plan_answers';
  static const _consentKey = 'consent_accepted';
  static const _ubsQuestionsKey = 'ubs_questions';

  Future<void> saveAnswers(List<BirthPlanAnswer> answers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_answersKey, jsonEncode(answers.map((a) => a.toJson()).toList()));
  }

  Future<List<BirthPlanAnswer>> loadAnswers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_answersKey);
    if (raw == null) return [];
    final data = jsonDecode(raw) as List<dynamic>;
    return data.map((item) => BirthPlanAnswer.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> clearAnswers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_answersKey);
  }

  Future<bool> hasConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_consentKey) ?? false;
  }

  Future<void> setConsentAccepted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentKey, value);
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
}
