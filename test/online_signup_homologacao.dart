import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:plano_parto_pet_saude/services/institutional/auth_transport_native.dart';
import 'package:plano_parto_pet_saude/services/institutional/institutional_auth.dart';
import 'support/institutional_fakes.dart';

void main() {
  test('Neon homologação: cadastro, login, sessão e JWT sem OTP', () async {
    final random = Random.secure();
    final suffix = List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    final password = List.generate(32, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    final email = 'petita-qa-$suffix@example.invalid';
    final client = http.Client();
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
