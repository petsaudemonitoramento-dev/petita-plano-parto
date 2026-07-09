class UbsQuestion {
  UbsQuestion({
    required this.id,
    required this.anonymousUserId,
    required this.question,
    required this.createdAt,
    this.answer,
    this.answeredAt,
  });

  final String id;
  final String anonymousUserId;
  final String question;
  final DateTime createdAt;
  final String? answer;
  final DateTime? answeredAt;

  bool get answered => answer != null && answer!.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'anonymousUserId': anonymousUserId,
        'question': question,
        'createdAt': createdAt.toIso8601String(),
        'answer': answer,
        'answeredAt': answeredAt?.toIso8601String(),
      };

  factory UbsQuestion.fromJson(Map<String, dynamic> json) {
    return UbsQuestion(
      id: json['id'] as String,
      anonymousUserId: json['anonymousUserId'] as String,
      question: json['question'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      answer: json['answer'] as String?,
      answeredAt: json['answeredAt'] == null ? null : DateTime.parse(json['answeredAt'] as String),
    );
  }

  UbsQuestion copyWith({String? answer, DateTime? answeredAt}) => UbsQuestion(
        id: id,
        anonymousUserId: anonymousUserId,
        question: question,
        createdAt: createdAt,
        answer: answer ?? this.answer,
        answeredAt: answeredAt ?? this.answeredAt,
      );
}
