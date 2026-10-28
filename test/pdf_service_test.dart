import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plano_parto_pet_saude/models/birth_plan_answer.dart';
import 'package:plano_parto_pet_saude/services/birth_plan_flow_service.dart';
import 'package:plano_parto_pet_saude/services/pdf_service.dart';

import 'support/offline_helpers.dart';

// Inspect unencrypted text streams from our generated PDFs, not a general PDF
// reader. This checks saved content and file structure, not visual placement.
String pdfText(Uint8List bytes) {
  final raw = latin1.decode(bytes);
  final text = StringBuffer();
  for (final m
      in RegExp(r'\d+ 0 obj\s*<<((?:(?!endobj)[\s\S])*?)>>\s*stream\r?\n')
          .allMatches(raw)) {
    final length = RegExp(r'/Length\s+(\d+)').firstMatch(m[1]!);
    if (length == null) continue;
    if (RegExp(r'/Subtype\s*/Image|/Type\s*/XRef').hasMatch(m[1]!)) continue;
    var data = bytes.sublist(m.end, m.end + int.parse(length[1]!));
    if (m[1]!.contains('/FlateDecode')) {
      data = Uint8List.fromList(zlib.decode(data));
    }
    final content = latin1.decode(data);
    if (!content.contains('TJ') && !content.contains('Tj')) continue;
    for (final s in RegExp(r'\(((?:\\.|[^\\()])*)\)').allMatches(content)) {
      text.write(s[1]!.replaceAllMapped(RegExp(r'\\([0-7]{1,3}|.)'), (e) {
        final octal = int.tryParse(e[1]!, radix: 8);
        return octal == null ? e[1]! : String.fromCharCode(octal);
      }));
      text.write(' ');
    }
  }
  return text.toString();
}

void expectValidPdf(Uint8List bytes) {
  final raw = latin1.decode(bytes);
  expect(raw, startsWith('%PDF-'));
  expect(raw.trimRight(), endsWith('%%EOF'));
  final start = RegExp(r'startxref\s+(\d+)').firstMatch(raw);
  expect(start, isNotNull);
  final xref = raw.substring(int.parse(start![1]!));
  // PDF 1.5+ uses a cross-reference stream instead of the older xref table.
  expect(
      xref.startsWith('xref') ||
          (RegExp(r'^\d+ 0 obj').hasMatch(xref) &&
              RegExp(r'/Type\s*/XRef').hasMatch(xref.split('stream').first)),
      isTrue);
  expect(RegExp(r'/Type\s*/Page\b').allMatches(raw), isNotEmpty);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(resetOfflineState);

  for (final format in BirthPlanPdfFormat.values) {
    test('$format PDF preserves every one of the 31 recorded answers',
        () async {
      final questions = await BirthPlanFlowService().loadQuestions();
      final bytes = await PdfService().buildBirthPlanPdf(
          questions: questions,
          answers: syntheticAnswers(questions),
          format: format);
      expectValidPdf(bytes);
      final artifacts = await Directory('build/test_artifacts/petita')
          .create(recursive: true);
      await File('${artifacts.path}/${format.name}.pdf').writeAsBytes(bytes);
      final text = pdfText(bytes);
      expect(text, isNotEmpty);
      for (var i = 0; i < 31; i++) {
        expect(text, contains('AUDIT${i.toString().padLeft(2, '0')}'),
            reason: questions[i].id);
      }
      if (format == BirthPlanPdfFormat.declaracao) {
        expect(RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)),
            hasLength(1));
        expect(text, contains('Assinatura da gestante'));
      } else {
        expect(
            RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)).length,
            greaterThan(1));
      }
    });

    test('$format generates a valid empty document without inventing answers',
        () async {
      final questions = await BirthPlanFlowService().loadQuestions();
      final bytes = await PdfService()
          .buildBirthPlanPdf(questions: questions, answers: [], format: format);
      expectValidPdf(bytes);
      expect(pdfText(bytes), isNot(contains('AUDIT')));
    });

    test('$format retains all multiple-choice entries including the last',
        () async {
      final questions = await BirthPlanFlowService().loadQuestions();
      final answers = [
        BirthPlanAnswer(
            questionId: 'alivio_dor',
            values: [for (var i = 0; i < 10; i++) 'ESCOLHA$i']),
        BirthPlanAnswer(
            questionId: 'cesarea',
            values: [for (var i = 0; i < 5; i++) 'CESAREA$i']),
      ];
      final bytes = await PdfService().buildBirthPlanPdf(
          questions: questions, answers: answers, format: format);
      expectValidPdf(bytes);
      final text = pdfText(bytes);
      for (var i = 0; i < 10; i++) {
        expect(text, contains('ESCOLHA$i'));
      }
      for (var i = 0; i < 5; i++) {
        expect(text, contains('CESAREA$i'));
      }
    });

    test(
        '$format exports the bytes and filename through a mocked sharing channel',
        () async {
      const channel = MethodChannel('net.nfet.printing');
      MethodCall? shared;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        shared = call;
        return 1;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));
      await PdfService().shareBirthPlanPdf(
          questions: await BirthPlanFlowService().loadQuestions(),
          answers: [
            BirthPlanAnswer(questionId: 'nome_gestante', values: ['Sintetica'])
          ],
          format: format);
      expect(shared!.method, 'sharePdf');
      expect(
          shared!.arguments['name'],
          format == BirthPlanPdfFormat.declaracao
              ? 'plano_de_parto_declaracao_pet_saude.pdf'
              : 'plano_de_parto_resumo_pet_saude.pdf');
      expectValidPdf(shared!.arguments['doc'] as Uint8List);
    });
  }

  test(
      'declaration reports its size limit instead of exporting clipped long text',
      () async {
    final questions = await BirthPlanFlowService().loadQuestions();
    final longText =
        '${List.filled(1500, 'preferencia sintetica').join(' ')} MARCADORFINAL';
    await expectLater(
        PdfService().buildBirthPlanPdf(questions: questions, answers: [
          BirthPlanAnswer(questionId: 'observacoes_finais', values: [longText])
        ]),
        throwsA(isA<BirthPlanPdfTooLongException>()
            .having((e) => e.message, 'message',
                contains('Suas respostas continuam salvas.'))
            .having((e) => e.message, 'alternative',
                contains('Resumo visual e registro completo'))));
  });

  test(
      'complete report paginates free text longer than one A4 without losing its end',
      () async {
    final bytes = await PdfService().buildBirthPlanPdf(
      questions: await BirthPlanFlowService().loadQuestions(),
      answers: [
        BirthPlanAnswer(questionId: 'observacoes_finais', values: [
          '${List.filled(1500, 'relato sintetico extenso').join(' ')} ULTIMA-LINHA-SINTETICA'
        ])
      ],
      format: BirthPlanPdfFormat.resumoVisual,
    );
    expectValidPdf(bytes);
    expect(RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)).length,
        greaterThan(2));
    expect(pdfText(bytes), contains('ULTIMA-LINHA-SINTETICA'));
  });
}
