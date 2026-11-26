import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plano_parto_pet_saude/services/neon_api_client.dart';

void main() {
  const id = '00000000-0000-4000-8000-000000000010';
  final origin = Uri.parse('https://petita.example.invalid');
  http.Response ok() => http.Response('{"data":[{"code":"UBS-TEST"}]}', 200,
      headers: {'content-type': 'application/json'});
  NeonApiClient api(MockClient client, {String? token = 'test-token'}) =>
      NeonApiClient(origin: origin, client: client, tokenProvider: () async => token);
  Matcher status(int code) => isA<NeonApiException>().having((e) => e.status, 'status', code);

  test('public catalog does not request or send a token', () async {
    final c = NeonApiClient(origin: origin, client: MockClient((request) async {
      expect(request.url.path, '/api/ubs');
      expect(request.headers.containsKey('Authorization'), false);
      return ok();
    }), tokenProvider: () async => throw StateError('should not be called'));
    expect((await c.listUbs()).single['code'], 'UBS-TEST');
  });
  test('private route uses verified token provider', () async {
    final c = api(MockClient((request) async {
      expect(request.url.path, '/api/me');
      expect(request.headers['Authorization'], 'Bearer test-token');
      expect(request.followRedirects, false);
      return ok();
    }));
    await c.loadProfile();
  });
  test('missing session never calls backend', () async {
    final c = api(MockClient((_) async => throw StateError('should not call')), token: null);
    await expectLater(c.listMyQuestions(), throwsA(status(401)));
  });
  test('question preserves acknowledgement and idempotency', () async {
    final c = api(MockClient((request) async {
      expect(request.url.path, '/api/questions');
      final body = jsonDecode(request.body) as Map;
      expect(body['idempotency_key'], id);
      expect(body['confirmou_nao_urgencia'], true);
      expect(body['confirmou_resposta_facultativa'], false);
      expect(body.containsKey('patient_id'), false);
      return ok();
    }));
    await c.submitQuestion(idempotencyKey: id, ubsCode: 'UBS-TEST',
      category: 'Teste', question: 'Pergunta fictícia', risk: 'low',
      warningSigns: [], acknowledgedNonUrgent: true,
      acknowledgedOptionalReply: false, acknowledgedPseudonymization: true,
      acknowledgedOwnUbs: true);
  });
  test('rejects invalid IDs before network', () async {
    final c = api(MockClient((_) async => throw StateError('should not call')));
    expect(() => c.respondToQuestion('../other', 'Teste', id), throwsA(status(400)));
  });
  test('forbidden is not reported as success', () async {
    final c = api(MockClient((_) async => http.Response('private details', 403)));
    await expectLater(c.listTeamQueue(), throwsA(status(403)));
  });
  test('invalid data envelope fails closed', () async {
    final c = api(MockClient((_) async => http.Response('{"ok":true}', 200,
      headers: {'content-type':'application/json'})));
    await expectLater(c.listUbs(), throwsA(status(502)));
  });
  test('redirect not followed', () async {
    final c = api(MockClient((_) async => http.Response('', 302,
      headers: {'location':'https://other.example.invalid'})));
    await expectLater(c.loadProfile(), throwsA(status(302)));
  });
  test('non TLS and credentialed origins rejected', () {
    for (final url in ['http://example.invalid', 'https://user@example.invalid']) {
      expect(() => NeonApiClient(origin: Uri.parse(url),
        client: MockClient((_) async => ok()), tokenProvider: () async => null),
        throwsArgumentError);
    }
  });

  test('enrollment cannot send a role or arbitrary identity', () async {
    final c = api(MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/profile');
      expect(jsonDecode(request.body), isEmpty);
      expect(request.headers['Authorization'], 'Bearer test-token');
      return ok();
    }));
    await c.enrollProfile();
  });

  test('consent preserves all explicit decisions and the operation ID', () async {
    final c = api(MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/consent');
      expect(jsonDecode(request.body), {
        'operation_id': id, 'terms_version': '2026-10-21-v1',
        'accepted_terms': true, 'accepted_privacy': true,
        'accepted_responsibility': true, 'accepted_plan_science': true,
        'accepted_health_data': true, 'accepted_online_sync': false,
      });
      return http.Response('', 400);
    }));
    await expectLater(c.acceptSyncConsent(
      operationId: id, termsVersion: '2026-10-21-v1',
      acceptedTerms: true, acceptedPrivacy: true,
      acceptedResponsibility: true, acceptedPlanScience: true,
      acceptedHealthData: true, acceptedOnlineSync: false,
    ), throwsA(status(400)));
  });

  test('consent withdrawal has separate authenticated route', () async {
    final c = api(MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/consent/withdraw');
      expect(request.headers['Authorization'], 'Bearer test-token');
      expect(jsonDecode(request.body), {
        'operation_id': id, 'terms_version': '2026-10-21-v1',
      });
      return ok();
    }));
    await c.withdrawSyncConsent(id, '2026-10-21-v1');
  });

  test('plan creation and update preserve revision, not patient identity', () async {
    var revision = 0;
    final c = api(MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/plans');
      expect(jsonDecode(request.body), {
        'id': id, 'expected_revision': revision,
        'patient_name': 'Paciente fictícia', 'dpp': '2027-01-01',
        'companion': null,
        'answers': {'nome_gestante': ['Paciente fictícia']},
      });
      return http.Response('{"data":[{"revision":${revision + 1}}]}', 200,
        headers: {'content-type': 'application/json'});
    }));
    for (revision = 0; revision < 2; revision++) {
      final result = await c.syncPlan(id: id, expectedRevision: revision,
        patientName: 'Paciente fictícia', dppIso: '2027-01-01',
        answers: {'nome_gestante': ['Paciente fictícia']});
      expect(result.single['revision'], revision + 1);
    }
  });

  test('sync conflict is not reported as successful or retried silently', () async {
    var calls = 0;
    final c = api(MockClient((request) async {
      calls++;
      return http.Response('{"error":"Conflito"}', 409);
    }));
    await expectLater(c.syncPlan(id: id, expectedRevision: 1,
      answers: {}), throwsA(status(409)));
    expect(calls, 1);
  });

  test('consent and plan operations require a session before network', () async {
    final c = api(MockClient((_) async => throw StateError('should not call')), token: null);
    await expectLater(c.getSyncConsent(), throwsA(status(401)));
    await expectLater(c.listPlans(), throwsA(status(401)));
    await expectLater(c.withdrawSyncConsent(id, '2026-10-21-v1'), throwsA(status(401)));
    await expectLater(c.syncPlan(id: id, expectedRevision: 0, answers: {}),
      throwsA(status(401)));
  });

  test('token provider failure is sanitized without contacting backend', () async {
    final c = NeonApiClient(origin: origin,
      client: MockClient((_) async => throw StateError('should not call')),
      tokenProvider: () async => throw StateError('private session detail'));
    await expectLater(c.loadProfile(), throwsA(allOf(status(503),
      predicate((e) => !e.toString().contains('private session detail')))));
  });

  test('token retrieval timeout fails closed before contacting backend', () async {
    final c = NeonApiClient(origin: origin,
      client: MockClient((_) async => throw StateError('should not call')),
      tokenProvider: () => Future<String?>.delayed(
        const Duration(milliseconds: 30), () => 'late-token'),
      timeout: const Duration(milliseconds: 1));
    await expectLater(c.loadProfile(), throwsA(status(503)));
    await Future<void>.delayed(const Duration(milliseconds: 40));
  });
}
