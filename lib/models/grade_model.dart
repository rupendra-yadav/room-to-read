class Grade {
  final String code;
  final String name;

  Grade({required this.code, required this.name});

  factory Grade.fromJson(Map<String, dynamic> json) {
    return Grade(
      code: json['M1_CODE']?.toString() ?? '',
      name: json['M1_NAME']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'M1_CODE': code,
    'M1_NAME': name,
  };

  @override
  String toString() => name;
}