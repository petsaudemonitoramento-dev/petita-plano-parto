import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plano_parto_pet_saude/models/birth_plan_answer.dart';
import 'package:plano_parto_pet_saude/services/storage_service.dart';
import 'package:plano_parto_pet_saude/services/neon_api_client.dart';
import 'package:plano_parto_pet_saude/services/institutional/institutional_auth.dart';
import 'package:plano_parto_pet_saude/services/institutional/plan_sync_controller.dart';
import 'support/institutional_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryVault vault;
  late InstitutionalAuth auth;
  late FixtureAuthTransport transport;
  late PlanSyncController sync;
  final answers = [
    BirthPlanAnswer(questionId: 'nome_gestante', values: ['SYNTHETIC'])
  ];
  const choices = {
    'terms': true,
    'privacy': true,
    'responsibility': true,
    'planScience': true,
    'healthData': true,
    'onlineSync': true
  };
  http.Response response(http.Request r, List<Object?> data,
          [int status = 200]) =>
      http.Response(jsonEncode({'data': data}), status,
          headers: {'content-type': 'application/json'}, request: r);
  final grant = [
    {'action': 'grant', 'terms_version': PlanSyncController.termsVersion}
  ];
  void setupClient(Future<http.Response> Function(http.Request) handler) {
    final api = NeonApiClient(
        origin: Uri.parse('https://fixture.invalid'),
        client: MockClient(handler),
        tokenProvider: auth.token);
    sync = PlanSyncController(api: api, auth: auth, vault: vault);
  }

  Map<String, dynamic> state() =>
      jsonDecode(vault.values['petita.sync.v1:fixture-a']!)
          as Map<String, dynamic>;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    vault = MemoryVault();
    transport = FixtureAuthTransport();
    auth = InstitutionalAuth(transport);
    await auth.restore();
  });
  test(
      'every consent flag must be explicit; failed persistence never sends HTTP',
      () async {
    var calls = 0;
    setupClient((r) async {
      calls++;
      return response(r, grant);
    });
    await expectLater(sync.grantConsent({...choices, 'onlineSync': false}),
        throwsA(isA<NeonApiException>()));
    expect(calls, 0);
    vault.failWrites = true;
    await expectLater(sync.grantConsent(choices), throwsStateError);
    expect(calls, 0);
  });
  test(
      'offline retry preserves operation ID and payload, ACK is durable, unchanged plan does not increment revision',
      () async {
    var posts = 0;
    final sent = <Map<String, dynamic>>[];
    var fail = true;
    setupClient((r) async {
      if (r.url.path == '/api/consent') return response(r, grant);
      posts++;
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      sent.add(body);
      return fail
          ? response(r, [], 503)
          : response(r, [
              {'id': body['id'], 'revision': 1}
            ]);
    });
    await expectLater(
        sync.synchronize(answers), throwsA(isA<NeonApiException>()));
    expect(state()['pending'], isNotNull);
    expect(sync.pending, true);
    final before = sent.single;
    fail = false;
    await sync.retryPending();
    expect(sent.last, before);
    expect(state()['revision'], 1);
    expect(state()['pending'], isNull);
    await sync.synchronize(answers);
    expect(posts, 2);
  });
  test(
      'lost ACK with exact next revision reconciles once; changed remote yields conflict and preserves both copies',
      () async {
    Map<String, dynamic>? sent;
    var conflict = false;
    setupClient((r) async {
      if (r.url.path == '/api/consent') return response(r, grant);
      if (r.method == 'POST') {
        sent = jsonDecode(r.body) as Map<String, dynamic>;
        return response(r, [], 409);
      }
      return response(r, [
        {
          'id': sent!['id'],
          'revision': sent!['expected_revision'] + 1,
          'answers_json': conflict
              ? {
                  'nome_gestante': ['OTHER-SYNTHETIC']
                }
              : sent!['answers'],
          'patient_name': sent!['patient_name'],
          'companion': sent!['companion'],
          'dpp': sent!['dpp']
        }
      ]);
    });
    await sync.synchronize(answers);
    expect(state()['revision'], 1);
    expect(sync.pending, false);
    conflict = true;
    final changed = [
      BirthPlanAnswer(questionId: 'nome_gestante', values: ['NEW-SYNTHETIC'])
    ];
    await StorageService().saveAnswers(changed);
    await expectLater(sync.synchronize(changed), throwsA(isA<PlanConflict>()));
    expect(state()['pending'], isNotNull);
    expect((await StorageService().loadAnswers()).single.values,
        ['NEW-SYNTHETIC']);
  });
  test(
      'offline withdrawal drops queue and blocks all uploads until withdrawal is confirmed',
      () async {
    var online = false;
    var uploads = 0;
    var withdrawn = false;
    setupClient((r) async {
      if (r.url.path.endsWith('/withdraw')) {
        if (!online) return response(r, [], 503);
        withdrawn = true;
        return response(r, [{}]);
      }
      if (r.url.path == '/api/consent')
        return response(
            r,
            withdrawn
                ? [
                    {
                      'action': 'withdraw',
                      'terms_version': PlanSyncController.termsVersion
                    }
                  ]
                : grant);
      uploads++;
      return response(r, [], 503);
    });
    await expectLater(
        sync.synchronize(answers), throwsA(isA<NeonApiException>()));
    await expectLater(sync.withdrawConsent(), throwsA(isA<NeonApiException>()));
    expect(sync.consentActive, false);
    expect(state()['pending'], isNull);
    expect(state()['withdrawOperation'], isNotNull);
    await expectLater(
        sync.synchronize(answers), throwsA(isA<NeonApiException>()));
    expect(uploads, 1);
    online = true;
    await sync.retryPending();
    expect(withdrawn, true);
    expect(state()['withdrawOperation'], isNull);
    expect(sync.consentActive, false);
  });
  test(
      'account switching cannot upload or restore a previously bound local workspace',
      () async {
    vault.values['petita.local-plan.owner'] = 'other-fixture';
    var calls = 0;
    setupClient((r) async {
      calls++;
      return response(r, []);
    });
    await expectLater(sync.synchronize(answers), throwsA(isA<PlanConflict>()));
    expect(calls, 0);
  });
  test(
      'subject switch while request is in flight never acknowledges previous account state',
      () async {
    setupClient((r) async {
      if (r.url.path == '/api/consent') return response(r, grant);
      final body = jsonDecode(r.body) as Map;
      transport.subject = 'fixture-b';
      await auth.restore();
      return response(r, [
        {'id': body['id'], 'revision': 1}
      ]);
    });
    await expectLater(
        sync.synchronize(answers), throwsA(isA<NeonApiException>()));
    expect(state()['pending'], isNotNull);
    expect(vault.values.containsKey('petita.sync.v1:fixture-b'), false);
  });
  test(
      'restore needs confirmation, validates owned result and creates protected backup before replacement',
      () async {
    const id = '00000000-0000-4000-8000-000000000001';
    setupClient((r) async => response(r, [
          {
            'id': id,
            'revision': 2,
            'answers_json': {
              'nome_gestante': ['REMOTE-SYNTHETIC']
            }
          }
        ]));
    await StorageService().saveAnswers(answers);
    await expectLater(sync.restorePlan(id, confirmedReplace: false),
        throwsA(isA<NeonApiException>()));
    expect((await StorageService().loadAnswers()).single.values, ['SYNTHETIC']);
    await sync.restorePlan(id, confirmedReplace: true);
    expect((await StorageService().loadAnswers()).single.values,
        ['REMOTE-SYNTHETIC']);
    expect(vault.values['petita.local-plan.backup:fixture-a'],
        contains('SYNTHETIC'));
    expect(state()['revision'], 2);
    await expectLater(
        sync.restorePlan('00000000-0000-4000-8000-000000000002',
            confirmedReplace: true),
        throwsA(isA<NeonApiException>()));
  });
  test(
      'restore rejects unknown clinical keys without overwriting local answers',
      () async {
    setupClient((r) async => response(r, [
          {
            'id': 'fixture',
            'revision': 2,
            'answers_json': {
              'not_an_institutional_question': ['SYNTHETIC']
            }
          }
        ]));
    await StorageService().saveAnswers(answers);
    await expectLater(sync.restorePlan('fixture', confirmedReplace: true),
        throwsA(isA<NeonApiException>()));
    expect((await StorageService().loadAnswers()).single.values, ['SYNTHETIC']);
  });
  test(
      'explicit local erasure cancels retry payload and backup, retaining a withdrawal tombstone without clinical data',
      () async {
    setupClient((r) async => r.url.path == '/api/consent'
        ? response(r, grant)
        : response(r, [], 503));
    await expectLater(
        sync.synchronize(answers), throwsA(isA<NeonApiException>()));
    vault.values['petita.local-plan.backup:fixture-a'] = 'OLD-SYNTHETIC';
    await sync.prepareLocalClear(true);
    expect(state()['pending'], isNull);
    expect(state()['lastPayload'], isNull);
    expect(state()['withdrawOperation'], isNotNull);
    expect(vault.values['petita.local-plan.backup:fixture-a'], isNull);
    expect(vault.values['petita.local-plan.owner'], isNull);
    expect(jsonEncode(vault.values), isNot(contains('SYNTHETIC')));
  });
  test(
      'consent endpoint offline still queues previously authorized current-version plan, then revalidates before retry',
      () async {
    var offline = false;
    var writes = 0;
    setupClient((r) async {
      if (offline) return response(r, [], 503);
      if (r.url.path == '/api/consent') return response(r, grant);
      writes++;
      final body = jsonDecode(r.body) as Map;
      return response(r, [
        {'id': body['id'], 'revision': 1}
      ]);
    });
    await sync.refreshConsent();
    offline = true;
    await expectLater(
        sync.synchronize(answers), throwsA(isA<NeonApiException>()));
    expect(state()['pending'], isNotNull);
    expect(sync.pending, true);
    expect(writes, 0);
    offline = false;
    await sync.retryPending();
    expect(writes, 1);
    expect(state()['pending'], isNull);
  });
}
