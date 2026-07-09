import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/birth_plan_question.dart';

class BirthPlanFlowService {
  Future<List<BirthPlanQuestion>> loadQuestions() async {
    final raw = await rootBundle.loadString('assets/data/birth_plan_flow.json');
    final data = jsonDecode(raw) as List<dynamic>;
    return data.map((item) => BirthPlanQuestion.fromJson(item as Map<String, dynamic>)).toList();
  }
}
