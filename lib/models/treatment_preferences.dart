/// Preferência opcional de tratamento no Plano de Parto.
///
/// A escolha não define sexo, gênero ou informação clínica. Não é enviada
/// automaticamente para um servidor, e sua presença nos PDFs exige opt-in.
class TreatmentPreferences {
  const TreatmentPreferences({
    required this.pronouns,
    this.includeInPdf = false,
  });

  /// Texto escolhido pela pessoa. Vazio significa "Prefiro não informar".
  final String pronouns;
  final bool includeInPdf;

  bool get hasPronouns => pronouns.trim().isNotEmpty;

  TreatmentPreferences copyWith({String? pronouns, bool? includeInPdf}) {
    return TreatmentPreferences(
      pronouns: pronouns ?? this.pronouns,
      includeInPdf: includeInPdf ?? this.includeInPdf,
    );
  }

  Map<String, dynamic> toJson() => {
        'pronouns': pronouns,
        'includeInPdf': includeInPdf,
      };

  factory TreatmentPreferences.fromJson(Map<String, dynamic> json) {
    return TreatmentPreferences(
      pronouns: json['pronouns'] as String? ?? '',
      includeInPdf: json['includeInPdf'] as bool? ?? false,
    );
  }
}
