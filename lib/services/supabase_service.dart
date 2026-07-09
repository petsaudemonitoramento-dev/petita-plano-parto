import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/birth_plan_answer.dart';
import '../models/user_profile.dart';

class OnlineStatus {
  const OnlineStatus({required this.connected, required this.message});
  final bool connected;
  final String message;
}

class AnonymousQuestion {
  const AnonymousQuestion({
    required this.id,
    required this.publicCode,
    required this.ubsCode,
    required this.questionText,
    required this.status,
    required this.selfRiskLevel,
    required this.hasWarningSigns,
    required this.warningSigns,
    required this.createdAt,
    this.category,
  });

  final String id;
  final String publicCode;
  final String ubsCode;
  final String questionText;
  final String status;
  final String selfRiskLevel;
  final bool hasWarningSigns;
  final List<String> warningSigns;
  final DateTime createdAt;
  final String? category;

  factory AnonymousQuestion.fromJson(Map<String, dynamic> json) {
    return AnonymousQuestion(
      id: json['id'] as String,
      publicCode: json['public_code'] as String? ?? 'DUV-',
      ubsCode: json['ubs_code'] as String? ?? '',
      questionText: json['question_text'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      selfRiskLevel: json['self_risk_level'] as String? ?? 'low',
      hasWarningSigns: json['has_warning_signs'] as bool? ?? false,
      warningSigns: List<String>.from(json['warning_signs'] as List? ?? const []),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      category: json['category'] as String?,
    );
  }
}

class SupabaseService {
  SupabaseClient get _client => Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  Future<OnlineStatus> checkConnection() async {
    try {
      await _client.from('ubs').select('code').limit(1);
      return const OnlineStatus(connected: true, message: 'Conectado ao Supabase.');
    } catch (e) {
      return OnlineStatus(connected: false, message: 'Sem conexão online no momento: $e');
    }
  }

  Future<AuthResponse> signUpPatient({
    required String name,
    required String email,
    required String password,
    String? ubsCode,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'name': name,
        'role': 'patient',
        if (ubsCode != null && ubsCode.isNotEmpty) 'ubs_code': ubsCode,
      },
    );
  }

  Future<AuthResponse> signUpUbsTeam({
    required String name,
    required String email,
    required String password,
    required String ubsCode,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'name': name,
        'role': 'patient',
        'requested_role': 'ubs_team',
        'requested_ubs_code': ubsCode,
      },
    );
  }

  Future<AuthResponse> signIn({required String email, required String password}) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<UserProfile?> loadOnlineProfile() async {
    final user = currentUser;
    if (user == null) return null;
    final data = await _client.from('profiles').select().eq('id', user.id).maybeSingle();
    if (data == null) return null;
    return _profileFromSupabase(Map<String, dynamic>.from(data));
  }

  UserProfile _profileFromSupabase(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'patient',
      ubsCode: json['ubs_code'] as String?,
      ubsName: null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Future<void> updatePatientProfile({
    required String name,
    required String email,
    String? ubsCode,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');
    await _client.from('profiles').update({
      'name': name,
      'email': email,
      'ubs_code': ubsCode,
    }).eq('id', user.id);
  }

  Future<void> syncBirthPlan({
    required String patientName,
    required String? ubsCode,
    required String? dppBr,
    required String? companion,
    required List<BirthPlanAnswer> answers,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('Faça login para sincronizar o Plano de Parto.');
    await _client.from('birth_plans').insert({
      'patient_id': user.id,
      'ubs_code': ubsCode,
      'patient_name': patientName,
      'dpp': _parseDateBrToIso(dppBr),
      'companion': companion,
      'answers_json': {
        for (final answer in answers) answer.questionId: answer.values,
      },
      'pdf_generated_at': DateTime.now().toIso8601String(),
    });
  }

  String? _parseDateBrToIso(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parts = value.trim().split('/');
    if (parts.length != 3) return null;
    final day = parts[0].padLeft(2, '0');
    final month = parts[1].padLeft(2, '0');
    final year = parts[2];
    if (year.length != 4) return null;
    return '$year-$month-$day';
  }

  Future<Map<String, dynamic>> submitPatientQuestion({
    required String ubsCode,
    required String category,
    required String questionText,
    required String selfRiskLevel,
    required List<String> warningSigns,
    required bool urgencyAcknowledged,
    required bool expectedResponseNoticeAccepted,
  }) async {
    final result = await _client.rpc('submit_patient_question', params: {
      'p_ubs_code': ubsCode,
      'p_category': category,
      'p_question_text': questionText,
      'p_self_risk_level': selfRiskLevel,
      'p_warning_signs': warningSigns,
      'p_urgency_acknowledged': urgencyAcknowledged,
      'p_expected_response_notice_accepted': expectedResponseNoticeAccepted,
    });
    if (result is List && result.isNotEmpty) {
      return Map<String, dynamic>.from(result.first as Map);
    }
    if (result is Map) return Map<String, dynamic>.from(result);
    return <String, dynamic>{};
  }

  Future<List<AnonymousQuestion>> listTeamQuestions() async {
    final data = await _client
        .from('team_questions_anonymous')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: true);
    return (data as List)
        .map((item) => AnonymousQuestion.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<void> respondToQuestion({required String questionId, required String answerText}) async {
    await _client.rpc('respond_to_patient_question', params: {
      'p_question_id': questionId,
      'p_answer_text': answerText,
    });
  }

  Future<void> createUbs({required String code, required String name, String city = 'Campina Grande', String state = 'PB'}) async {
    await _client.from('ubs').insert({
      'code': code,
      'name': name,
      'city': city,
      'state': state,
      'active': true,
    });
  }

  Future<void> addKnowledgeBaseItem({
    required String category,
    required String question,
    required List<String> keywords,
    required String answer,
  }) async {
    await _client.from('knowledge_base').insert({
      'category': category,
      'question': question,
      'keywords': keywords,
      'answer': answer,
      'active': true,
    });
  }

  Future<void> approveUbsTeamByEmail({
    required String email,
    required String name,
    required String ubsCode,
  }) async {
    await _client.rpc('approve_ubs_team_by_email', params: {
      'p_email': email,
      'p_name': name,
      'p_ubs_code': ubsCode,
    });
  }
}
