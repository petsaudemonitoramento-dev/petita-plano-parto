import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Transport-only client for the new API. No database credentials or session
/// persistence. An authenticated Neon token provider must be wired separately.
class NeonApiException implements Exception {
  final int status;
  const NeonApiException(this.status);
  @override
  String toString() => 'Petita online: operação indisponível ($status).';
}

typedef NeonTokenProvider = Future<String?> Function();

class NeonApiClient {
  final Uri _origin;
  final http.Client _http;
  final NeonTokenProvider _token;
  final Duration timeout;
  NeonApiClient({
    required Uri origin,
    required http.Client client,
    required NeonTokenProvider tokenProvider,
    this.timeout = const Duration(seconds: 15),
  })  : _origin = origin,
        _http = client,
        _token = tokenProvider {
    if (origin.scheme != 'https' ||
        !origin.hasAuthority ||
        origin.userInfo.isNotEmpty ||
        origin.hasQuery ||
        origin.hasFragment ||
        (origin.path.isNotEmpty && origin.path != '/')) {
      throw ArgumentError('A API deve ter uma origem HTTPS válida.');
    }
  }

  Future<List<Map<String, dynamic>>> _request(String method, String path,
      {Map<String, dynamic>? body, bool isPublic = false}) async {
    final abort = Completer<void>();
    try {
      return await _boundedRequest(method, path,
              body: body, isPublic: isPublic, abortTrigger: abort.future)
          .timeout(timeout * 2,
              onTimeout: () => throw const NeonApiException(503));
    } finally {
      if (!abort.isCompleted) abort.complete();
    }
  }

  Future<List<Map<String, dynamic>>> _boundedRequest(String method, String path,
      {Map<String, dynamic>? body,
      bool isPublic = false,
      required Future<void> abortTrigger}) async {
    final url = _origin.replace(path: path);
    final headers = <String, String>{'Accept': 'application/json'};
    if (!isPublic) {
      final String? token;
      try {
        token = await _token().timeout(timeout);
      } catch (_) {
        // Session-provider failures must not leak credentials or internal details.
        throw const NeonApiException(503);
      }
      if (token == null ||
          token.isEmpty ||
          token.length > 16384 ||
          RegExp(r'\s').hasMatch(token)) {
        throw const NeonApiException(401);
      }
      headers['Authorization'] = 'Bearer $token';
    }
    final request =
        http.AbortableRequest(method, url, abortTrigger: abortTrigger)
          ..followRedirects = false
          ..headers.addAll(headers);
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    try {
      final response = await _http.send(request).timeout(timeout);
      if (response.statusCode != 200) {
        await response.stream.drain<void>().timeout(timeout);
        throw NeonApiException(response.statusCode);
      }
      if (!(response.headers['content-type'] ?? '')
          .toLowerCase()
          .startsWith('application/json')) {
        await response.stream.drain<void>().timeout(timeout);
        throw const NeonApiException(502);
      }
      final bytes = <int>[];
      await for (final chunk in response.stream.timeout(timeout)) {
        if (bytes.length + chunk.length > 1024 * 1024) {
          throw const NeonApiException(502);
        }
        bytes.addAll(chunk);
      }
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map || decoded['data'] is! List) {
        throw const NeonApiException(502);
      }
      return (decoded['data'] as List).map((row) {
        if (row is! Map<String, dynamic>) throw const NeonApiException(502);
        return row;
      }).toList(growable: false);
    } on NeonApiException {
      rethrow;
    } on Exception {
      // Never leak backend errors or tokens to UI/logs.
      throw const NeonApiException(503);
    }
  }

  static String _id(String value) {
    if (!RegExp(
            r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$')
        .hasMatch(value)) {
      throw const NeonApiException(400);
    }
    return value;
  }

  Future<List<Map<String, dynamic>>> getSyncConsent() =>
      _request('GET', '/api/consent');
  Future<List<Map<String, dynamic>>> acceptSyncConsent({
    required String operationId,
    required String termsVersion,
    required bool acceptedTerms,
    required bool acceptedPrivacy,
    required bool acceptedResponsibility,
    required bool acceptedPlanScience,
    required bool acceptedHealthData,
    required bool acceptedOnlineSync,
  }) =>
      _request('POST', '/api/consent', body: {
        'operation_id': _id(operationId),
        'terms_version': termsVersion,
        'accepted_terms': acceptedTerms,
        'accepted_privacy': acceptedPrivacy,
        'accepted_responsibility': acceptedResponsibility,
        'accepted_plan_science': acceptedPlanScience,
        'accepted_health_data': acceptedHealthData,
        'accepted_online_sync': acceptedOnlineSync,
      });
  Future<List<Map<String, dynamic>>> withdrawSyncConsent(
          String operationId, String termsVersion) =>
      _request('POST', '/api/consent/withdraw', body: {
        'operation_id': _id(operationId),
        'terms_version': termsVersion,
      });
  Future<List<Map<String, dynamic>>> listPlans() =>
      _request('GET', '/api/plans');
  Future<List<Map<String, dynamic>>> syncPlan({
    required String id,
    required int expectedRevision,
    String? patientName,
    String? dppIso,
    String? companion,
    required Map<String, List<String>> answers,
  }) =>
      _request('POST', '/api/plans', body: {
        'id': _id(id),
        'expected_revision': expectedRevision,
        'patient_name': patientName,
        'dpp': dppIso,
        'companion': companion,
        'answers': answers,
      });
  Future<List<Map<String, dynamic>>> getUbsPreference() =>
      _request('GET', '/api/patient/ubs-preference');
  Future<List<Map<String, dynamic>>> saveNoUbsPreference() =>
      _request('POST', '/api/patient/ubs-preference', body: {});
  Future<List<Map<String, dynamic>>> listMyUbsRequests() =>
      _request('GET', '/api/patient/ubs-requests');
  Future<List<Map<String, dynamic>>> requestPatientUbs(
          String code, String operationId) =>
      _request('POST', '/api/patient/ubs-requests',
          body: {'ubs_code': code, 'operation_id': _id(operationId)});
  Future<List<Map<String, dynamic>>> listPatientUbsRequests() =>
      _request('GET', '/api/admin/patient-ubs-requests');
  Future<List<Map<String, dynamic>>> decidePatientUbs(
          String requestId, bool approve) =>
      _request('POST',
          '/api/admin/patient-ubs-requests/${_id(requestId)}/${approve ? "approve" : "reject"}',
          body: {});
  Future<List<Map<String, dynamic>>> revokePatientUbs(
          String patientId, String reason) =>
      _request(
          'POST', '/api/admin/patient-ubs-members/${_id(patientId)}/revoke',
          body: {'reason': reason});
  Future<List<Map<String, dynamic>>> listKnowledge() =>
      _request('GET', '/api/knowledge', isPublic: true);
  Future<List<Map<String, dynamic>>> listKnowledgeCategories() =>
      _request('GET', '/api/knowledge/categories', isPublic: true);
  Future<List<Map<String, dynamic>>> addKnowledgeCategory(String name) =>
      _request('POST', '/api/admin/knowledge/categories', body: {'name': name});
  Future<List<Map<String, dynamic>>> addKnowledgeItem({
    required String category, required String question, required List<String> keywords, required String answer,
  }) => _request('POST', '/api/admin/knowledge', body: {
    'category': category, 'question': question, 'keywords': keywords, 'answer': answer,
  });
  Future<List<Map<String, dynamic>>> listUbs() =>
      _request('GET', '/api/ubs', isPublic: true);
  Future<List<Map<String, dynamic>>> enrollAdminCandidate() =>
      _request('POST', '/api/admin-candidate/profile', body: {});
  Future<List<Map<String, dynamic>>> myAdminRequest() =>
      _request('GET', '/api/admin-candidate/request');
  Future<List<Map<String, dynamic>>> listAdminRequests() =>
      _request('GET', '/api/admin/admin-requests');
  Future<List<Map<String, dynamic>>> decideAdminRequest(String id, bool approve) =>
      _request('POST', '/api/admin/admin-requests/${_id(id)}/${approve ? "approve" : "reject"}', body: {});
  Future<List<Map<String, dynamic>>> enrollProfessionalProfile() =>
      _request('POST', '/api/professional/profile', body: {});
  Future<List<Map<String, dynamic>>> listMyProfessionalRequests() =>
      _request('GET', '/api/team/my-requests');
  Future<List<Map<String, dynamic>>> listProfessionalApprovals() =>
      _request('GET', '/api/admin/professional-approvals');
  Future<List<Map<String, dynamic>>> enrollProfile() =>
      _request('POST', '/api/profile', body: {});
  Future<List<Map<String, dynamic>>> loadProfile() =>
      _request('GET', '/api/me');
  Future<List<Map<String, dynamic>>> listMyQuestions() =>
      _request('GET', '/api/questions/mine');
  Future<List<Map<String, dynamic>>> listTeamQueue() =>
      _request('GET', '/api/team/queue');
  Future<List<Map<String, dynamic>>> listTeamRequests() =>
      _request('GET', '/api/admin/team-requests');

  /// The caller must keep this operation's idempotency key stable across retries.
  /// Each acknowledgement must reflect the user's explicit action.
  Future<List<Map<String, dynamic>>> submitQuestion({
    required String idempotencyKey,
    required String ubsCode,
    required String category,
    required String question,
    required String risk,
    required List<String> warningSigns,
    required bool acknowledgedNonUrgent,
    required bool acknowledgedOptionalReply,
    required bool acknowledgedPseudonymization,
    required bool acknowledgedOwnUbs,
  }) =>
      _request('POST', '/api/questions', body: {
        'idempotency_key': _id(idempotencyKey),
        'ubs_code': ubsCode,
        'category': category,
        'question_text': question,
        'self_risk_level': risk,
        'warning_signs': warningSigns,
        'confirmou_nao_urgencia': acknowledgedNonUrgent,
        'confirmou_resposta_facultativa': acknowledgedOptionalReply,
        'confirmou_visibilidade_anonimizada': acknowledgedPseudonymization,
        'confirmou_ubs_exclusiva': acknowledgedOwnUbs,
      });

  Future<List<Map<String, dynamic>>> requestTeamAccess(
          String ubsCode, String idempotencyKey) =>
      _request('POST', '/api/team/access-request', body: {
        'ubs_code': ubsCode,
        'idempotency_key': _id(idempotencyKey),
      });
  Future<List<Map<String, dynamic>>> respondToQuestion(
          String questionId, String answer, String idempotencyKey) =>
      _request('POST', '/api/team/questions/${_id(questionId)}/answer', body: {
        'answer_text': answer,
        'idempotency_key': _id(idempotencyKey),
      });
  Future<List<Map<String, dynamic>>> decideTeamRequest(
          String requestId, bool approved) =>
      _request('POST',
          '/api/admin/team-requests/${_id(requestId)}/${approved ? "approve" : "reject"}',
          body: {});
  Future<List<Map<String, dynamic>>> revokeTeamMember(
          String profileId, String reason) =>
      _request('POST', '/api/admin/team-members/${_id(profileId)}/revoke',
          body: {'reason': reason});
}
