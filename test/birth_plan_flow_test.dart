import 'package:flutter_test/flutter_test.dart';
import 'package:plano_parto_pet_saude/models/birth_plan_question.dart';
import 'package:plano_parto_pet_saude/services/birth_plan_flow_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled questionnaire loads with unique IDs and usable options',
      () async {
    final questions = await BirthPlanFlowService().loadQuestions();

    expect(questions, isNotEmpty);
    expect(questions.map((q) => q.id).toSet(), hasLength(questions.length));
    for (final question in questions) {
      expect(question.id.trim(), isNotEmpty);
      expect(question.section.trim(), isNotEmpty);
      expect(question.question.trim(), isNotEmpty);
      expect(
          question.options.every((option) => option.trim().isNotEmpty), isTrue);
      expect(question.options.toSet(), hasLength(question.options.length));
    }
  });

  test('older questionnaire entries default to a single predefined answer', () {
    final question = BirthPlanQuestion.fromJson({
      'id': 'example',
      'section': 'Example',
      'question': 'Example question?',
      'options': ['A', 'B'],
    });

    expect(question.multiple, isFalse);
    expect(question.allowOther, isFalse);
  });
}
