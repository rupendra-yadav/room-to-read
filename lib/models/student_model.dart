class Student {
  final String id;
  final String code;
  final String name;
  final String className;
  int readingLevel;
  int currentLevel;
  final int booksIssued;
  final DateTime lastUpdated;
  int previousLevel;
  final String teacherId; // M1_GROUP2

  Student({
    required this.id,
    required this.code,
    required this.name,
    required this.className,
    required this.readingLevel,
    required this.currentLevel,
    required this.booksIssued,
    required this.lastUpdated,
    required this.previousLevel,
    required this.teacherId,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    print('Student.fromJson called with: $json');
    // M1_TXT2 is the current reading level, M1_TXT1 is the previous level
    final currentLevel = int.tryParse(json['M1_TXT2']?.toString() ?? '') ?? 0;
    final prevLevel = int.tryParse(json['M1_TXT1']?.toString() ?? '') ?? 0;

    // Use M1_CR for class if available, otherwise use M1_GROUP2N
    final className = json['M1_OPP']?.toString() ?? '';

    // Get teacher ID from M1_GROUP2
    final teacherId = json['M1_GROUP2']?.toString() ?? '';

    final student = Student(
      id: json['M1_NO']?.toString() ?? '',
      code: json['M1_CODE']?.toString() ?? '',
      name: json['M1_NAME']?.toString() ?? '',
      className: className,
      readingLevel: currentLevel,
      currentLevel: currentLevel,
      previousLevel: prevLevel,
      booksIssued: 0,
      lastUpdated: DateTime.now(),
      teacherId: teacherId,
    );
    print(
      'Created student: id=${student.id}, code=${student.code}, name=${student.name}, class=${student.className}, readingLevel=$currentLevel, previousLevel=$prevLevel, teacherId=$teacherId',
    );
    return student;
  }

  Student copyWith({
    String? id,
    String? code,
    String? name,
    String? className,
    int? readingLevel,
    int? currentLevel,
    int? booksIssued,
    DateTime? lastUpdated,
    int? previousLevel,
    String? teacherId,
  }) {
    return Student(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      className: className ?? this.className,
      readingLevel: readingLevel ?? this.readingLevel,
      currentLevel: currentLevel ?? this.currentLevel,
      booksIssued: booksIssued ?? this.booksIssued,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      previousLevel: previousLevel ?? this.previousLevel,
      teacherId: teacherId ?? this.teacherId,
    );
  }
}
