import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plano_parto_pet_saude/services/institutional/auth_transport_native.dart';
import 'package:plano_parto_pet_saude/services/institutional/auth_transport.dart';
import 'package:plano_parto_pet_saude/services/institutional/institutional_auth.dart';
import 'support/institutional_fakes.dart';

void main() {
  final url = Uri.parse('https://fixture.neon.tech/neondb/auth');
  http.Response ok(http.Request r, Object? value) =>
      http.Response(jsonEncode(value), 200,
          headers: {'content-type': 'application/json'}, request: r);
  test(
      'native signs in, restores bearer session from vault and obtains fresh JWT without persisting password/JWT',
      () async {
    final vault = MemoryVault();
    var tokenCalls = 0;
    final client = MockClient((r) async {
      expect(r.followRedirects, false);
      if (r.url.path.endsWith('/sign-in/email'))
        return ok(r, {
          'token': 'opaque-session-fixture',
          'user': {'id': 'fixture-a'}
        });
      expect(r.headers['Authorization'], 'Bearer opaque-session-fixture');
      if (r.url.path.endsWith('/get-session'))
        return ok(r, {
          'user': {'id': 'fixture-a', 'emailVerified': true},
          'session': {
            'expiresAt':
                DateTime.now().add(const Duration(hours: 1)).toIso8601String()
          }
        });
      tokenCalls++;
      return ok(r, {'token': 'short-lived-api-fixture'});
    });
    final auth = InstitutionalAuth(NativeNeonAuthTransport(url, vault, client));
    await auth.login('fixture@example.invalid', 'PASSWORD-NEVER-PERSIST');
    expect(auth.verified, true);
    expect(await auth.token(), 'short-lived-api-fixture');
    final restored =
        InstitutionalAuth(NativeNeonAuthTransport(url, vault, client));
    await restored.restore();
    expect(restored.subject, 'fixture-a');
    expect(await restored.token(), 'short-lived-api-fixture');
    expect(tokenCalls, 2);
    expect(jsonEncode(vault.values), isNot(contains('PASSWORD-NEVER-PERSIST')));
    expect(
        jsonEncode(vault.values), isNot(contains('short-lived-api-fixture')));
  });
  test(
      'logout clears native secret and gates token even when server logout fails',
      () async {
    final vault = MemoryVault();
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/sign-in/email'))
        return ok(r, {
          'token': 'opaque-fixture',
          'user': {'id': 'fixture-a'}
        });
      if (r.url.path.endsWith('/sign-out'))
        return http.Response('internal fixture', 503, request: r);
      return ok(r, {
        'user': {'id': 'fixture-a', 'emailVerified': true},
        'session': {
          'expiresAt':
              DateTime.now().add(const Duration(hours: 1)).toIso8601String()
        }
      });
    });
    final auth = InstitutionalAuth(NativeNeonAuthTransport(url, vault, client));
    await auth.login('fixture@example.invalid', 'fixture');
    await expectLater(
        auth.logout(), throwsA(isA<InstitutionalAuthException>()));
    expect(auth.user, isNull);
    expect(vault.values, isEmpty);
    expect(await auth.token(), isNull);
  });
  test(
      'verification and reset send OTP only to documented endpoints, never persist it',
      () async {
    final vault = MemoryVault();
    final paths = <String>[];
    final client = MockClient((r) async {
      paths.add(r.url.path);
      return ok(r, {});
    });
    final auth = InstitutionalAuth(NativeNeonAuthTransport(url, vault, client));
    await auth.verify('fixture@example.invalid', '123456');
    await auth.requestReset('fixture@example.invalid');
    await auth.reset('fixture@example.invalid', '654321', 'new-fixture');
    expect(paths, [
      '/neondb/auth/email-otp/verify-email',
      '/neondb/auth/email-otp/request-password-reset',
      '/neondb/auth/email-otp/reset-password'
    ]);
    expect(vault.values, isEmpty);
  });
  test('provider errors are sanitized and redirects rejected', () async {
    final auth = NativeNeonAuthTransport(
        url,
        MemoryVault(),
        MockClient((r) async =>
            http.Response('sensitive internal fixture', 302, request: r)));
    try {
      await auth.call('login',
          {'email': 'fixture@example.invalid', 'password': 'secret-fixture'});
      fail('redirect accepted');
    } on InstitutionalAuthException catch (e) {
      expect(e.status, 302);
      expect('$e', isNot(contains('sensitive')));
    }
  });
}
