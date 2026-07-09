class ConsentRecord {
  ConsentRecord({
    required this.acceptedTerms,
    required this.acceptedPrivacy,
    required this.acceptedResponsibility,
    required this.termsVersion,
    required this.acceptedAt,
  });

  final bool acceptedTerms;
  final bool acceptedPrivacy;
  final bool acceptedResponsibility;
  final String termsVersion;
  final DateTime acceptedAt;

  Map<String, dynamic> toJson() => {
        'acceptedTerms': acceptedTerms,
        'acceptedPrivacy': acceptedPrivacy,
        'acceptedResponsibility': acceptedResponsibility,
        'termsVersion': termsVersion,
        'acceptedAt': acceptedAt.toIso8601String(),
      };
}
