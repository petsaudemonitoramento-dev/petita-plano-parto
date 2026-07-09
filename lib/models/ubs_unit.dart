class UbsUnit {
  const UbsUnit({
    required this.code,
    required this.name,
    required this.city,
    required this.state,
    required this.active,
  });

  final String code;
  final String name;
  final String city;
  final String state;
  final bool active;

  factory UbsUnit.fromJson(Map<String, dynamic> json) {
    return UbsUnit(
      code: json['code'] as String,
      name: json['name'] as String,
      city: json['city'] as String,
      state: json['state'] as String,
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'city': city,
        'state': state,
        'active': active,
      };
}
