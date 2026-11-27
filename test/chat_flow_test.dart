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
    if ((await StorageService().loadAnswers()).isNotEmpty) {
      // Novas versões só retomam dados locais mediante escolha explícita.
      expect(find.text('Encontramos um plano salvo'), findsOneWidget);
      await tester.tap(find.text('Continuar meu plano'));
      await advanceChat(tester);
    }
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

  testWidgets('DPP formats digits, shows invalid date visibly and sends by button', (tester) async {
    await openChat(tester);
    await sendText(tester, 'Gestante Sintetica');
    await tapChoice(tester, 'Prefiro não informar');
    final field = find.byType(TextField).first;
    expect(tester.widget<TextField>(field).keyboardType, TextInputType.number);
    await tester.enterText(field, '31022026');
    expect(tester.widget<TextField>(field).controller!.text, '31/02/2026');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    expect(find.text('Informe uma data válida no formato DD/MM/AAAA.'), findsOneWidget);
    expect((await StorageService().loadAnswers()), hasLength(1));
    final date = testDpp();
    await tester.enterText(field, date.replaceAll('/', ''));
    expect(tester.widget<TextField>(field).controller!.text, date);
    await tester.tap(find.byIcon(Icons.send));
    await advanceChat(tester);
    final saved = await StorageService().loadAnswers();
    expect(saved.singleWhere((a) => a.questionId == 'dpp').values, [date]);
    expect(find.textContaining('Escolha sua UBS de referência'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DPP sends using keyboard action', (tester) async {
    await openChat(tester);
    await sendText(tester, 'Gestante Sintetica');
    await tapChoice(tester, 'Prefiro não informar');
    final date = testDpp();
    await tester.enterText(find.byType(TextField).first, date.replaceAll('/', ''));
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await advanceChat(tester);
    expect((await StorageService().loadAnswers()).singleWhere((a) => a.questionId == 'dpp').values, [date]);
  });

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
    expect(find.widgetWithText(InkWell, 'Sentir segurança'), findsOneWidget);
    await tapChoice(tester, 'Sentir segurança');
    await tapChoice(tester, 'Concluir seleção');
    expect((await StorageService().loadAnswers()).last.values,
        [questions[5].options.first]);
  });

  testWidgets('finish selection is pink before confirmation, purple while saving, then advances', (tester) async {
    await reachPriorities(tester);
    final finish = find.widgetWithText(InkWell, 'Concluir seleção');
    Color? fill() => (tester.widget<AnimatedContainer>(
      find.descendant(of: finish, matching: find.byType(AnimatedContainer)).first
    ).decoration as BoxDecoration).color;
    await tester.ensureVisible(finish);
    await tester.pumpAndSettle();
    expect(fill(), const Color(0xFFC23880));
    await tapChoice(tester, 'Sentir segurança');
    expect(fill(), const Color(0xFFC23880));
    await tester.ensureVisible(finish);
    await tester.tap(finish);
    await tester.pump();
    expect(fill(), const Color(0xFF9B4DE0));
    await advanceChat(tester);
    expect((await StorageService().loadAnswers()).last.questionId, 'prioridade_parto');
    expect((await StorageService().loadAnswers()).last.values, ['Sentir-me segura']);
    expect(finish, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('multiple choices and typed complement are both preserved',
      (tester) async {
    final questions = await BirthPlanFlowService().loadQuestions();
    await reachPriorities(tester);
    await tapChoice(tester, 'Sentir segurança');
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
    await sendText(tester, testDpp());
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
    // No modo de cards, o campo inutilizado some para liberar altura.
    expect(find.byType(TextField), findsNothing);
    await tapChoice(tester, 'Concluir seleção');
    expect(await StorageService().loadAnswers(), hasLength(5));
    await tapChoice(tester, 'Escrever minha resposta');
    expect(tester.widget<TextField>(find.byType(TextField).first).enabled, isTrue);
    await sendText(tester, 'Minha prioridade escrita sintética');
    final answers = await StorageService().loadAnswers();
    expect(answers.last.questionId, 'prioridade_parto');
    expect(answers.last.values, ['Minha prioridade escrita sintética']);
    // Com a interface em cards, a pergunta anterior sai de cena sem
    // apagar a resposta. Nao exigir a bolha de historico do chat legado.
    expect(find.text('Minha prioridade escrita sintética'), findsNothing);
    expect((await StorageService().loadAnswers()).last.values,
        ['Minha prioridade escrita sintética']);
  });

  testWidgets('explicit masculine treatment applies immediately and canonical values persist', (tester) async {
    final questions = await BirthPlanFlowService().loadQuestions();
    await openChat(tester);
    await sendText(tester, 'Alex Sintetico');
    await tapChoice(tester, 'Ele/dele');
    expect(find.textContaining('se sinta acolhido'), findsOneWidget);
    expect((await StorageService().loadTreatmentPreferences())!.pronouns, 'Ele/dele');
    await sendText(tester, testDpp());
    for (final q in questions.skip(3).take(2)) {
      await tapChoice(tester, q.options.first);
    }
    await tapChoice(tester, 'Sentir-me seguro');
    await tapChoice(tester, 'Concluir seleção');
    expect((await StorageService().loadAnswers()).last.values, ['Sentir-me segura']);
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
