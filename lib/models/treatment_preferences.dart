/// Preferência opcional de tratamento no Plano de Parto.
///
/// A escolha não define sexo, gênero ou informação clínica. Não é enviada
/// automaticamente para um servidor, e sua presença nos PDFs exige opt-in.
class TreatmentPreferences {
  const TreatmentPreferences({
    required this.pronouns,
    this.includeInPdf = false,
    this.conversationScope,
  });

  /// Texto escolhido pela pessoa. Vazio significa "Prefiro não informar".
  final String pronouns;
  final bool includeInPdf;

  /// Local-only scope; prevents using a previous account's treatment choice.
  final String? conversationScope;

  String address({required String neutral, required String feminine, required String masculine, required String inclusive}) {
    switch (pronouns.trim().toLowerCase()) {
      case 'ela/dela': return feminine;
      case 'ele/dele': return masculine;
      case 'elu/delu': return inclusive;
      default: return neutral;
    }
  }

  bool get hasPronouns => pronouns.trim().isNotEmpty;

  TreatmentPreferences copyWith({String? pronouns, bool? includeInPdf}) {
    return TreatmentPreferences(
      pronouns: pronouns ?? this.pronouns,
      includeInPdf: includeInPdf ?? this.includeInPdf,
      conversationScope: conversationScope,
    );
  }

  Map<String, dynamic> toJson() => {
        'pronouns': pronouns,
        'includeInPdf': includeInPdf,
        if (conversationScope != null) 'conversationScope': conversationScope,
      };

  factory TreatmentPreferences.fromJson(Map<String, dynamic> json) {
    return TreatmentPreferences(
      pronouns: json['pronouns'] as String? ?? '',
      includeInPdf: json['includeInPdf'] as bool? ?? false,
      conversationScope: json['conversationScope'] as String?,
    );
  }
}
