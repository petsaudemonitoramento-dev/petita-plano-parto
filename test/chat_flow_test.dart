import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plano_parto_pet_saude/screens/chat/chat_screen.dart';
import 'package:plano_parto_pet_saude/services/birth_plan_flow_service.dart';
import 'package:plano_parto_pet_saude/services/storage_service.dart';

import 'support/offline_helpers.dart';

void main() {
  setUp(resetOfflineState);

  Future<void> openChat(WidgetTester tester) async {
    setViewport(tester, const Size(800, 1200));
    await tester.pumpWidget(const MaterialApp(home: ChatScreen()));
    await tester.pumpAndSettle();
    await tapChoice(tester, 'Montar meu plano');
  }

  Future<void> reachPriorities(WidgetTester tester) async {
    final questions = await BirthPlanFlowService().loadQuestions();
    await openChat(tester);
    await sendText(tester, 'Gestante Sintetica');
    await sendText(tester, '01/12/2026');
    for (final q in questions.skip(2).take(3)) {
      await tapChoice(tester, q.options.first);
    }
  }

  testWidgets('all 31 questions persist single, multiple and free text answers',
      (tester) async {
    final questions = await BirthPlanFlowService().loadQuestions();
    expect(questions, hasLength(31));
    await openChat(tester);
    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      expect(find.text('Etapa ${i + 1} de 31'), findsOneWidget);
      if (q.multiple) {
        await tapChoice(tester, q.options[0]);
        await tapChoice(tester, q.options[1]);
        await tapChoice(tester, q.options[0]);
        await tapChoice(tester, 'Concluir seleção');
      } else if (q.id == 'nome_gestante' ||
          q.id == 'dpp' ||
          q.id == 'preferencias_culturais' ||
          q.id == 'observacoes_finais') {
        await sendText(
            tester, q.id == 'dpp' ? '01/12/2026' : 'Sintetico ${q.id}');
      } else {
        await tapChoice(tester, q.options.first);
      }
      final saved = await StorageService().loadAnswers();
      expect(saved, hasLength(i + 1), reason: q.id);
      expect(saved.last.questionId, q.id);
      expect(
          saved.last.values,
          q.multiple
              ? [q.options[1]]
              : [
                  q.id == 'dpp'
                      ? '01/12/2026'
                      : (q.id == 'nome_gestante' ||
                              q.id == 'preferencias_culturais' ||
                              q.id == 'observacoes_finais')
                          ? 'Sintetico ${q.id}'
                          : q.options.first
                ]);
    }
    expect(
        find.textContaining('Seu Plano de Parto está pronto'), findsOneWidget);
    expect(find.widgetWithText(InkWell, 'Ver meu plano'), findsOneWidget);
  });

  testWidgets('empty multiple selection keeps choices available to recover',
      (tester) async {
    final questions = await BirthPlanFlowService().loadQuestions();
    await reachPriorities(tester);
    await tapChoice(tester, 'Concluir seleção');
    expect(
        find.textContaining('Selecione pelo menos uma opção'), findsOneWidget);
    expect(find.widgetWithText(InkWell, questions[5].options.first),
        findsOneWidget);
    await tapChoice(tester, questions[5].options.first);
    await tapChoice(tester, 'Concluir seleção');
    expect((await StorageService().loadAnswers()).last.values,
        [questions[5].options.first]);
  });

  testWidgets('multiple choices and typed complement are both preserved',
      (tester) async {
    final questions = await BirthPlanFlowService().loadQuestions();
    await reachPriorities(tester);
    await tapChoice(tester, questions[5].options.first);
    await sendText(tester, 'Preferencia sintetica adicional');
    expect((await StorageService().loadAnswers()).last.values,
        [questions[5].options.first, 'Preferencia sintetica adicional']);
  });

  testWidgets(
      'reopening a partial plan resumes without deleting persisted answers',
      (tester) async {
    await openChat(tester);
    await sendText(tester, 'Gestante Sintetica');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    // Recreate the widget tree and the storage service, keeping the mock backing store.
    await tester.pumpWidget(const MaterialApp(home: ChatScreen()));
    await tester.pumpAndSettle();
    await tapChoice(tester, 'Montar meu plano');
    expect(find.text('Etapa 2 de 31'), findsOneWidget);
    expect((await StorageService().loadAnswers()).single.values,
        ['Gestante Sintetica']);
    await sendText(tester, '01/12/2026');
    expect(await StorageService().loadAnswers(), hasLength(2));
  });

  testWidgets(
      'revising a completed plan updates one answer without deleting the rest',
      (tester) async {
    final questions = await BirthPlanFlowService().loadQuestions();
    await StorageService().saveAnswers(syntheticAnswers(questions));
    await openChat(tester);
    await sendText(tester, 'Nome Sintetico Editado');
    final saved = await StorageService().loadAnswers();
    expect(saved, hasLength(31));
    expect(saved.singleWhere((a) => a.questionId == 'nome_gestante').values,
        ['Nome Sintetico Editado']);
    expect(saved.singleWhere((a) => a.questionId == questions.last.id).values,
        ['AUDIT30']);
  });

  testWidgets('chat credits the requested developer without changing the medical notice',
      (tester) async {
    await openChat(tester);
    expect(find.text('Desenvolvedor: Lucca Araújo'), findsOneWidget);
    expect(
      find.text(
        'A Petita pode cometer erros. Confirme informações importantes com a equipe de saúde.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

    testWidgets('blank input does not advance or persist an answer',
      (tester) async {
    await openChat(tester);
    await sendText(tester, '   ');
    expect(find.text('Etapa 1 de 31'), findsOneWidget);
    expect(await StorageService().loadAnswers(), isEmpty);
  });

  testWidgets(
      'rapid double submission answers once without skipping the next question',
      (tester) async {
    await openChat(tester);
    final choice = find.widgetWithText(InkWell, 'Prefiro não informar');
    await tester.scrollUntilVisible(choice, 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(choice);
    await tester.tap(choice);
    await advanceChat(tester);
    expect(find.text('Etapa 2 de 31'), findsOneWidget);
    expect(await StorageService().loadAnswers(), hasLength(1));
  });

  testWidgets(
      'manual UBS warning returns to free text without saving its placeholder',
      (tester) async {
    final questions = await BirthPlanFlowService().loadQuestions();
    await StorageService()
        .saveAnswers(syntheticAnswers(questions.take(3).toList()));
    await openChat(tester);
    final option = find.widgetWithText(InkWell, 'Outra UBS').last;
    await tester.scrollUntilVisible(option, 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(option);
    await tester.pumpAndSettle();
    expect(find.text('UBS fora da lista oficial'), findsOneWidget);
    expect(await StorageService().loadAnswers(), hasLength(3));
    await tester.tap(find.text('Entendi'));
    await advanceChat(tester);
    await sendText(tester, 'UBS Sintetica');
    expect(
        (await StorageService().loadAnswers()).last.values, ['UBS Sintetica']);
  });

  testWidgets(
      'leaving chat during a pending command does not use a disposed context',
      (tester) async {
    setViewport(tester, const Size(800, 1200));
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => const ChatScreen())),
                      child: const Text('Abrir')),
                ))));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Abrir cadastro');
    await tester.tap(find.byIcon(Icons.send));
    await tester.tap(find.byIcon(Icons.arrow_back));
    await advanceChat(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Abrir'), findsOneWidget);
  });

  testWidgets(
      'choosing to describe a cultural preference waits for the description',
      (tester) async {
    final questions = await BirthPlanFlowService().loadQuestions();
    await StorageService()
        .saveAnswers(syntheticAnswers(questions.take(29).toList()));
    await openChat(tester);
    await tapChoice(tester, 'Sim, vou descrever');
    expect(find.text('Etapa 30 de 31'), findsOneWidget);
    expect(await StorageService().loadAnswers(), hasLength(29));
    await sendText(tester, 'Preferencia pessoal sintetica');
    final saved = await StorageService().loadAnswers();
    expect(
        saved
            .singleWhere((a) => a.questionId == 'preferencias_culturais')
            .values,
        ['Preferencia pessoal sintetica']);
    expect(find.text('Etapa 31 de 31'), findsOneWidget);
  });
}
