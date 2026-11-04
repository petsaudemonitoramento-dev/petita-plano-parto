import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plano_parto_pet_saude/screens/chat/chat_screen.dart';
import 'package:plano_parto_pet_saude/services/birth_plan_flow_service.dart';
import 'package:plano_parto_pet_saude/services/storage_service.dart';

import 'support/offline_helpers.dart';

void main() {
  setUp(resetOfflineState);

  test('questoes adiadas e notas ficam offline e sao removidas com o plano', () async {
    final storage = StorageService();
    await storage.deferQuestionForConsultation('prioridade_parto');
    await storage.saveConsultationNotes('Levar a pergunta sobre acompanhante');
    expect(await storage.loadConsultationPending(), contains('prioridade_parto'));
    expect(await storage.loadConsultationNotes(),
        'Levar a pergunta sobre acompanhante');

    await storage.resolveQuestionForConsultation('prioridade_parto');
    expect(await storage.loadConsultationPending(), isEmpty);
    await storage.deferQuestionForConsultation('prioridade_parto');
    await storage.clearAnswers();
    expect(await storage.loadConsultationPending(), isEmpty);
    expect(await storage.loadConsultationNotes(), isEmpty);
  });

  testWidgets('adiar a pergunta nao registra uma resposta ficticia',
      (tester) async {
    setViewport(tester, const Size(800, 1200));
    final questions = await BirthPlanFlowService().loadQuestions();
    await StorageService()
        .saveAnswers(syntheticAnswers(questions.take(4).toList()));

    await tester.pumpWidget(const MaterialApp(home: ChatScreen()));
    await tester.pumpAndSettle();
    await tapChoice(tester, 'Montar meu plano');
    expect(find.text('Encontramos um plano salvo'), findsOneWidget);
    await tester.tap(find.text('Continuar meu plano'));
    await advanceChat(tester);

    final pendingQuestion = questions[4];
    expect(find.text('Conversar sobre isto na próxima consulta'), findsOneWidget);
    await tester.tap(find.text('Conversar sobre isto na próxima consulta'));
    await advanceChat(tester);

    final saved = await StorageService().loadAnswers();
    expect(saved.where((a) => a.questionId == pendingQuestion.id), isEmpty);
    expect(await StorageService().loadConsultationPending(),
        contains(pendingQuestion.id));
  });
}
