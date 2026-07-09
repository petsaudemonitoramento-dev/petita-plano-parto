class BirthPlanQuestion {
  BirthPlanQuestion({
    required this.id,
    required this.section,
    required this.question,
    required this.options,
    this.multiple = false,
    this.allowOther = false,
  });

  final String id;
  final String section;
  final String question;
  final List<String> options;
  final bool multiple;
  final bool allowOther;

  factory BirthPlanQuestion.fromJson(Map<String, dynamic> json) {
    return BirthPlanQuestion(
      id: json['id'] as String,
      section: json['section'] as String,
      question: json['question'] as String,
      options: List<String>.from(json['options'] as List),
      multiple: json['multiple'] as bool? ?? false,
      allowOther: json['allowOther'] as bool? ?? false,
    );
  }
}
