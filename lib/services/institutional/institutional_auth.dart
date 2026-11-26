import 'package:flutter/foundation.dart';
import 'auth_transport.dart';

class InstitutionalAuth extends ChangeNotifier {
  final AuthTransport transport;
  Map<String, dynamic>? user;
  bool locallySignedOut = false;
  int _generation = 0;
  InstitutionalAuth(this.transport);
  String? get subject => user?['id'] as String?;
  bool get verified => user?['emailVerified'] == true;
  Future<void> signup(String name, String email, String password) async {
    await transport.call('signup',
        {'name': name.trim(), 'email': email.trim(), 'password': password});
  }

  Future<void> login(String email, String password) async {
    final generation = ++_generation;
    user = null;
    await transport
        .call('login', {'email': email.trim(), 'password': password});
    if (generation != _generation) throw const InstitutionalAuthException(401);
    locallySignedOut = false;
    await restore();
    if (user == null) throw const InstitutionalAuthException(401);
  }

  Future<void> verify(String email, String otp) async {
    await transport.call('verify', {'email': email.trim(), 'otp': otp.trim()});
  }

  Future<void> resend(String email) => transport
      .call('resend', {'email': email.trim(), 'type': 'email-verification'});
  Future<void> requestReset(String email) =>
      transport.call('requestReset', {'email': email.trim()});
  Future<void> reset(String email, String otp, String password) =>
      transport.call('reset',
          {'email': email.trim(), 'otp': otp.trim(), 'password': password});
  Future<void> restore() async {
    if (locallySignedOut) return;
    final generation = _generation;
    try {
      final result = await transport.call('session', {});
      if (generation != _generation || locallySignedOut) return;
      final candidate = result['user'];
      user = candidate is Map && candidate['id'] is String
          ? Map<String, dynamic>.from(candidate)
          : null;
    } on InstitutionalAuthException catch (e) {
      user = null;
      if (e.status != 401) rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<String?> token() async {
    if (locallySignedOut) return null;
    final generation = _generation;
    try {
      final result = await transport.call('token', {});
      if (generation != _generation || locallySignedOut)
        throw const InstitutionalAuthException(401);
      return result['token'] as String?;
    } on InstitutionalAuthException catch (e) {
      if (e.status == 401) {
        user = null;
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    _generation++;
    locallySignedOut = true;
    user = null;
    notifyListeners(); // immediately gate all API callers, including remote failure
    await transport.call('logout', {});
  }
}
