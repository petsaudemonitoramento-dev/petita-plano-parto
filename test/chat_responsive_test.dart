import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plano_parto_pet_saude/screens/chat/chat_screen.dart';
import 'package:plano_parto_pet_saude/services/birth_plan_flow_service.dart';
import 'package:plano_parto_pet_saude/services/storage_service.dart';

import 'support/offline_helpers.dart';

void main() {
  setUp(resetOfflineState);

  Future<void> openQuestion(
      WidgetTester tester, Size viewport, double scale) async {
    setViewport(tester, viewport);
    final questions = await BirthPlanFlowService().loadQuestions();
    await StorageService().saveAnswers(
        syntheticAnswers(questions.take(4).toList()));
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
        ),
        child: const ChatScreen(),
      )),
    ));
    await tester.pumpAndSettle();
    // Centralizar a escolha no viewport. O helper do fluxo tradicional
    // pode ultrapassar o item ao rolar 250 px em telas muito baixas.
    final start = find.widgetWithText(InkWell, 'Montar meu plano').last;
    await Scrollable.ensureVisible(
      tester.element(start),
      alignment: 0.5,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
    await tester.tap(start);
    await advanceChat(tester);
    expect(find.text('Encontramos um plano salvo'), findsOneWidget);
    final resume = find.text('Continuar meu plano');
    await tester.ensureVisible(resume);
    await tester.pumpAndSettle();
    await tester.tap(resume);
    await advanceChat(tester);
    expect(find.byKey(const Key('petita_cards_scroll')), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  }

  for (final scenario in <({String name, Size viewport, double scale})>[
    (name: '320x568 fonte 1,3', viewport: Size(320, 568), scale: 1.3),
    (name: '360x640 fonte normal', viewport: Size(360, 640), scale: 1.0),
    (name: '393x852 fonte 1,6', viewport: Size(393, 852), scale: 1.6),
    (name: '412x915 fonte normal', viewport: Size(412, 915), scale: 1.0),
    (name: '600x960 tela ampla', viewport: Size(600, 960), scale: 1.0),
    (name: '640x360 horizontal', viewport: Size(640, 360), scale: 1.0),
  ]) {
    testWidgets('cards adaptam ${scenario.name} sem overflow',
        (tester) async {
      await openQuestion(tester, scenario.viewport, scenario.scale);
      final scroll = find.byKey(const Key('petita_cards_scroll'));
      final rect = tester.getRect(scroll);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(scenario.viewport.width + 1));
      expect(rect.height, greaterThan(1));

      // Em telas pequenas, a ultima acao continua acessivel por rolagem.
      final deferButton = find.text(
          'Conversar sobre isto na próxima consulta');
      expect(deferButton, findsOneWidget);
      await tester.ensureVisible(deferButton);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('digitação aparece quando selecionada, sem perder o card',
      (tester) async {
    await openQuestion(tester, const Size(320, 568), 1.4);
    await tapChoice(tester, 'Escrever minha resposta');
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byKey(const Key('petita_cards_scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('novo card volta automaticamente ao topo depois de rolar',
      (tester) async {
    await openQuestion(tester, const Size(320, 568), 1.1);
    final questions = await BirthPlanFlowService().loadQuestions();
    final card = find.byKey(const Key('petita_cards_scroll'));
    final scrollController =
        tester.widget<SingleChildScrollView>(card).controller!;
    final defer = find.text('Conversar sobre isto na próxima consulta');
    await tester.ensureVisible(defer);
    await tester.pumpAndSettle();
    expect(scrollController.offset, greaterThan(0));

    await tester.tap(defer);
    await advanceChat(tester);

    expect(find.text(questions[5].question), findsOneWidget);
    expect(scrollController.offset, closeTo(0, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('opcao de escrita muda de cor, exibe confirmacao e foca campo',
      (tester) async {
    await openQuestion(tester, const Size(393, 852), 1.0);
    final option = find.text('Escrever minha resposta');
    await tester.ensureVisible(option);
    await tester.tap(option);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('petita_writing_confirmation')),
        findsOneWidget);
    expect(find.textContaining('Modo escrita ativado'), findsOneWidget);
    final pill = tester.widget<AnimatedContainer>(
      find.ancestor(of: option, matching: find.byType(AnimatedContainer)).first,
    );
    expect((pill.decoration! as BoxDecoration).color,
        const Color(0xFF9B4DE0));
    expect(tester.widget<TextField>(find.byType(TextField).first)
        .focusNode!.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

}
