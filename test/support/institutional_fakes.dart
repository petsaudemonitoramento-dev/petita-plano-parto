import 'package:plano_parto_pet_saude/services/institutional/secret_vault.dart';
import 'package:plano_parto_pet_saude/services/institutional/auth_transport.dart';

class MemoryVault implements SecretVault {
  final values = <String, String>{};
  bool failWrites = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('fixture storage failure');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (failWrites) throw StateError('fixture storage failure');
    values.remove(key);
  }
}

class FixtureAuthTransport implements AuthTransport {
  String subject;
  bool signedIn = true;
  FixtureAuthTransport([this.subject = 'fixture-a']);
  @override
  Future<Map<String, dynamic>> call(
      String action, Map<String, dynamic> body) async {
    if (action == 'logout') {
      signedIn = false;
      return {};
    }
    if (!signedIn) throw const InstitutionalAuthException(401);
    if (action == 'session')
      return {
        'user': {
          'id': subject,
          'name': 'SYNTHETIC',
          'email': 'fixture@example.invalid',
          'emailVerified': false
        }
      };
    if (action == 'token') return {'token': 'fixture-api-token'};
    return {};
  }
}
