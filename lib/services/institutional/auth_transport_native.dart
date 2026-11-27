import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/institutional_config.dart';
import 'auth_transport.dart';
import 'secret_vault.dart';

// Neon issues a signed session cookie to the native HTTP client. Only this
// origin-scoped cookie is stored in the secure vault. The short-lived JWT is
// retrieved from the authenticated session and never persisted.
typedef _AuthResponse = ({Map<String, dynamic> data, String? cookie, String? jwt});
AuthTransport createAuthTransport(
        Uri url, SecretVault vault, http.Client client) =>
    NativeNeonAuthTransport(url, vault, client,
        appOrigin: Uri.parse(InstitutionalConfig.apiUrl));

class NativeNeonAuthTransport implements AuthTransport {
  final Uri base;
  final SecretVault vault;
  final http.Client client;
  final Duration timeout;
  final Uri appOrigin;
  String? _credential;
  String? _subject;
  int _generation = 0;
  NativeNeonAuthTransport(this.base, this.vault, this.client,
      {required this.appOrigin, this.timeout = const Duration(seconds: 15)}) {
    if (appOrigin.scheme != 'https' ||
        !appOrigin.hasAuthority || appOrigin.host.isEmpty ||
        appOrigin.userInfo.isNotEmpty || appOrigin.hasQuery ||
        appOrigin.hasFragment ||
        (appOrigin.path.isNotEmpty && appOrigin.path != '/')) {
      throw ArgumentError('Origem institucional inválida.');
    }
    if (base.scheme != 'https' ||
        !base.host.endsWith('.neon.tech') ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment) {
      throw ArgumentError('Endpoint Neon Auth inválido.');
    }
  }
  String get _key => 'petita.auth.session.v1:${base.toString()}';

  static const _cookieName = '__Secure-neon-auth.session_token';
  String? _sessionCookie(String? header) {
    if (header == null || header.length > 32768) return null;
    final match = RegExp(r'(?:^|,\s*)__Secure-neon-auth\.session_token=([^;,\s]+)').firstMatch(header);
    final value = match?.group(1);
    if (value == null || value.isEmpty || value.length > 8192) return null;
    return '$_cookieName=$value';
  }
  bool _validCookie(String value) => value.length <= 8250 && RegExp(r'^__Secure-neon-auth\.session_token=[^;,\s]+$').hasMatch(value);
  bool _isJwt(Object? value) => value is String && value.length <= 16384 && RegExp(r'^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$').hasMatch(value);

  Future<_AuthResponse> _performRequest(
      String method, String path, Map<String, dynamic>? data,
      {String? credential}) async {
    try {
      final req = http.Request(method,
          Uri.parse('${base.toString().replaceFirst(RegExp(r'/$'), '')}$path'))
        ..followRedirects = false
        ..headers['Accept'] = 'application/json'
        // The configured institutional app origin must be registered in Neon.
        // Native HTTP does not supply an Origin header automatically.
        ..headers['Origin'] = appOrigin.origin;
      if (credential != null) {
        if (!_validCookie(credential)) throw const InstitutionalAuthException(401);
        req.headers['Cookie'] = credential;
      }
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
      if (decoded != null && decoded is! Map<String, dynamic>)
        throw const InstitutionalAuthException(503);
      return (data: (decoded as Map<String, dynamic>?) ?? {},
          cookie: _sessionCookie(response.headers['set-cookie']),
          jwt: response.headers['set-auth-jwt']);
    } on InstitutionalAuthException {
      rethrow;
    } catch (_) {
      throw const InstitutionalAuthException(503);
    }
  }

  Future<_AuthResponse> _request(
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
      final cookie = data['credential'];
      final subject = data['subject'];
      if (cookie is! String || !_validCookie(cookie) || subject is! String || subject.isEmpty) {
        // Old builds stored an opaque token, which Neon does not accept here.
        await vault.delete(_key);
        return;
      }
      _credential = cookie;
      _subject = subject;
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
      final epoch = _generation;
      final response = await _request('GET', '/get-session', null, credential: _credential);
      if (epoch != _generation) throw const InstitutionalAuthException(401);
      final session = response.data;
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
      final candidate = response.jwt ?? (session['session'] as Map?)?['token'];
      if (_isJwt(candidate)) return {'token': candidate};
      final token = (await _request('GET', '/token', null, credential: _credential)).data['token'];
      if (epoch != _generation) throw const InstitutionalAuthException(401);
      if (!_isJwt(token)) throw const InstitutionalAuthException(503);
      return {'token': token};
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
    final response = await _request('POST', path, body);
    if (epoch != _generation) throw const InstitutionalAuthException(401);
    final result = response.data;
    if (response.cookie != null && result['user'] is Map) {
      final subject = (result['user'] as Map)['id'];
      if (subject is! String || subject.isEmpty)
        throw const InstitutionalAuthException(503);
      await vault.write(_key,
          jsonEncode({'credential': response.cookie, 'subject': subject}));
      if (epoch != _generation) { await vault.delete(_key); throw const InstitutionalAuthException(401); }
      _credential = response.cookie;
      _subject = subject;
    } else if (action == 'login') {
      throw const InstitutionalAuthException(503);
    }
    return result;
  }
}
