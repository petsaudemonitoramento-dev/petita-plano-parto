class KnowledgeDocument {
  const KnowledgeDocument({
    required this.id,
    required this.title,
    required this.description,
    required this.sourceType,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final String sourceType;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'sourceType': sourceType,
        'createdAt': createdAt.toIso8601String(),
      };

  factory KnowledgeDocument.fromJson(Map<String, dynamic> json) {
    return KnowledgeDocument(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      sourceType: json['sourceType'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
