class ConsentRecord {
  const ConsentRecord({
    required this.acceptedTerms,
    required this.acceptedPrivacy,
    required this.acceptedResponsibility,
    required this.acceptedPlanScience,
    required this.acceptedHealthData,
    required this.termsVersion,
    required this.acceptedAt,
  });

  // Atualizar quando houver mudança material na ciência inicial.
  static const currentVersion = '2026-10-21-v1';

  final bool acceptedTerms;
  final bool acceptedPrivacy;
  final bool acceptedResponsibility;
  final bool acceptedPlanScience;
  final bool acceptedHealthData;
  final String termsVersion;
  final DateTime acceptedAt;

  bool get isCurrentAndComplete =>
      acceptedTerms &&
      acceptedPrivacy &&
      acceptedResponsibility &&
      acceptedPlanScience &&
      acceptedHealthData &&
      termsVersion == currentVersion;

  factory ConsentRecord.fromJson(Map<String, dynamic> json) => ConsentRecord(
        acceptedTerms: json['acceptedTerms'] == true,
        acceptedPrivacy: json['acceptedPrivacy'] == true,
        acceptedResponsibility: json['acceptedResponsibility'] == true,
        acceptedPlanScience: json['acceptedPlanScience'] == true,
        acceptedHealthData: json['acceptedHealthData'] == true,
        termsVersion: json['termsVersion']?.toString() ?? '',
        acceptedAt: DateTime.parse(json['acceptedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'acceptedTerms': acceptedTerms,
        'acceptedPrivacy': acceptedPrivacy,
        'acceptedResponsibility': acceptedResponsibility,
        'acceptedPlanScience': acceptedPlanScience,
        'acceptedHealthData': acceptedHealthData,
        'termsVersion': termsVersion,
        'acceptedAt': acceptedAt.toIso8601String(),
      };
}
