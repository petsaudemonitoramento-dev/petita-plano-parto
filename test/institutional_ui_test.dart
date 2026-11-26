import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plano_parto_pet_saude/screens/institutional/account_screen.dart';
import 'package:plano_parto_pet_saude/screens/institutional/area_screen.dart';
import 'package:plano_parto_pet_saude/services/neon_api_client.dart';
import 'package:plano_parto_pet_saude/services/institutional/institutional_auth.dart';
import 'package:plano_parto_pet_saude/services/institutional/plan_sync_controller.dart';
import 'package:plano_parto_pet_saude/services/institutional/runtime.dart';
import 'support/institutional_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  InstitutionalRuntime runtime(String role, List<String> requests) {
    final auth = InstitutionalAuth(FixtureAuthTransport());
    final vault = MemoryVault();
    final api = NeonApiClient(
        origin: Uri.parse('https://fixture.invalid'),
        client: MockClient((r) async {
          requests.add('${r.method} ${r.url.path}');
          final rows = switch (r.url.path) {
            '/api/me' => [
                {
                  'id': '00000000-0000-4000-8000-000000000001',
                  'role': role,
                  'ubs_code': null
                }
              ],
            '/api/profile' => [
                {'id': '00000000-0000-4000-8000-000000000001'}
              ],
            _ => []
          };
          return http.Response(jsonEncode({'data': rows}), 200,
              headers: {'content-type': 'application/json'});
        }),
        tokenProvider: auth.token);
    return InstitutionalRuntime(
        auth, api, PlanSyncController(api: api, auth: auth, vault: vault));
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
      'online consent starts entirely unchecked and cannot POST implicit acceptance',
      (tester) async {
    tester.view.physicalSize = const Size(900, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final calls = <String>[];
    final r = runtime('patient', calls);
    await tester
        .pumpWidget(MaterialApp(home: InstitutionalAccountScreen(runtime: r)));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    });
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(LinearProgressIndicator), findsNothing,
        reason: 'Requests observed: $calls');
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 3));
    final choices = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .toList();
    expect(choices, hasLength(6));
    expect(choices.every((c) => c.value == false), true);
    await tester.tap(find.text('Registrar consentimento online'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    });
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(LinearProgressIndicator), findsNothing,
        reason: 'Requests observed: $calls');
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 3));
    expect(calls.contains('POST /api/consent'), false);
    expect(find.text('Consentimento online registrado.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'patient can request professional access but never sees admin approvals and no admin endpoint is called',
      (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: InstitutionalAreaScreen(runtime: runtime('patient', calls))));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    });
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(LinearProgressIndicator), findsNothing,
        reason: 'Requests observed: $calls');
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 3));
    expect(find.text('Solicitar acesso profissional'), findsOneWidget);
    expect(find.text('Aprovar profissional'), findsNothing);
    expect(calls.any((c) => c.contains('/api/admin/')), false);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'unconfigured account gives offline availability message without simulated auth',
      (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: InstitutionalAccountScreen()));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    });
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 3));
    expect(
        find.textContaining('conexão institucional ainda não está disponível'),
        findsOneWidget);
    expect(find.text('Entrar'), findsNothing);
  });
}
