import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../models/birth_plan_answer.dart';
import '../storage_service.dart';
import '../neon_api_client.dart';
import '../birth_plan_flow_service.dart';
import 'institutional_auth.dart';
import 'secret_vault.dart';

String newOperationId() {
  final random = Random.secure();
  final b = List<int>.generate(16, (_) => random.nextInt(256));
  b[6] = (b[6] & 15) | 64;
  b[8] = (b[8] & 63) | 128;
  final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

class PlanConflict implements Exception {
  @override
  String toString() =>
      'Há uma revisão diferente na nuvem. O plano local foi mantido. Compare as versões antes de escolher.';
}

class PlanSyncController extends ChangeNotifier {
  final NeonApiClient api;
  final InstitutionalAuth auth;
  final SecretVault vault;
  final StorageService storage;
  bool busy = false;
  bool pending = false;
  bool consentActive = false;
  bool _remoteConsentActive = false;
  static const termsVersion = '2026-10-21-v1';
  PlanSyncController(
      {required this.api,
      required this.auth,
      required this.vault,
      StorageService? storage})
      : storage = storage ?? StorageService();
  String _stateKey(String subject) => 'petita.sync.v1:$subject';
  Future<Map<String, dynamic>> _state(String subject) async {
    final raw = await vault.read(_stateKey(subject));
    if (raw == null) return {'planId': newOperationId(), 'revision': 0};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      throw const NeonApiException(503);
    } // do not replace corrupted revision/operation IDs
  }

  Future<void> _save(String subject, Map<String, dynamic> value) =>
      vault.write(_stateKey(subject), jsonEncode(value));
  String _subject() {
    if (auth.subject == null || !auth.signedIn || auth.locallySignedOut)
      throw const NeonApiException(401);
    return auth.subject!;
  }

  void _unchanged(String subject) {
    if (_subject() != subject) throw const NeonApiException(401);
  }

  Future<void> refreshConsent() async {
    final subject = _subject();
    final rows = await api.getSyncConsent();
    _unchanged(subject);
    _remoteConsentActive = rows.isNotEmpty &&
        rows.single['terms_version'] == termsVersion &&
        rows.single['action'] == 'grant';
    final state = await _state(subject);
    state['consentGranted'] = _remoteConsentActive;
    state['consentVersion'] = termsVersion;
    if (!_remoteConsentActive) state.remove('pending');
    await _save(subject, state);
    consentActive = _remoteConsentActive && state['withdrawOperation'] == null;
    pending = state['pending'] != null;
    notifyListeners();
  }

  Future<void> grantConsent(Map<String, bool> choices) async {
    final subject = _subject();
    final flags = [
      'terms',
      'privacy',
      'responsibility',
      'planScience',
      'healthData',
      'onlineSync'
    ];
    if (flags.any((key) => choices[key] != true))
      throw const NeonApiException(400);
    final state = await _state(subject);
    if (state['withdrawOperation'] != null) throw const NeonApiException(503);
    final operation = state['grantOperation'] as String? ?? newOperationId();
    state['grantOperation'] = operation;
    await _save(subject, state);
    try {
      await api.acceptSyncConsent(
          operationId: operation,
          termsVersion: termsVersion,
          acceptedTerms: choices['terms']!,
          acceptedPrivacy: choices['privacy']!,
          acceptedResponsibility: choices['responsibility']!,
          acceptedPlanScience: choices['planScience']!,
          acceptedHealthData: choices['healthData']!,
          acceptedOnlineSync: choices['onlineSync']!);
    } on NeonApiException catch (e) {
      if (e.status != 409) rethrow;
    }
    _unchanged(subject);
    await refreshConsent();
    final latest = await _state(subject);
    latest.remove('grantOperation');
    await _save(subject, latest);
    if (!consentActive) throw const NeonApiException(403);
  }

  Future<void> withdrawConsent() async {
    final subject = _subject();
    consentActive = false;
    notifyListeners(); // immediately stop queued operations locally
    final state = await _state(subject);
    state.remove('pending');
    state.remove('grantOperation');
    final operation = state['withdrawOperation'] as String? ?? newOperationId();
    state['withdrawOperation'] = operation;
    await _save(subject, state);
    try {
      await api.withdrawSyncConsent(operation, termsVersion);
    } on NeonApiException catch (e) {
      if (e.status != 409) rethrow;
    }
    _unchanged(subject);
    await refreshConsent();
    if (_remoteConsentActive) throw const NeonApiException(503);
    final latest = await _state(subject);
    latest.remove('withdrawOperation');
    await _save(subject, latest);
  }

  Future<void> synchronize(List<BirthPlanAnswer> local) async {
    if (busy) throw const NeonApiException(409);
    final subject = _subject();
    busy = true;
    notifyListeners();
    try {
      final owner = await vault.read('petita.local-plan.owner');
      if (owner != null && owner != subject) throw PlanConflict();
      final cached = await _state(subject);
      // Keep a durable queue even if the consent endpoint itself is offline,
      // only after this account explicitly granted the current terms earlier.
      if (cached['consentGranted'] == true &&
          cached['consentVersion'] == termsVersion &&
          cached['withdrawOperation'] == null &&
          cached['pending'] == null &&
          jsonEncode(cached['lastPayload']) != jsonEncode(_payload(local))) {
        await vault.write('petita.local-plan.owner', subject);
        cached['pending'] = _payload(local);
        await _save(subject, cached);
        pending = true;
        notifyListeners();
      }
      await refreshConsent();
      final state = await _state(subject);
      if (!consentActive || state['withdrawOperation'] != null)
        throw const NeonApiException(403);
      if (state['pending'] != null) await _sendPending(subject, state);
      _unchanged(subject);
      final payload = _payload(local);
      if (jsonEncode(state['lastPayload']) == jsonEncode(payload)) return;
      state['pending'] = payload;
      await vault.write('petita.local-plan.owner', subject);
      await _save(subject, state); // durable queue before sending
      await _sendPending(subject, state);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Map<String, dynamic> _payload(List<BirthPlanAnswer> local) {
    final map = {for (final answer in local) answer.questionId: answer.values};
    final dpp = map['dpp']?.firstOrNull?.split('/');
    return <String, dynamic>{
      'answers': map,
      'patient_name': map['nome_gestante']?.firstOrNull?.trim(),
      'dpp': dpp?.length == 3
          ? '${dpp![2]}-${dpp[1].padLeft(2, '0')}-${dpp[0].padLeft(2, '0')}'
          : null,
      'companion': map['acompanhante_principal']?.join(', ').trim()
    };
  }

  // Invoked before verified local erasure. No network dependency and no clinical
  // payload remains in a retry/backup that could resurrect the cleared plan.
  Future<void> prepareLocalClear(bool revokeConsent) async {
    if (busy) throw const NeonApiException(409);
    final owner = await vault.read('petita.local-plan.owner') ?? auth.subject;
    if (owner == null) return;
    final state = await _state(owner);
    state.remove('pending');
    state.remove('lastPayload');
    state.remove('grantOperation');
    state['planId'] = newOperationId();
    state['revision'] = 0;
    if (revokeConsent) {
      state['withdrawOperation'] ??= newOperationId();
      state['consentGranted'] = false;
      consentActive = false;
    }
    await _save(owner, state);
    await vault.delete('petita.local-plan.backup:$owner');
    await vault.delete('petita.local-plan.owner');
    pending = false;
    notifyListeners();
  }

  Future<void> retryPending() async {
    if (busy || auth.subject == null || !auth.signedIn) return;
    final subject = _subject();
    final state = await _state(subject);
    // Never grant consent implicitly on reconnect, or resurrect a withdrawn queue.
    if (state['withdrawOperation'] != null) {
      await withdrawConsent();
      return;
    }
    if (state['pending'] == null) return;
    busy = true;
    notifyListeners();
    try {
      await refreshConsent();
      if (consentActive) await _sendPending(subject, state);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _sendPending(String subject, Map<String, dynamic> state) async {
    final data = Map<String, dynamic>.from(state['pending'] as Map);
    pending = true;
    notifyListeners();
    _unchanged(subject);
    List<Map<String, dynamic>> rows;
    try {
      rows = await api.syncPlan(
          id: state['planId'] as String,
          expectedRevision: state['revision'] as int,
          patientName: data['patient_name'] as String?,
          dppIso: data['dpp'] as String?,
          companion: data['companion'] as String?,
          answers: (data['answers'] as Map)
              .map((k, v) => MapEntry('$k', List<String>.from(v as List))));
    } on NeonApiException catch (e) {
      if (e.status != 409) rethrow;
      // A lost response may have committed. Read own records and acknowledge only
      // an exact payload at the next revision; otherwise retain both versions.
      final plans = await api.listPlans();
      final same = plans.where((p) => p['id'] == state['planId']).firstOrNull;
      if (same == null ||
          same['revision'] != (state['revision'] as int) + 1 ||
          !_same(same, data)) throw PlanConflict();
      rows = [same];
    }
    _unchanged(subject);
    if (rows.length != 1 ||
        rows.single['id'] != state['planId'] ||
        rows.single['revision'] is! int ||
        rows.single['revision'] != (state['revision'] as int) + 1)
      throw const NeonApiException(502);
    state['revision'] = rows.single['revision'];
    state['lastPayload'] = data;
    state.remove('pending');
    await _save(subject, state);
    pending = false;
    notifyListeners();
  }

  bool _same(Map<String, dynamic> remote, Map<String, dynamic> local) {
    final a = Map<String, dynamic>.from(remote['answers_json'] as Map? ?? {});
    final b = Map<String, dynamic>.from(local['answers'] as Map);
    return a.length == b.length &&
        b.entries.every((e) => jsonEncode(a[e.key]) == jsonEncode(e.value)) &&
        remote['patient_name'] == local['patient_name'] &&
        remote['companion'] == local['companion'] &&
        (remote['dpp'] == null ? null : '${remote['dpp']}'.split('T').first) ==
            local['dpp'];
  }

  Future<void> restorePlan(String planId,
      {required bool confirmedReplace}) async {
    if (!confirmedReplace || busy) throw const NeonApiException(400);
    final subject = _subject();
    busy = true;
    notifyListeners();
    try {
      final rows = await api.listPlans();
      _unchanged(subject);
      final plan = rows.where((p) => p['id'] == planId).firstOrNull;
      if (plan == null ||
          plan['answers_json'] is! Map ||
          plan['revision'] is! int ||
          (plan['revision'] as int) < 1) throw const NeonApiException(404);
      if (utf8.encode(jsonEncode(plan['answers_json'])).length > 12000)
        throw const NeonApiException(502);
      final allowed = (await BirthPlanFlowService().loadQuestions())
          .map((q) => q.id)
          .toSet();
      if ((plan['answers_json'] as Map).length > 31 ||
          !(plan['answers_json'] as Map).keys.every(allowed.contains))
        throw const NeonApiException(502);
      final values = (plan['answers_json'] as Map).entries.map((e) {
        if (e.value is! List ||
            (e.value as List).length > 30 ||
            (e.value as List).any((v) => v is! String || v.length > 1500))
          throw const NeonApiException(502);
        return BirthPlanAnswer(
            questionId: '${e.key}', values: List<String>.from(e.value));
      }).toList();
      final owner = await vault.read('petita.local-plan.owner');
      if (owner != null && owner != subject) throw PlanConflict();
      await vault.write(
          'petita.local-plan.backup:$subject',
          jsonEncode(
              (await storage.loadAnswers()).map((a) => a.toJson()).toList()));
      _unchanged(subject);
      await storage.saveAnswers(values);
      await vault.write('petita.local-plan.owner', subject);
      await _save(subject, {'planId': planId, 'revision': plan['revision']});
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
