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
    await tapChoice(tester, 'Montar meu plano');
    expect(find.text('Encontramos um plano salvo'), findsOneWidget);
    await tester.tap(find.text('Continuar meu plano'));
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
}
