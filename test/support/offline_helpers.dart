import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plano_parto_pet_saude/models/birth_plan_answer.dart';
import 'package:plano_parto_pet_saude/models/birth_plan_question.dart';
import 'package:shared_preferences/shared_preferences.dart';

void resetOfflineState() {
  SharedPreferences.setMockInitialValues({});
  // Do not reuse asset Futures created in the previous test's fake async zone.
  rootBundle.clear();
}

// Tests mount widgets directly, never main() or a Supabase client.
void setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> tapChoice(WidgetTester tester, String label) async {
  final target = find.widgetWithText(InkWell, label).last;
  await tester.scrollUntilVisible(target, 250,
      scrollable: find.byType(Scrollable).first, maxScrolls: 60);
  await tester.tap(target);
  await advanceChat(tester);
}

Future<void> advanceChat(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
}

Future<void> sendText(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).first, text);
  await tester.tap(find.byIcon(Icons.send));
  await advanceChat(tester);
}

List<BirthPlanAnswer> syntheticAnswers(List<BirthPlanQuestion> questions) => [
      for (var i = 0; i < questions.length; i++)
        BirthPlanAnswer(
            questionId: questions[i].id,
            values: ['AUDIT${i.toString().padLeft(2, '0')}']),
    ];
