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
}
