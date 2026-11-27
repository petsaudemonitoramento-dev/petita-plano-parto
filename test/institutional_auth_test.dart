import 'dart:convert';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plano_parto_pet_saude/services/institutional/auth_transport_native.dart';
import 'package:plano_parto_pet_saude/services/institutional/auth_transport.dart';
import 'package:plano_parto_pet_saude/services/institutional/institutional_auth.dart';
import 'support/institutional_fakes.dart';

class DelayedFixture extends FixtureAuthTransport {
  final waiting = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> call(String action, Map<String, dynamic> body) =>
      action == 'token' ? waiting.future : super.call(action, body);
}

void main() {
  final url = Uri.parse('https://fixture.neon.tech/neondb/auth');
  final appOrigin = Uri.parse('https://petita.example.invalid');
  const cookie = '__Secure-neon-auth.session_token=signed-fixture';
  const jwt = 'fixture.header.signature';
  http.Response ok(http.Request r, Object? value, {bool sessionCookie = false, String? accessJwt}) =>
      http.Response(jsonEncode(value), 200,
          headers: {'content-type': 'application/json', if (sessionCookie) 'set-cookie': '$cookie; Secure; HttpOnly; Path=/', if (accessJwt != null) 'set-auth-jwt': accessJwt}, request: r);
  test(
      'native signs in, restores signed cookie from vault and obtains fresh JWT without persisting password/JWT',
      () async {
    final vault = MemoryVault();
    var tokenCalls = 0;
    final client = MockClient((r) async {
      expect(r.followRedirects, false);
      expect(r.headers['Origin'], appOrigin.origin);
      if (r.url.path.endsWith('/sign-in/email') || r.url.path.endsWith('/sign-up/email'))
        return ok(r, {
          'token': 'opaque-session-fixture',
          'user': {'id': 'fixture-a'}
        }, sessionCookie: true);
      expect(r.headers['Cookie'], cookie);
      expect(r.headers['Authorization'], isNull);
      if (r.url.path.endsWith('/get-session'))
        return ok(r, {
          'user': {'id': 'fixture-a', 'emailVerified': false},
          'session': {
            'expiresAt':
                DateTime.now().add(const Duration(hours: 1)).toIso8601String()
          }
        });
      tokenCalls++;
      return ok(r, {'token': 'fixture.header.signature'});
    });
    final auth = InstitutionalAuth(NativeNeonAuthTransport(url, vault, client, appOrigin: appOrigin));
    await auth.signup('Fixture', 'fixture@example.invalid', 'PASSWORD-NEVER-PERSIST');
    await auth.login('fixture@example.invalid', 'PASSWORD-NEVER-PERSIST');
    expect(auth.signedIn, true);
    expect(await auth.token(), 'fixture.header.signature');
    final restored =
        InstitutionalAuth(NativeNeonAuthTransport(url, vault, client, appOrigin: appOrigin));
    await restored.restore();
    expect(restored.subject, 'fixture-a');
    expect(await restored.token(), 'fixture.header.signature');
    expect(tokenCalls, 2);
    expect(jsonEncode(vault.values), contains(cookie));
    expect(jsonEncode(vault.values), isNot(contains('opaque-session-fixture')));
    expect(jsonEncode(vault.values), isNot(contains('PASSWORD-NEVER-PERSIST')));
    expect(
        jsonEncode(vault.values), isNot(contains('fixture.header.signature')));
  });
  test('native uses the JWT issued in get-session header and not the opaque session token', () async {
    final vault = MemoryVault();
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/sign-in/email')) {
        return ok(r, {'token':'opaque-fixture','user':{'id':'fixture-a'}}, sessionCookie:true);
      }
      expect(r.headers['Cookie'], cookie);
      expect(r.url.path, endsWith('/get-session'));
      return ok(r, {'user': {'id':'fixture-a'}, 'session': {'expiresAt': DateTime.now().add(const Duration(hours:1)).toIso8601String(), 'token':'opaque'}}, accessJwt:jwt);
    });
    final auth = InstitutionalAuth(NativeNeonAuthTransport(url,vault,client,appOrigin:appOrigin));
    await auth.login('fixture@example.invalid','fixture-password');
    expect(await auth.token(),jwt);
    expect(jsonEncode(vault.values),isNot(contains(jwt)));
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
        }, sessionCookie: true);
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
    final auth = InstitutionalAuth(NativeNeonAuthTransport(url, vault, client, appOrigin: appOrigin));
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
      expect(r.headers['Origin'], appOrigin.origin);
      paths.add(r.url.path);
      return ok(r, {});
    });
    final auth = InstitutionalAuth(NativeNeonAuthTransport(url, vault, client, appOrigin: appOrigin));
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
            http.Response('sensitive internal fixture', 302, request: r)),
        appOrigin: appOrigin);
    try {
      await auth.call('login',
          {'email': 'fixture@example.invalid', 'password': 'secret-fixture'});
      fail('redirect accepted');
    } on InstitutionalAuthException catch (e) {
      expect(e.status, 302);
      expect('$e', isNot(contains('sensitive')));
    }
  });
  test('logout invalidates token retrieval already in flight', () async {
    final fixture = DelayedFixture();
    final auth = InstitutionalAuth(fixture);
    await auth.restore();
    final pending = auth.token();
    final denied =
        expectLater(pending, throwsA(isA<InstitutionalAuthException>()));
    await auth.logout();
    fixture.waiting.complete({'token': 'PREVIOUS-SYNTHETIC-TOKEN'});
    await denied;
    expect(auth.user, isNull);
    expect(await auth.token(), isNull);
  });
  test(
      'expired native session is erased and never reported as authenticated login',
      () async {
    final vault = MemoryVault();
    final client = MockClient((r) async => ok(
        r,
        r.url.path.endsWith('/sign-in/email')
            ? {
                'token': 'opaque-fixture',
                'user': {'id': 'fixture-a'}
              }
            : {
                'user': {'id': 'fixture-a', 'emailVerified': true},
                'session': {'expiresAt': '2020-01-01T00:00:00Z'}
              }, sessionCookie: r.url.path.endsWith('/sign-in/email')));
    final auth = InstitutionalAuth(NativeNeonAuthTransport(url, vault, client, appOrigin: appOrigin));
    await expectLater(auth.login('fixture@example.invalid', 'fixture-password'),
        throwsA(isA<InstitutionalAuthException>()));
    expect(auth.user, isNull);
    expect(vault.values, isEmpty);
  });
}
