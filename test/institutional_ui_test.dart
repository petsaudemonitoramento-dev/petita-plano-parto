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
import 'package:plano_parto_pet_saude/services/storage_service.dart';
import 'package:plano_parto_pet_saude/models/user_profile.dart';

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
            '/api/ubs' => [{'code':'FIXTURE-A','name':'UBS fictícia'}],
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

  Future<void> finishAction(WidgetTester tester, List<String> calls) async {
    // Let each in-memory request complete and paint the state it scheduled.
    // Stay below the client's timeout so a transport failure cannot look idle.
    final progress = find.byType(LinearProgressIndicator);
    for (var frame = 0; frame < 120; frame++) {
      // Stream completion may cross the real event queue between API calls.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 16));
      if (progress.evaluate().isEmpty) return;
    }
    fail('A tela continua carregando. Requisições observadas: $calls');
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
    await finishAction(tester, calls);
    final choices = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .toList();
    expect(choices, hasLength(6));
    expect(choices.every((c) => c.value == false), true);
    expect(calls, contains('GET /api/consent'));
    expect(calls, isNot(contains('POST /api/consent')));
    final primary = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Autorizar e sincronizar'));
    expect(primary.onPressed, isNull);
    expect(calls.contains('POST /api/consent'), false);
    expect(find.text('Desativar sincronização'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'patient can request professional access but never sees admin approvals and no admin endpoint is called',
      (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: InstitutionalAreaScreen(runtime: runtime('patient', calls))));
    await finishAction(tester, calls);
    expect(find.text('Solicitar acesso profissional'), findsOneWidget);
    expect(calls, contains('GET /api/ubs'));
    expect(find.text('Solicitações profissionais pendentes'), findsNothing);
    expect(find.text('Aprovar profissional'), findsNothing);
    expect(calls.any((c) => c.contains('/api/admin/')), false);
    expect(tester.takeException(), isNull);
  });
  testWidgets('login keeps recovery and registration fields separate', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await StorageService().saveProfile(UserProfile(id: 'LOCAL-fixture', name: 'Gestante fictícia', email: 'local@example.invalid', role: 'patient', ubsCode: 'FIXTURE-A', createdAt: DateTime.utc(2026)));
    final r = runtime('patient', []);
    await r.auth.logout();
    await tester.pumpWidget(MaterialApp(home: InstitutionalAccountScreen(runtime: r)));
    await tester.pumpAndSettle();
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Nome da gestante'), findsNothing);
    expect(find.text('Código recebido por e-mail'), findsNothing);
    await tester.tap(find.text('Criar conta'));
    await tester.pumpAndSettle();
    expect(find.text('Nome da gestante'), findsOneWidget);
    expect(find.text('Gestante fictícia'), findsOneWidget);
    expect(find.text('local@example.invalid'), findsOneWidget);
    expect(find.text('Criar minha conta'), findsOneWidget);
    expect(find.text('Já tenho uma conta'), findsOneWidget);
    expect(find.text('Código recebido por e-mail'), findsNothing);
  });
  testWidgets('patient account does not show professional verification or access button', (tester) async {
    tester.view.physicalSize = const Size(900, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final calls = <String>[];
    await tester.pumpWidget(MaterialApp(home: InstitutionalAccountScreen(runtime: runtime('patient', calls))));
    await finishAction(tester, calls);
    expect(find.text('Verificação para acesso profissional'), findsNothing);
    expect(find.text('Área profissional e administrativa'), findsNothing);
    expect(find.text('Sincronização online opcional'), findsOneWidget);
  });
  testWidgets('unregistered UBS is optional and never sends a fake request', (tester) async {
    tester.view.physicalSize = const Size(900, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final calls = <String>[];
    final r = runtime('patient', calls);
    await tester.pumpWidget(MaterialApp(home: InstitutionalAccountScreen(runtime: r)));
    await finishAction(tester, calls);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Minha UBS não está cadastrada').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Você pode salvar e sincronizar seu plano online normalmente.'), findsOneWidget);
    expect(find.text('Solicitar vínculo à UBS'), findsNothing);
    expect(find.text('Autorizar e sincronizar'), findsOneWidget);
    expect(calls, isNot(contains('POST /api/patient/ubs-requests')));
    expect(tester.takeException(), isNull);
  });
  testWidgets('professional account does not expose patient synchronization', (tester) async {
    tester.view.physicalSize = const Size(900, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final calls = <String>[];
    await tester.pumpWidget(MaterialApp(home: InstitutionalAccountScreen(professional: true, runtime: runtime('patient', calls))));
    await finishAction(tester, calls);
    expect(find.text('Acesso profissional'), findsOneWidget);
    expect(find.text('Verificação para acesso profissional'), findsOneWidget);
    expect(find.text('Sincronização online opcional'), findsNothing);
  });
  testWidgets(
      'unconfigured account gives offline availability message without simulated auth',
      (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: InstitutionalAccountScreen()));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('conexão institucional ainda não está disponível'),
        findsOneWidget);
    expect(find.text('Entrar'), findsNothing);
  });
}
