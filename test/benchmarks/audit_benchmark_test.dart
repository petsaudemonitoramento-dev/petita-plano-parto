// Synthetic Cloud measurements; not device/startup benchmarks.
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plano_parto_pet_saude/services/faq_search_service.dart';
import 'package:plano_parto_pet_saude/services/birth_plan_flow_service.dart';
import 'package:plano_parto_pet_saude/services/pdf_service.dart';
import 'package:plano_parto_pet_saude/models/birth_plan_answer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

num median(Iterable<int> values) {
  final sorted = values.toList()..sort();
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('FAQ benchmark with identical synthetic 900ms network latency', () async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://fixture.invalid', publishableKey: 'fixture-public',
      httpClient: MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 900));
        return http.Response('[]', 200, request: request);
      }),
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false,
        detectSessionInUri: false, localStorage: EmptyLocalStorage()),
    );
    final samples = <int>[];
    for (var i = 0; i < 5; i++) {
      final service = FaqSearchService();
      final items = await service.loadFaq();
      final watch = Stopwatch()..start();
      expect(await service.search(items.first.question), isNotNull);
      samples.add(watch.elapsedMilliseconds);
    }
    print('AUDIT_METRIC ${jsonEncode({'name':'faq_900ms','samples_ms':samples,'median_ms':median(samples)})}');
    await Future<void>.delayed(const Duration(milliseconds: 950));
    await Supabase.instance.dispose();
  });

  test('PDF cold and warm resource cache benchmark with 31 synthetic answers', () async {
    final questions = await BirthPlanFlowService().loadQuestions();
    final answers = [for (final q in questions)
      BirthPlanAnswer(questionId: q.id, values: ['SINTÉTICO: informação de teste'])];
    final samples = <int>[];
    final sizes = <int>[];
    for (var i = 0; i < 5; i++) {
      final watch = Stopwatch()..start();
      final bytes = await PdfService().buildBirthPlanPdf(questions: questions,
        answers: answers, format: BirthPlanPdfFormat.resumoVisual);
      samples.add(watch.elapsedMilliseconds);
      sizes.add(bytes.length);
      expect(bytes.take(5), '%PDF-'.codeUnits);
    }
    print('AUDIT_METRIC ${jsonEncode({'name':'pdf_31','samples_ms':samples,'bytes':sizes,'cold_ms':samples.first,'warm_median_ms':median(samples.skip(1))})}');
  });
}
