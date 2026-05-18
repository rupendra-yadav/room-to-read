class UserModel {
  final String code;
  final String type;
  final String no;
  final String name;
  final String lname;
  final String dt1;
  final String dt2;
  final String bt;
  final String group;
  final String group1;
  final String tel;
  final String pa;
  final String it;
  final String opp;
  final String sch;
  final String prg;

  UserModel({
    required this.code,
    required this.type,
    required this.no,
    required this.name,
    required this.lname,
    required this.dt1,
    required this.dt2,
    required this.bt,
    required this.group,
    required this.group1,
    required this.tel,
    required this.pa,
    required this.it,
    required this.opp,
    required this.sch,
    required this.prg,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    try {
      // Debug logging to see what fields are available
      print('🔍 UserModel.fromJson - Available fields: ${json.keys.toList()}');
      print(
        '🔍 M1_GROUP value: "${json['M1_GROUP']}" (${json['M1_GROUP'].runtimeType})',
      );
      print(
        '🔍 M1_GROUP1 value: "${json['M1_GROUP1']}" (${json['M1_GROUP1'].runtimeType})',
      );
      print(
        '🔍 program_code value: "${json['program_code']}" (${json['program_code'].runtimeType})',
      );
      print(
        '🔍 school_name value: "${json['school_name']}" (${json['school_name'].runtimeType})',
      );
      print(
        '🔍 school_gsd_id value: "${json['school_gsd_id']}" (${json['school_gsd_id'].runtimeType})',
      );

      final groupValue = _getGroupValue(json);
      print('✅ FINAL group value selected: "$groupValue"');

      // ✅ CRITICAL FIX: The API returns M1_GROUP and M1_GROUP1 with SWAPPED values
      // API returns: M1_GROUP=program_id (2014), M1_GROUP1=school_id (3898)
      // We need: group=school_id (3898), group1=program_id (2014)
      // So we SWAP them when parsing
      final apiM1Group = (json['M1_GROUP'] ?? '').toString();
      final apiM1Group1 = (json['M1_GROUP1'] ?? '').toString();
      
      print('   🔄 SWAPPING M1_GROUP and M1_GROUP1 values:');
      print('      API M1_GROUP: $apiM1Group → will use as group1 (program_id)');
      print('      API M1_GROUP1: $apiM1Group1 → will use as group (school_id)');

      return UserModel(
        code: (json['M1_CODE'] ?? '').toString(),
        type: (json['M1_TYPE'] ?? '').toString(),
        no: (json['M1_NO'] ?? '').toString(),
        name: (json['M1_NAME'] ?? '').toString(),
        lname: (json['M1_LNAME'] ?? '').toString(),
        dt1: (json['M1_DT1'] ?? '').toString(),
        dt2: (json['M1_DT2'] ?? '').toString(),
        bt: (json['M1_BT'] ?? '').toString(),
        group: apiM1Group1, // ✅ SWAP: Use M1_GROUP1 as group (school_id)
        group1: apiM1Group, // ✅ SWAP: Use M1_GROUP as group1 (program_id)
        tel: (json['M1_TEL'] ?? '').toString(),
        pa: (json['M1_PA'] ?? '').toString(),
        it: (json['M1_IT'] ?? '').toString(),
        opp: (json['M1_OPP'] ?? '').toString(),
        // Use M1_GROUP1 as school_id and student_id (dual purpose)
        sch: (json['school_name'] ?? '').toString(),
        prg: (json['program_code'] ?? '').toString(),
        // ✅ FIXED: Use M1_GROUP if available and not empty, otherwise fallback to school_gsd_id or M1_GROUP1
        // group: groupValue,
      );
    } catch (e) {
      print('❌ Error parsing UserModel: $e');
      print('📄 JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'M1_CODE': code,
      'M1_TYPE': type,
      'M1_NO': no,
      'M1_NAME': name,
      'M1_LNAME': lname,
      'M1_DT1': dt1,
      'M1_DT2': dt2,
      'M1_BT': bt,
      'M1_GROUP': group,
      'M1_GROUP1': group1,
      'M1_TEL': tel,
      'M1_PA': pa,
      'M1_IT': it,
      'M1_OPP': opp,
      'school_name': sch,
      'program_code': prg,
    };
  }

  /// ✅ Helper method to extract M1_GROUP with proper fallback logic
  static String _getGroupValue(Map<String, dynamic> json) {
    // Try M1_GROUP first
    final m1Group = json['M1_GROUP']?.toString().trim() ?? '';
    print('   🔍 Checking M1_GROUP: "$m1Group" (empty: ${m1Group.isEmpty})');
    if (m1Group.isNotEmpty) {
      print('   ✅ Using M1_GROUP: $m1Group');
      return m1Group;
    }

    // Fallback to school_gsd_id
    final schoolGsdId = json['school_gsd_id']?.toString().trim() ?? '';
    print(
      '   🔍 Checking school_gsd_id: "$schoolGsdId" (empty: ${schoolGsdId.isEmpty})',
    );
    if (schoolGsdId.isNotEmpty) {
      print('   ⚠️ M1_GROUP empty, using school_gsd_id: $schoolGsdId');
      return schoolGsdId;
    }

    // Last resort: use M1_GROUP1
    final m1Group1 = json['M1_GROUP1']?.toString().trim() ?? '';
    print('   🔍 Checking M1_GROUP1: "$m1Group1" (empty: ${m1Group1.isEmpty})');
    if (m1Group1.isNotEmpty) {
      print(
        '   ⚠️ M1_GROUP and school_gsd_id empty, using M1_GROUP1: $m1Group1',
      );
      return m1Group1;
    }

    print('   ❌ All group fields empty!');
    return '';
  }
}
