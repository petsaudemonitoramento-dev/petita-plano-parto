import '../../models/user_profile.dart';
import '../faq_search_service.dart';
import '../neon_api_client.dart';
import 'plan_sync_controller.dart';
import 'runtime.dart';

// All identities/roles/UBS come from the canonical API. No local-profile fallback.
class InstitutionalQuestionService {
  final InstitutionalRuntime? injected;
  InstitutionalQuestionService([this.injected]);
  InstitutionalRuntime? get runtime =>
      injected ?? InstitutionalRuntime.instance;
  bool get isLoggedIn =>
      runtime?.auth.verified == true && runtime?.auth.locallySignedOut == false;
  Future<({bool connected})> checkConnection() async {
    try {
      await runtime!.api.loadProfile();
      return (connected: true);
    } catch (_) {
      return (connected: false);
    }
  }

  Future<UserProfile?> loadOnlineProfile() async {
    if (!isLoggedIn) return null;
    final p = (await runtime!.api.loadProfile()).single;
    return UserProfile(
        id: p['id'] as String,
        name: p['display_name'] as String? ?? '',
        email: runtime!.auth.user?['email'] as String? ?? '',
        role: p['role'] as String,
        ubsCode: p['ubs_code'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0));
  }

  Future<List<({String name})>> listKnowledgeCategories() async =>
      (await FaqSearchService().loadFaq())
          .map((f) => f.category)
          .toSet()
          .map((name) => (name: name))
          .toList();
  final Map<String, String> _operations = {};
  Future<Map<String, dynamic>> submitPatientQuestion(
      {required String ubsCode,
      required String category,
      required String questionText,
      required String selfRiskLevel,
      required List<String> warningSigns,
      required bool urgencyAcknowledged,
      required bool expectedResponseNoticeAccepted,
      required bool ownUbsAcknowledged,
      required bool pseudonymizationAcknowledged}) async {
    if (!isLoggedIn || !ownUbsAcknowledged || !pseudonymizationAcknowledged)
      throw const NeonApiException(403);
    final subject = runtime!.auth.subject!;
    final payload =
        '$subject|$ubsCode|$category|$questionText|$selfRiskLevel|${warningSigns.join(",")}';
    final operation = _operations.putIfAbsent(payload, newOperationId);
    final rows = await runtime!.api.submitQuestion(
        idempotencyKey: operation,
        ubsCode: ubsCode,
        category: category,
        question: questionText,
        risk: selfRiskLevel,
        warningSigns: warningSigns,
        acknowledgedNonUrgent: urgencyAcknowledged,
        acknowledgedOptionalReply: expectedResponseNoticeAccepted,
        acknowledgedPseudonymization: pseudonymizationAcknowledged,
        acknowledgedOwnUbs: ownUbsAcknowledged);
    if (runtime!.auth.subject != subject) throw const NeonApiException(401);
    final result = rows.single['result'];
    if (result is! Map) throw const NeonApiException(502);
    _operations.remove(payload);
    return Map<String, dynamic>.from(result);
  }
}
