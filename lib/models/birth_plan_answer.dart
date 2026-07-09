class BirthPlanAnswer {
  BirthPlanAnswer({required this.questionId, required this.values});

  final String questionId;
  final List<String> values;

  Map<String, dynamic> toJson() => {
        'questionId': questionId,
        'values': values,
      };

  factory BirthPlanAnswer.fromJson(Map<String, dynamic> json) {
    return BirthPlanAnswer(
      questionId: json['questionId'] as String,
      values: List<String>.from(json['values'] as List),
    );
  }
}
