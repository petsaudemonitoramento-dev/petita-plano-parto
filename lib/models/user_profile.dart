class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.ubsCode,
    this.ubsName,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String? ubsCode;
  final String? ubsName;
  final DateTime createdAt;

  bool get isPatient => role == 'patient';
  bool get isUbsTeam => role == 'ubs_team';
  bool get isAdmin => role == 'admin';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'ubsCode': ubsCode,
        'ubsName': ubsName,
        'createdAt': createdAt.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      ubsCode: json['ubsCode'] as String?,
      ubsName: json['ubsName'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
