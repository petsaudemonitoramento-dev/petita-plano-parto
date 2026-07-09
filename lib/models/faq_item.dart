class FaqItem {
  FaqItem({
    required this.id,
    required this.category,
    required this.question,
    required this.keywords,
    required this.answer,
    required this.riskLevel,
  });

  final String id;
  final String category;
  final String question;
  final List<String> keywords;
  final String answer;
  final String riskLevel;

  factory FaqItem.fromJson(Map<String, dynamic> json) {
    return FaqItem(
      id: json['id'] as String,
      category: json['category'] as String,
      question: json['question'] as String,
      keywords: List<String>.from(json['keywords'] as List),
      answer: json['answer'] as String,
      riskLevel: json['riskLevel'] as String,
    );
  }
}
