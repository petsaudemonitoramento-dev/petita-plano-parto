import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plano_parto_pet_saude/main.dart' as app;
import 'package:plano_parto_pet_saude/config/build_mode.dart';
import 'package:plano_parto_pet_saude/services/birth_plan_flow_service.dart';
import 'package:plano_parto_pet_saude/services/storage_service.dart';
import 'package:plano_parto_pet_saude/services/supabase_service.dart';
import 'package:plano_parto_pet_saude/services/pdf_service.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'offline native startup, consent, 31 answers, persistence and PDFs',
      (tester) async {
    expect(BuildMode.internalTest, isTrue,
        reason: 'Never exercise production services from the emulator.');
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await app.main();
    await tester.pump(const Duration(seconds: 2));
    expect(SupabaseService().isLoggedIn, isFalse);
    expect(find.text('Olá, eu sou a Petita!'), findsOneWidget);

    await binding.convertFlutterSurfaceToImage();
    await tester.pump(const Duration(milliseconds: 300));
    await binding.takeScreenshot('offline-home-synthetic');
    final start = find.text('Criar meu plano de parto');
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      final box = find.byType(Checkbox).at(i);
      await tester.ensureVisible(box);
      await tester.tap(box);
      await tester.pump();
    }
    await tester.ensureVisible(find.text('Concordar e começar'));
    await tester.tap(find.text('Concordar e começar'));
    await tester.pumpAndSettle();
    expect(await StorageService().hasConsent(), isTrue);

    Future<void> settleChat() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
    }

    Future<void> choose(String value) async {
      final target = find.widgetWithText(InkWell, value).last;
      await tester.scrollUntilVisible(target, 250,
          scrollable: find.byType(Scrollable).first, maxScrolls: 80);
      await tester.tap(target);
      await settleChat();
    }

    Future<void> write(String value) async {
      await tester.enterText(find.byType(TextField).first, value);
      await tester.tap(find.byIcon(Icons.send));
      await settleChat();
    }

    final questions = await BirthPlanFlowService().loadQuestions();
    expect(questions.length, 31);
    await choose('Montar meu plano');
    final due = DateTime.now().add(const Duration(days: 21));
    final dpp =
        '${due.day.toString().padLeft(2, '0')}/${due.month.toString().padLeft(2, '0')}/${due.year}';
    for (final q in questions) {
      if (q.id == 'semanas_gestacao') continue;
      if (q.id == 'nome_gestante') {
        await write('Pessoa Sintetica Android');
        await choose('Ela/dela');
      } else if (q.id == 'dpp') {
        await write(dpp);
      } else if (q.id == 'preferencias_culturais') {
        await choose('Sim, vou descrever');
        await write('Preferencia sintetica de teste');
      } else if (q.id == 'observacoes_finais') {
        await write('Observacao sintetica de teste');
      } else if (q.multiple) {
        await choose(q.options.first);
        await choose(q.options[1]);
        await choose('Concluir seleção');
      } else {
        await choose(q.options.first);
      }
    }
    await prefs.reload();
    final storage = StorageService();
    final answers = await storage.loadAnswers();
    expect(answers.length, 31);
    expect(
        answers
            .singleWhere((a) => a.questionId == 'semanas_gestacao')
            .values
            .first,
        contains('estimativa em'));
    final treatment = await storage.loadTreatmentPreferences();
    expect(treatment!.pronouns, 'Ela/dela');
    expect(treatment.includeInPdf, isFalse);
    for (final format in BirthPlanPdfFormat.values) {
      final bytes = await PdfService().buildBirthPlanPdf(
          questions: questions,
          answers: answers,
          format: format,
          treatment: treatment);
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      expect(bytes.length, greaterThan(1000));
    }
    expect(
        find.textContaining('Seu Plano de Parto está pronto'), findsOneWidget);
    await binding.takeScreenshot('offline-plan-complete-synthetic');
    // Native FileProvider/chooser invocation; no destination/network selected.
    await PdfService()
        .shareBirthPlanPdf(questions: questions, answers: answers);
    expect(await StorageService().loadAnswers(), hasLength(31));
    // Record only aggregate test evidence, never answers or identity payloads.
    binding.reportData = {
      'canonicalAnswers': 31,
      'pdfFormats': 2,
      'backendInitialized': false,
      'syntheticOnly': true
    };
    await rootBundle.load('assets/data/birth_plan_flow.json');
  }, timeout: const Timeout(Duration(minutes: 8)));
}
