import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'secret_vault.dart';

// Authenticated snapshot. The protected key is separate from the envelope.
// Legacy keys are retained until an explicit verified local erasure; migration
// never overwrites or discards the original clinical answers on failure.
class ProtectedPatientStore {
  static const recordKey = 'petita_patient_envelope_v1';
  static const keyId = 'petita_patient_key_v1';
  static const patientKeys = {
    'birth_plan_answers',
    'birth_plan_consultation_deferred_v1',
    'birth_plan_consultation_notes_v1',
    'birth_plan_treatment_preferences_v1',
    'consent_record_v2',
    'consent_accepted',
    'ubs_questions',
    'local_user_profile',
  };
  final SecretVault vault;
  final SharedPreferences preferences;
  final AesGcm cipher = AesGcm.with256bits();
  Map<String, dynamic> _data = {};
  late SecretKey _key;
  bool _ready = false;
  ProtectedPatientStore(this.vault, this.preferences);
  Future<void> initialize() async {
    await preferences.reload();
    final envelope = preferences.getString(recordKey);
    final encodedKey = await vault.read(keyId);
    if (envelope != null && encodedKey == null)
      throw StateError('Chave protegida indisponível. Dados preservados.');
    _key = encodedKey == null
        ? await cipher.newSecretKey()
        : SecretKey(base64Decode(encodedKey));
    if (encodedKey == null)
      await vault.write(keyId, base64Encode(await _key.extractBytes()));
    if (envelope != null) {
      _data = await _decode(
          envelope); // bad tag or unknown schema never becomes an empty plan
    } else {
      _data = {
        for (final key in patientKeys)
          if (preferences.containsKey(key)) key: preferences.get(key)
      };
      await _commit(
          _data); // source remains intact if encryption/write/read-back fails
    }
    _ready = true;
  }

  Future<Map<String, dynamic>> _decode(String raw) async {
    final envelope = jsonDecode(raw) as Map;
    if (envelope['version'] != 1)
      throw StateError('Formato protegido não suportado.');
    final box = SecretBox(base64Decode(envelope['data'] as String),
        nonce: base64Decode(envelope['nonce'] as String),
        mac: Mac(base64Decode(envelope['tag'] as String)));
    final clear =
        await cipher.decrypt(box, secretKey: _key, aad: utf8.encode(recordKey));
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(clear)) as Map);
  }

  Future<void> _commit(Map<String, dynamic> value) async {
    final box = await cipher.encrypt(utf8.encode(jsonEncode(value)),
        secretKey: _key, aad: utf8.encode(recordKey));
    final raw = jsonEncode({
      'version': 1,
      'nonce': base64Encode(box.nonce),
      'tag': base64Encode(box.mac.bytes),
      'data': base64Encode(box.cipherText)
    });
    if (!await preferences.setString(recordKey, raw)) {
      await preferences.reload();
      throw StateError('Gravação protegida recusada.');
    }
    await preferences.reload();
    final persisted = preferences.getString(recordKey);
    if (persisted == null ||
        jsonEncode(await _decode(persisted)) != jsonEncode(value))
      throw StateError('Gravação protegida não confirmada.');
    _data = Map.from(value);
  }

  Object? read(String key) {
    if (!_ready) throw StateError('Armazenamento protegido indisponível.');
    final value = _data[key];
    return value is List ? List<String>.from(value) : value;
  }

  Future<void> write(String key, Object? value) async {
    if (!_ready) throw StateError('Armazenamento protegido indisponível.');
    final next = Map<String, dynamic>.from(_data);
    if (value == null) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    await _commit(next);
    // A verified removal must also erase the corresponding legacy residue.
    if (value == null && preferences.containsKey(key)) {
      if (!await preferences.remove(key)) {
        await preferences.reload();
        throw StateError('Limpeza legada não confirmada.');
      }
      await preferences.reload();
      if (preferences.containsKey(key))
        throw StateError('Limpeza legada não confirmada.');
    }
  }
}
