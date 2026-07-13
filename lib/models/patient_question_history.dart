class PatientQuestionHistory {
  const PatientQuestionHistory({
    required this.id,
    required this.publicCode,
    required this.category,
    required this.questionText,
    required this.status,
    required this.ubsCode,
    required this.createdAt,
    this.answerText,
    this.answeredAt,
  });

  final String id;
  final String publicCode;
  final String category;
  final String questionText;
  final String status;
  final String ubsCode;
  final String? answerText;
  final DateTime createdAt;
  final DateTime? answeredAt;

  bool get isAnswered => status == 'answered' && (answerText?.trim().isNotEmpty ?? false);

  factory PatientQuestionHistory.fromJson(Map<String, dynamic> json) {
    return PatientQuestionHistory(
      id: json['id']?.toString() ?? '',
      publicCode: json['public_code'] as String? ?? 'DUV-',
      category: json['category'] as String? ?? 'Outros',
      questionText: json['question_text'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      ubsCode: json['ubs_code'] as String? ?? '',
      answerText: json['answer_text'] as String?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      answeredAt: DateTime.tryParse(json['answered_at']?.toString() ?? ''),
    );
  }
}

class RagAnswer {
  const RagAnswer({
    required this.found,
    required this.answer,
    required this.sources,
    this.similarity,
  });

  final bool found;
  final String answer;
  final List<String> sources;
  final double? similarity;

  factory RagAnswer.fromJson(Map<String, dynamic> json) {
    return RagAnswer(
      found: json['found'] as bool? ?? false,
      answer: json['answer'] as String? ?? '',
      sources: List<String>.from(json['sources'] as List? ?? const []),
      similarity: (json['similarity'] as num?)?.toDouble(),
    );
  }
}
