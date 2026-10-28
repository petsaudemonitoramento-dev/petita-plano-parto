import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plano_parto_pet_saude/models/birth_plan_answer.dart';
import 'package:plano_parto_pet_saude/services/birth_plan_flow_service.dart';
import 'package:plano_parto_pet_saude/services/pdf_service.dart';
import 'package:plano_parto_pet_saude/services/storage_service.dart';
import 'package:plano_parto_pet_saude/screens/birth_plan/birth_plan_summary_screen.dart';

import 'support/offline_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(resetOfflineState);

  test(
      'synthetic presentation fixtures generate both formats and an extended report',
      () async {
    final questions = await BirthPlanFlowService().loadQuestions();
    final overrides = <String, List<String>>{
      'nome_gestante': ["Lívia Conceição D'Ávila (TESTE SINTÉTICO)"],
      'dpp': ['01/12/2026'],
      'ubs_referencia': ['UBS Sintética São José'],
      'acompanhante_principal': ['João — acompanhante sintético'],
      'preferencias_culturais': ['Acolhimento, oração e comunicação clara.'],
      'observacoes_finais': [
        'Exemplo fictício: atenção, autonomia e informação. Acentos: á, é, í, ó, ú, ã, õ, ç. Pontuação: “aspas”, nº 1, 50% & (teste).'
      ],
    };
    final answers = [
      for (final q in questions)
        BirthPlanAnswer(
            questionId: q.id,
            values:
                overrides[q.id] ?? q.options.take(q.multiple ? 2 : 1).toList()),
    ];
    final dir = await Directory('build/test_artifacts/pr5_visual')
        .create(recursive: true);
    await File('${dir.path}/respostas-sinteticas.json').writeAsString(
        const JsonEncoder.withIndent('  ')
            .convert(answers.map((a) => a.toJson()).toList()));
    for (final format in BirthPlanPdfFormat.values) {
      final bytes = await PdfService().buildBirthPlanPdf(
          questions: questions, answers: answers, format: format);
      await File('${dir.path}/${format.name}.pdf').writeAsBytes(bytes);
      final pages =
          RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)).length;
      expect(
          pages, format == BirthPlanPdfFormat.declaracao ? 1 : greaterThan(1));
    }
    final extended = [
      for (final a in answers)
        a.questionId == 'observacoes_finais'
            ? BirthPlanAnswer(questionId: a.questionId, values: [
                '${List.filled(80, 'Este é um relato inteiramente sintético para conferir a leitura, os acentos e a continuidade de uma resposta longa.').join(' ')} FIM-DO-RELATO-SINTÉTICO.'
              ])
            : questions.singleWhere((q) => q.id == a.questionId).multiple
                ? BirthPlanAnswer(
                    questionId: a.questionId,
                    values: questions
                        .singleWhere((q) => q.id == a.questionId)
                        .options)
                : a,
    ];
    await File('${dir.path}/respostas-sinteticas-longas.json').writeAsString(
        const JsonEncoder.withIndent('  ')
            .convert(extended.map((a) => a.toJson()).toList()));
    final report = await PdfService().buildBirthPlanPdf(
        questions: questions,
        answers: extended,
        format: BirthPlanPdfFormat.resumoVisual);
    await File('${dir.path}/resumoVisual-longo.pdf').writeAsBytes(report);
    await expectLater(
        PdfService().buildBirthPlanPdf(questions: questions, answers: extended),
        throwsA(isA<StateError>()));
  });

  testWidgets(
      'complete report label stays readable on a narrow populated summary',
      (tester) async {
    setViewport(tester, const Size(320, 640));
    await StorageService().saveAnswers([
      BirthPlanAnswer(questionId: 'nome_gestante', values: ['Lívia Sintética']),
    ]);
    await tester.pumpWidget(const MaterialApp(home: BirthPlanSummaryScreen()));
    await tester.pumpAndSettle();
    final button = find.text('Gerar PDF — resumo visual e registro completo');
    expect(button, findsOneWidget);
    expect(find.textContaining('modelo antigo'), findsNothing);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
