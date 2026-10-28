import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plano_parto_pet_saude/screens/chat/chat_screen.dart';
import 'package:plano_parto_pet_saude/services/birth_plan_flow_service.dart';
import 'package:plano_parto_pet_saude/services/storage_service.dart';
import 'package:plano_parto_pet_saude/models/treatment_preferences.dart';

import 'support/offline_helpers.dart';

void main() {
  setUp(resetOfflineState);

  Future<void> openChat(WidgetTester tester) async {
    setViewport(tester, const Size(800, 1200));
    await tester.pumpWidget(const MaterialApp(home: ChatScreen()));
    await tester.pumpAndSettle();
    await tapChoice(tester, 'Montar meu plano');
  }

  String testDpp() {
    final date = DateTime.now().add(const Duration(days: 21));
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> reachPriorities(WidgetTester tester) async {
    final questions = await BirthPlanFlowService().loadQuestions();
    await openChat(tester);
    await sendText(tester, 'Gestante Sintetica');
    await tapChoice(tester, 'Prefiro não informar');
    await sendText(tester, testDpp());
    for (final q in questions.skip(3).take(2)) {
      await tapChoice(tester, q.options.first);
    }
  }

  testWidgets('31 canonical answers persist with DPP and optional pronouns',
      (tester) async {
    final questions = await BirthPlanFlowService().loadQuestions();
    expect(questions, hasLength(31));
    await openChat(tester);
    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      // The third canonical answer is calculated rather than asked.
      if (q.id == 'semanas_gestacao') continue;
      final shown = i < 2 ? i + 1 : i;
      final total = i < 2 ? 31 : 30;
      expect(find.text('Etapa $shown de $total'), findsOneWidget);
      if (q.multiple) {
        await tapChoice(tester, q.options[0]);
        await tapChoice(tester, q.options[1]);
        await tapChoice(tester, q.options[0]);
        await tapChoice(tester, 'Concluir seleção');
      } else if (q.id == 'nome_gestante') {
        await sendText(tester, 'Gestante Sintetica');
        // Optional onboarding between first and second canonical questions.
        await tapChoice(tester, 'Ela/dela');
      } else if (q.id == 'dpp') {
        await sendText(tester, testDpp());
      } else if (q.id == 'preferencias_culturais') {
        await tapChoice(tester, 'Sim, vou descrever');
        await sendText(tester, 'Preferencia cultural sintetica');
      } else if (q.id == 'observacoes_finais') {
        await sendText(tester, 'Observacao final sintetica');
      } else {
        await tapChoice(tester, q.options.first);
      }
      final saved = await StorageService().loadAnswers();
      expect(saved, hasLength(i == 0 ? 1 : i == 1 ? 3 : i + 1), reason: q.id);
      if (q.id == 'dpp') {
        expect(
          saved.singleWhere((a) => a.questionId == 'semanas_gestacao').values.first,
          contains('estimativa em'),
        );
      } else {
        expect(saved.last.questionId, q.id);
      }
    }
    expect(
      (await StorageService().loadTreatmentPreferences())!.pronouns,
      'Ela/dela',
    );
    expect(find.textContaining('Seu Plano de Parto está pronto'), findsOneWidget);
    expect(find.widgetWithText(InkWell, 'Ver meu plano'), findsOneWidget);
  });

  testWidgets('opção Outro aguarda texto e salva a frase, não o marcador',
      (tester) async {
    await reachPriorities(tester);
    await tapChoice(tester, 'Outro');
    expect(tester.widget<TextField>(find.byType(TextField).first).enabled, isTrue);
    expect(await StorageService().loadAnswers(), hasLength(5));
    await sendText(tester, 'Preferência personalizada sintética');
    final saved = await StorageService().loadAnswers();
    expect(saved.last.questionId, 'prioridade_parto');
    expect(saved.last.values, ['Preferência personalizada sintética']);
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
    await tapChoice(tester, 'Escrever minha resposta');
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
    expect(find.text('Encontramos um plano salvo'), findsOneWidget);
    await tester.tap(find.text('Continuar meu plano'));
    await advanceChat(tester);
    expect(find.text('Etapa 2 de 31'), findsOneWidget);
    expect((await StorageService().loadAnswers()).single.values,
        ['Gestante Sintetica']);
    await sendText(tester, '01/12/2026');
    expect(await StorageService().loadAnswers(), hasLength(3));
  });

  testWidgets('reopening nine saved answers asks before resuming at step 10',
      (tester) async {
    final questions = await BirthPlanFlowService().loadQuestions();
    await StorageService().saveAnswers(syntheticAnswers(questions).take(9).toList());
    setViewport(tester, const Size(800, 1200));
    await tester.pumpWidget(const MaterialApp(home: ChatScreen()));
    await tester.pumpAndSettle();
    await tapChoice(tester, 'Montar meu plano');
    expect(find.text('Encontramos um plano salvo'), findsOneWidget);
    expect(find.text('Continuar meu plano'), findsOneWidget);
    expect(find.text('Começar novo plano'), findsOneWidget);
    expect(await StorageService().loadAnswers(), hasLength(9));

    await tester.tap(find.text('Continuar meu plano'));
    await advanceChat(tester);
    expect(find.text('Etapa 10 de 31'), findsOneWidget);
    expect(await StorageService().loadAnswers(), hasLength(9));
  });

  testWidgets('starting again clears only old answers after an explicit choice',
      (tester) async {
    final questions = await BirthPlanFlowService().loadQuestions();
    await StorageService().saveAnswers(syntheticAnswers(questions).take(9).toList());
    await StorageService().saveTreatmentPreferences(
      const TreatmentPreferences(pronouns: 'Ela/dela', includeInPdf: true),
    );
    setViewport(tester, const Size(800, 1200));
    await tester.pumpWidget(const MaterialApp(home: ChatScreen()));
    await tester.pumpAndSettle();
    await tapChoice(tester, 'Montar meu plano');
    expect(find.text('Encontramos um plano salvo'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await advanceChat(tester);
    expect(await StorageService().loadAnswers(), hasLength(9));
    expect(await StorageService().loadTreatmentPreferences(), isNotNull);

    await tapChoice(tester, 'Montar meu plano');
    await tester.tap(find.text('Começar novo plano'));
    await advanceChat(tester);
    expect(find.text('Etapa 1 de 31'), findsOneWidget);
    expect(await StorageService().loadAnswers(), isEmpty);
    expect(await StorageService().loadTreatmentPreferences(), isNull);
  });

  testWidgets('finished saved plan asks to view it instead of silently restarting',
      (tester) async {
    final questions = await BirthPlanFlowService().loadQuestions();
    await StorageService().saveAnswers(syntheticAnswers(questions));
    setViewport(tester, const Size(800, 1200));
    await tester.pumpWidget(const MaterialApp(home: ChatScreen()));
    await tester.pumpAndSettle();
    await tapChoice(tester, 'Montar meu plano');
    expect(find.text('Encontramos um plano salvo'), findsOneWidget);
    expect(find.text('Ver plano salvo'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await advanceChat(tester);
    expect(await StorageService().loadAnswers(), hasLength(31));
  });

  testWidgets('text input is disabled until the person explicitly chooses to write',
      (tester) async {
    final questions = await BirthPlanFlowService().loadQuestions();
    await reachPriorities(tester);
    expect(questions[5].id, 'prioridade_parto');
    expect(tester.widget<TextField>(find.byType(TextField).first).enabled, isFalse);
    await tapChoice(tester, 'Concluir seleção');
    expect(await StorageService().loadAnswers(), hasLength(5));
    await tapChoice(tester, 'Escrever minha resposta');
    expect(tester.widget<TextField>(find.byType(TextField).first).enabled, isTrue);
    await sendText(tester, 'Minha prioridade escrita sintética');
    final answers = await StorageService().loadAnswers();
    expect(answers.last.questionId, 'prioridade_parto');
    expect(answers.last.values, ['Minha prioridade escrita sintética']);
    // O ListView.builder virtualiza mensagens antigas. Rolar para conferir
    // que a resposta continua presente no histórico, não só no armazenamento.
    await tester.scrollUntilVisible(
      find.text('Minha prioridade escrita sintética'),
      -180,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 30,
    );
    expect(find.text('Minha prioridade escrita sintética'), findsOneWidget);
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
    expect(tester.widget<TextField>(find.byType(TextField).first).enabled, isTrue);
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
