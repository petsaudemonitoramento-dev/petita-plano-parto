import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_transport.dart';
import 'secret_vault.dart';

// Uses the branch's published Better Auth OpenAPI REST contract, never Google
// tokens or the JWT anonymous endpoint. Native bearer support needs real-device
// OTP validation before release. Passwords/OTP/JWT are never persisted here.
AuthTransport createAuthTransport(
        Uri url, SecretVault vault, http.Client client) =>
    NativeNeonAuthTransport(url, vault, client);

class NativeNeonAuthTransport implements AuthTransport {
  final Uri base;
  final SecretVault vault;
  final http.Client client;
  final Duration timeout;
  String? _credential;
  String? _subject;
  int _generation = 0;
  NativeNeonAuthTransport(this.base, this.vault, this.client,
      {this.timeout = const Duration(seconds: 15)}) {
    if (base.scheme != 'https' ||
        !base.host.endsWith('.neon.tech') ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment) {
      throw ArgumentError('Endpoint Neon Auth inválido.');
    }
  }
  String get _key => 'petita.auth.session.v1:${base.toString()}';

  Future<Map<String, dynamic>> _performRequest(
      String method, String path, Map<String, dynamic>? data,
      {String? credential}) async {
    try {
      final req = http.Request(method,
          Uri.parse('${base.toString().replaceFirst(RegExp(r'/$'), '')}$path'))
        ..followRedirects = false
        ..headers['Accept'] = 'application/json';
      if (credential != null)
        req.headers['Authorization'] = 'Bearer $credential';
      if (data != null) {
        req.headers['Content-Type'] = 'application/json';
        req.body = jsonEncode(data);
      }
      final response = await client.send(req).timeout(timeout);
      if (response.statusCode != 200) {
        await response.stream.drain<void>().timeout(timeout);
        throw InstitutionalAuthException(response.statusCode);
      }
      if (!(response.headers['content-type'] ?? '')
          .toLowerCase()
          .startsWith('application/json')) {
        throw const InstitutionalAuthException(503);
      }
      final bytes = <int>[];
      await for (final part in response.stream.timeout(timeout)) {
        if (bytes.length + part.length > 65536)
          throw const InstitutionalAuthException(503);
        bytes.addAll(part);
      }
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded == null) return {};
      if (decoded is! Map<String, dynamic>)
        throw const InstitutionalAuthException(503);
      return decoded;
    } on InstitutionalAuthException {
      rethrow;
    } catch (_) {
      throw const InstitutionalAuthException(503);
    }
  }

  Future<Map<String, dynamic>> _request(
      String method, String path, Map<String, dynamic>? body,
      {String? credential}) async {
    try {
      return await _performRequest(method, path, body, credential: credential)
          .timeout(timeout);
    } on InstitutionalAuthException catch (e) {
      if (e.status == 401 && credential != null && credential == _credential) {
        await vault.delete(_key);
        _credential = null;
        _subject = null;
        _generation++;
      }
      rethrow;
    } catch (_) {
      throw const InstitutionalAuthException(503);
    }
  }

  Future<void> _restore() async {
    if (_credential != null) return;
    try {
      final raw = await vault.read(_key);
      if (raw == null) return;
      final data = jsonDecode(raw) as Map;
      _credential = data['credential'] as String;
      _subject = data['subject'] as String;
    } catch (_) {
      throw const InstitutionalAuthException(503);
    }
  }

  @override
  Future<Map<String, dynamic>> call(
      String action, Map<String, dynamic> body) async {
    await _restore();
    if (action == 'logout') {
      final old = _credential;
      _generation++;
      await vault
          .delete(_key); // fail closed: do not claim logout if local wipe fails
      _credential = null;
      _subject = null;
      if (old != null) await _request('POST', '/sign-out', {}, credential: old);
      return {};
    }
    if (action == 'session' || action == 'token') {
      if (_credential == null) throw const InstitutionalAuthException(401);
      final session =
          await _request('GET', '/get-session', null, credential: _credential);
      final user = session['user'];
      final expires =
          DateTime.tryParse('${(session['session'] as Map?)?['expiresAt']}');
      if (user is! Map ||
          user['id'] != _subject ||
          expires == null ||
          !expires.isAfter(DateTime.now())) {
        await vault.delete(_key);
        _credential = null;
        _subject = null;
        throw const InstitutionalAuthException(401);
      }
      if (action == 'session') return session;
      // Fetch a fresh short-lived JWT via the session; no anonymous fallback.
      return _request('GET', '/token', null, credential: _credential);
    }
    final routes = {
      'signup': '/sign-up/email',
      'login': '/sign-in/email',
      'resend': '/email-otp/send-verification-otp',
      'verify': '/email-otp/verify-email',
      'requestReset': '/email-otp/request-password-reset',
      'reset': '/email-otp/reset-password',
    };
    final path = routes[action];
    if (path == null) throw const InstitutionalAuthException(400);
    final epoch = _generation;
    final result = await _request('POST', path, body);
    if (epoch != _generation) throw const InstitutionalAuthException(401);
    if (result['token'] is String && result['user'] is Map) {
      final subject = (result['user'] as Map)['id'];
      if (subject is! String || subject.isEmpty)
        throw const InstitutionalAuthException(503);
      await vault.write(_key,
          jsonEncode({'credential': result['token'], 'subject': subject}));
      _credential = result['token'] as String;
      _subject = subject;
    }
    return result;
  }
}
