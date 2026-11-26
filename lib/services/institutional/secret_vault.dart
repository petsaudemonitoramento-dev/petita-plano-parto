import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SecretVault {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class DeviceSecretVault implements SecretVault {
  final FlutterSecureStorage _storage;
  const DeviceSecretVault([this._storage = const FlutterSecureStorage()]);
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
    if (await _storage.read(key: key) != value)
      throw StateError('Armazenamento protegido indisponível.');
  }

  @override
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
    if (await _storage.read(key: key) != null)
      throw StateError('Não foi possível encerrar a sessão local.');
  }
}
