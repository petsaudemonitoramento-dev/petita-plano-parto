import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/birth_plan_answer.dart';
import '../models/patient_question_history.dart';
import '../models/support_document.dart';
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
      id: json['id']?.toString() ?? '',
      publicCode: json['public_code'] as String? ?? 'DUV-',
      ubsCode: json['ubs_code'] as String? ?? '',
      questionText: json['question_text'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      selfRiskLevel: json['self_risk_level'] as String? ?? 'low',
      hasWarningSigns: json['has_warning_signs'] as bool? ?? false,
      warningSigns: List<String>.from(json['warning_signs'] as List? ?? const []),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      category: json['category'] as String?,
    );
  }
}

class KnowledgeCategory {
  const KnowledgeCategory({required this.name, required this.active});
  final String name;
  final bool active;

  factory KnowledgeCategory.fromJson(Map<String, dynamic> json) {
    return KnowledgeCategory(
      name: json['name'] as String? ?? '',
      active: json['active'] as bool? ?? true,
    );
  }
}

class TeamAccessRequest {
  const TeamAccessRequest({
    required this.id,
    required this.name,
    required this.email,
    required this.ubsCode,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final String ubsCode;
  final String status;
  final DateTime createdAt;

  factory TeamAccessRequest.fromJson(Map<String, dynamic> json) {
    return TeamAccessRequest(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      ubsCode: json['requested_ubs_code'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class SupabaseService {
  static const int maxSupportFileBytes = 20 * 1024 * 1024;
  static const int supportStorageApplicationLimitBytes = 900 * 1024 * 1024;

  SupabaseClient get _client => Supabase.instance.client;

  User? get currentUser {
    try {
      return _client.auth.currentUser;
    } catch (_) {
      // The offline core also runs when the optional backend was not initialized.
      return null;
    }
  }
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
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'name': name,
        'role': 'patient',
        'requested_role': 'ubs_team',
        'requested_ubs_code': ubsCode,
      },
    );
    await requestUbsTeamAccess(name: name, email: email, ubsCode: ubsCode);
    return response;
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
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'patient',
      ubsCode: json['ubs_code'] as String?,
      ubsName: null,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
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

  Future<List<PatientQuestionHistory>> listMyQuestions() async {
    if (!isLoggedIn) throw Exception('Entre com a conta da gestante para visualizar as dúvidas.');
    final data = await _client.rpc('list_my_patient_questions');
    return (data as List? ?? const [])
        .map((item) => PatientQuestionHistory.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
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

  Future<void> requestUbsTeamAccess({
    required String name,
    required String email,
    required String ubsCode,
  }) async {
    final user = currentUser;
    await _client.from('team_access_requests').insert({
      'user_id': user?.id,
      'name': name,
      'email': email,
      'requested_ubs_code': ubsCode,
      'status': 'pending',
    });
  }

  Future<List<TeamAccessRequest>> listTeamAccessRequests() async {
    final data = await _client
        .from('team_access_requests')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: true);
    return (data as List)
        .map((item) => TeamAccessRequest.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<void> decideTeamAccessRequest({required String requestId, required bool approve}) async {
    await _client.rpc('decide_team_access_request', params: {
      'p_request_id': requestId,
      'p_approve': approve,
    });
  }

  Future<List<KnowledgeCategory>> listKnowledgeCategories() async {
    try {
      final data = await _client.from('knowledge_categories').select().eq('active', true).order('name');
      return (data as List)
          .map((item) => KnowledgeCategory.fromJson(Map<String, dynamic>.from(item as Map)))
          .where((item) => item.name.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> addKnowledgeCategory({required String name}) async {
    await _client.from('knowledge_categories').insert({'name': name.trim(), 'active': true});
  }

  Future<RagAnswer?> askPetitaRag({required String question, String? category}) async {
    try {
      final response = await _client.functions.invoke(
        'ask-petita-rag',
        body: {
          'question': question,
          if (category != null && category.trim().isNotEmpty) 'category': category.trim(),
        },
      );
      if (response.status < 200 || response.status >= 300 || response.data == null) return null;
      return RagAnswer.fromJson(Map<String, dynamic>.from(response.data as Map));
    } catch (_) {
      return null;
    }
  }

  Future<List<SupportDocument>> listSupportDocuments() async {
    final data = await _client
        .from('support_documents')
        .select()
        .order('created_at', ascending: false);
    return (data as List)
        .map((item) => SupportDocument.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<SupportStorageUsage> getSupportStorageUsage() async {
    try {
      final data = await _client.rpc('get_support_documents_storage_usage');
      if (data is Map) {
        return SupportStorageUsage.fromJson(Map<String, dynamic>.from(data));
      }
    } catch (_) {}
    return const SupportStorageUsage(
      usedBytes: 0,
      maxBytes: supportStorageApplicationLimitBytes,
    );
  }

  Future<SupportDocument> uploadSupportDocument({
    required String title,
    required String category,
    required PlatformFile file,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('Entre como administrador para anexar documentos.');

    final extension = (file.extension ?? '').toLowerCase();
    if (extension != 'pdf' && extension != 'docx') {
      throw Exception('Envie somente arquivos PDF ou DOCX.');
    }
    if (file.size <= 0 || file.size > maxSupportFileBytes) {
      throw Exception('O arquivo deve ter no máximo 20 MB.');
    }

    final bytes = file.bytes;
    if (bytes == null) {
      throw Exception('Não foi possível ler o arquivo selecionado. Selecione-o novamente.');
    }

    final usage = await getSupportStorageUsage();
    if (usage.usedBytes + file.size > usage.maxBytes) {
      throw Exception('O limite reservado de 900 MB para documentos de apoio seria ultrapassado. Remova um documento antes de continuar.');
    }

    final mimeType = extension == 'pdf'
        ? 'application/pdf'
        : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    final safeName = _safeFileName(file.name);
    final filePath = '${user.id}/${DateTime.now().microsecondsSinceEpoch}_$safeName';

    await _client.storage.from('support-documents').uploadBinary(
          filePath,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );

    try {
      final inserted = await _client
          .from('support_documents')
          .insert({
            'title': title.trim().isEmpty ? file.name : title.trim(),
            'category': category,
            'file_name': file.name,
            'file_path': filePath,
            'mime_type': mimeType,
            'size_bytes': file.size,
            'status': 'queued',
            'active': true,
            'uploaded_by': user.id,
          })
          .select()
          .single();

      final document = SupportDocument.fromJson(Map<String, dynamic>.from(inserted));
      final response = await _client.functions.invoke(
        'process-support-document',
        body: {'document_id': document.id},
      );
      if (response.status < 200 || response.status >= 300) {
        throw Exception('O documento foi enviado, mas o processamento não pôde ser iniciado.');
      }
      return document;
    } catch (e) {
      await _client.storage.from('support-documents').remove([filePath]);
      rethrow;
    }
  }

  Future<void> deleteSupportDocument(String documentId) async {
    final response = await _client.functions.invoke(
      'delete-support-document',
      body: {'document_id': documentId},
    );
    if (response.status < 200 || response.status >= 300) {
      final detail = response.data?.toString() ?? 'erro desconhecido';
      throw Exception('Não foi possível remover o documento: $detail');
    }
  }

  String _safeFileName(String value) {
    final normalized = value
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return normalized.isEmpty ? 'documento' : normalized;
  }
}
