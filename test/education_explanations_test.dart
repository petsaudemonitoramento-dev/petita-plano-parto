import 'package:flutter_test/flutter_test.dart';
import 'package:plano_parto_pet_saude/services/birth_plan_explanations.dart';
import 'package:plano_parto_pet_saude/services/birth_plan_flow_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cada pergunta canônica possui quatro partes de explicação acessível', () async {
    final questions = await BirthPlanFlowService().loadQuestions();
    expect(questions, hasLength(31));
    for (final question in questions) {
      final explanation = BirthPlanExplanations.forQuestion(question.id);
      expect(explanation, isNotNull, reason: question.id);
      for (final heading in [
        'O que significa?',
        'Como acontece na prática?',
        'Por que isso importa?',
        'O que você pode escolher ou perguntar?',
      ]) {
        expect(explanation, contains(heading), reason: question.id);
      }
      expect(explanation!.length, greaterThan(100), reason: question.id);
    }
  });
}
