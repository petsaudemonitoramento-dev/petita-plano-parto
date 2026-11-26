import 'dart:math';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:plano_parto_pet_saude/services/institutional/auth_transport_native.dart';
import 'package:plano_parto_pet_saude/services/institutional/institutional_auth.dart';
import 'support/institutional_fakes.dart';

class DiagnosticClient extends http.BaseClient {
  final inner = http.Client();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest req) async {
    final response = await inner.send(req);
    final bytes = await response.stream.toBytes();
    print('${req.url.path}: HTTP ${response.statusCode}');
    if (response.statusCode >= 400) {
      try {
        final body = jsonDecode(utf8.decode(bytes));
        if (body is Map) {
          final code = body['code'];
          if (code is String && RegExp(r'^[A-Z_]{3,70}$').hasMatch(code)) print(code);
          final message = '${body['message'] ?? body['error']}'.toLowerCase();
          for (final term in ['origin','email','domain','password','disabled','rate limit','header','not found','not allowed','invalid','missing']) {
            if (message.contains(term)) print('Provider diagnostic: $term');
          }
        }
      } on FormatException { print('Non-JSON error response'); }
    }
    return http.StreamedResponse(Stream.value(bytes), response.statusCode, headers: response.headers);
  }
  @override
  void close() => inner.close();
}

void main() {
  test('Neon homologação: cadastro, login, sessão e JWT sem OTP', () async {
    final random = Random.secure();
    final suffix = List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    final password = List.generate(32, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    final email = 'petita-qa-$suffix@example.invalid';
    final client = DiagnosticClient();
    addTearDown(client.close);
    final url = Uri.parse('https://ep-calm-night-b61u6bdb.neonauth.c-2.sa-east-1.aws.neon.tech/neondb/auth');
    final auth = InstitutionalAuth(NativeNeonAuthTransport(url, MemoryVault(), client));
    await auth.signup('Teste automatizado Petita', email, password);
    print('Cadastro aceito. Fixture para limpeza: $email');
    await auth.login(email, password);
    expect(auth.signedIn, isTrue);
    expect(auth.user?['email'], email);
    print('Login e sessão do mesmo cadastro confirmados sem OTP.');
    final token = await auth.token();
    expect(token != null && token.isNotEmpty, isTrue);
    await auth.logout();
    expect(auth.signedIn, isFalse);
  });
}
