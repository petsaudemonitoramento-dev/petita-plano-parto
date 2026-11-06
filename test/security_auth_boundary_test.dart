// Client-boundary evidence only. Mock HTTP does not prove server-side RLS.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plano_parto_pet_saude/models/user_profile.dart';
import 'package:plano_parto_pet_saude/screens/admin/admin_screen.dart';
import 'package:plano_parto_pet_saude/screens/ubs/ubs_team_screen.dart';
import 'package:plano_parto_pet_saude/services/faq_search_service.dart';
import 'package:plano_parto_pet_saude/services/storage_service.dart';
import 'package:plano_parto_pet_saude/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Future<http.Response> Function(http.Request) respond;
  final requests = <http.Request>[];

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://fixture.invalid', publishableKey: 'fixture-public',
      httpClient: MockClient((request) {
        requests.add(request);
        return respond(request); // Every request terminates in-memory.
      }),
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false, detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    requests.clear();
    rootBundle.clear(); // Avoid asset Futures from a previous widget fake-async zone.
    respond = (request) async => http.Response('{"message":"fixture denied"}', 403, request: request);
  });

  for (final role in ['admin', 'ubs_team']) {
    testWidgets('forged local $role never unlocks privileged area without session', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await StorageService().saveProfile(UserProfile(
        id: 'fixture-forged', name: 'SYNTHETIC', email: 'fixture@example.invalid',
        role: role, ubsCode: 'FIXTURE-A', createdAt: DateTime.utc(2026),
      ));
      await tester.pumpWidget(MaterialApp(home: role == 'admin'
          ? const AdminScreen() : const UbsTeamScreen()));
      await tester.pumpAndSettle(const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
      expect(find.text(role == 'admin' ? 'Entrar como administrador'
          : 'Entrar ou solicitar acesso da Equipe UBS'), findsOneWidget);
      expect(find.textContaining('Administrador conectado.'), findsNothing);
      expect(requests, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink()); // dispose admin polling timer
    });
  }

  test('own question history requires session before making HTTP request', () async {
    await expectLater(SupabaseService().listMyQuestions(), throwsException);
    expect(requests, isEmpty);
  });

  test('[boundary] UBS queue relies on server isolation; fake mixed rows are not filtered', () async {
    respond = (request) async => http.Response(jsonEncode([
      for (final code in ['FIXTURE-A', 'FIXTURE-B']) {
        'id': 'fixture-$code', 'ubs_code': code, 'question_text': 'SYNTHETIC',
        'status': 'pending', 'created_at': '2026-01-01T00:00:00Z',
      },
    ]), 200, headers: {'content-type': 'application/json'}, request: request);
    final rows = await SupabaseService().listTeamQuestions();
    expect(rows.map((row) => row.ubsCode), ['FIXTURE-A', 'FIXTURE-B']);
    final query = requests.single.url;
    expect(query.path, '/rest/v1/team_questions_anonymous');
    expect(query.queryParameters['select'], '*');
    expect(query.queryParameters.containsKey('ubs_code'), isFalse);
    // This is intentionally a malicious/misconfigured fake server, not a finding of live leakage.
  });

  test('[finding] bundled FAQ answer waits for stalled curated HTTP', () async {
    final stalled = Completer<http.Response>();
    respond = (_) => stalled.future;
    final service = FaqSearchService();
    final items = await service.loadFaq();
    final result = service.search(items.first.question);
    try {
      await expectLater(result.timeout(const Duration(milliseconds: 80)),
          throwsA(isA<TimeoutException>()));
      expect(requests.single.url.path, '/rest/v1/knowledge_base');
    } finally {
      stalled.complete(http.Response('[]', 200, request: requests.single));
    }
    expect(await result, isNotNull);
  });
}
