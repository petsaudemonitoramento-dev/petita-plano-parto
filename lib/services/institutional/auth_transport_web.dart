import 'dart:convert';
import 'dart:js_interop';
import 'package:http/http.dart' as http;
import 'auth_transport.dart';
import 'secret_vault.dart';

@JS('petitaNeonAuthCall')
external JSPromise<JSString> _call(JSString action, JSString payload);
AuthTransport createAuthTransport(
        Uri url, SecretVault vault, http.Client client) =>
    WebNeonAuthTransport(url);

class WebNeonAuthTransport implements AuthTransport {
  final Uri base;
  WebNeonAuthTransport(this.base);
  @override
  Future<Map<String, dynamic>> call(
      String action, Map<String, dynamic> body) async {
    try {
      final value = await _call(action.toJS,
              jsonEncode({'url': base.toString(), 'body': body}).toJS)
          .toDart
          .timeout(const Duration(seconds: 15));
      final result = jsonDecode(value.toDart) as Map<String, dynamic>;
      if (result['error'] is Map)
        throw InstitutionalAuthException(
            (result['error'] as Map)['status'] as int? ?? 503);
      return Map<String, dynamic>.from(result['data'] as Map? ?? {});
    } on InstitutionalAuthException {
      rethrow;
    } catch (_) {
      throw const InstitutionalAuthException(503);
    }
  }
}
