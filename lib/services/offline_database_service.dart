import 'dart:convert';
import 'package:room_to_read/services/auth_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:get/get.dart';

class OfflineDatabaseService extends GetxService {
  static const String dbName = 'room_to_read.db';
  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, dbName);

    return openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    print('🔄 Database upgrade: v$oldVersion → v$newVersion');
    if (oldVersion < 3) {
      try {
        // Recreate grades_cache with UNIQUE constraint
        await db.execute('DROP TABLE IF EXISTS grades_cache');
        await db.execute('''
      CREATE TABLE grades_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        cached_at TEXT NOT NULL
      )
    ''');
        print('✅ Recreated grades_cache with UNIQUE constraint');
      } catch (e) {
        print('⚠️ Error upgrading grades_cache: $e');
      }
    }

    if (oldVersion < 2) {
      print(
        '📝 Upgrading to v2: Adding F4_LCODE column to checked_out_books...',
      );
      try {
        // Check if column already exists
        final tableInfo = await db.rawQuery(
          "PRAGMA table_info(checked_out_books)",
        );
        final hasF4LcodeColumn = tableInfo.any(
          (col) => col['name'] == 'F4_LCODE',
        );

        if (!hasF4LcodeColumn) {
          await db.execute(
            'ALTER TABLE checked_out_books ADD COLUMN F4_LCODE TEXT',
          );
          print('✅ Added F4_LCODE column to checked_out_books');
        } else {
          print('ℹ️ F4_LCODE column already exists');
        }
      } catch (e) {
        print('⚠️ Error upgrading database: $e');
      }
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // Students table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS students (
        id TEXT PRIMARY KEY,
        code TEXT UNIQUE,
        name TEXT,
        className TEXT,
        readingLevel INTEGER DEFAULT 0,
        currentLevel INTEGER DEFAULT 0,
        booksIssued INTEGER DEFAULT 0,
        lastUpdated TEXT,
        previousLevel INTEGER DEFAULT 0,
        teacherId TEXT,
        rawData TEXT
      )
    ''');

    // Books table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS books (
        id TEXT PRIMARY KEY,
        code TEXT UNIQUE,
        no TEXT,
        type TEXT,
        name TEXT,
        lname TEXT,
        dt1 TEXT,
        dt2 TEXT,
        bt TEXT,
        groupField TEXT,
        add1 TEXT,
        add2 TEXT,
        add3 TEXT,
        txt1 TEXT,
        txt2 TEXT,
        txt3 TEXT,
        txt4 TEXT,
        txt5 TEXT,
        groupN TEXT,
        bookId TEXT,
        rawData TEXT
      )
    ''');

    // Classes table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS classes (
        id TEXT PRIMARY KEY,
        name TEXT UNIQUE
      )
    ''');

    // Offline transactions (legacy)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS offline_transactions (
        id TEXT PRIMARY KEY,
        teacherId TEXT,
        studentId TEXT,
        studentName TEXT,
        bookId TEXT,
        bookName TEXT,
        bookCode TEXT,
        className TEXT,
        type TEXT,
        timestamp TEXT,
        data TEXT,
        synced INTEGER DEFAULT 0,
        retryCount INTEGER DEFAULT 0,
        lastRetryTime TEXT
      )
    ''');

    // Enhanced offline transactions
    await db.execute('''
      CREATE TABLE IF NOT EXISTS offline_transactions_enhanced (
        transaction_id TEXT PRIMARY KEY,
        teacher_id TEXT,
        student_id TEXT,
        student_name TEXT,
        book_id TEXT,
        book_name TEXT,
        book_code TEXT,
        class_name TEXT,
        transaction_type TEXT,
        transaction_date TEXT,
        raw_data TEXT,
        sync_status INTEGER DEFAULT 0,
        retry_count INTEGER DEFAULT 0,
        last_retry_time TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Checked out books table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS checked_out_books (
        id TEXT PRIMARY KEY,
        teacherId TEXT,
        studentId TEXT,
        studentName TEXT,
        bookId TEXT,
        bookName TEXT,
        bookCode TEXT,
        F4_LCODE TEXT,
        className TEXT,
        checkoutDate TEXT,
        dueDate TEXT,
        transactionCode TEXT,
        synced INTEGER DEFAULT 0,
        rawData TEXT,
        transactionId TEXT
      )
    ''');

    // Reading level updates table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reading_level_updates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_code TEXT,
        old_level INTEGER,
        new_level INTEGER,
        sync_status INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Book status updates table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS book_status_updates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_code TEXT,
        status_type TEXT,
        change_amount INTEGER,
        old_count INTEGER,
        new_count INTEGER,
        reason TEXT,
        teacher_id TEXT,
        transaction_id TEXT,
        sync_status INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // User profile cache table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_profile (
        id TEXT PRIMARY KEY,
        code TEXT UNIQUE,
        name TEXT,
        mobile TEXT,
        email TEXT,
        type TEXT,
        program_code TEXT,
        school_id TEXT,
        school_name TEXT,
        logged_in_at TEXT,
        last_sync_at TEXT,
        raw_data TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // App cache metadata table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_cache (
        cache_key TEXT PRIMARY KEY,
        cache_value TEXT,
        cache_type TEXT,
        created_at TEXT,
        expires_at TEXT,
        is_valid INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
  CREATE TABLE IF NOT EXISTS grades_cache (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE, 
    name TEXT NOT NULL,
    cached_at TEXT NOT NULL
  )
''');

    print('✅ Database initialized successfully');
  }

  // ============= SAVE OPERATIONS =============

  /// Save user profile data to offline database
  Future<void> saveUserProfileOffline(Map<String, dynamic> userData) async {
    try {
      final db = await database;

      await db.insert('user_profile', {
        'id': userData['id'] ?? userData['code'] ?? 'unknown',
        'code': userData['code'] ?? '',
        'name': userData['name'] ?? '',
        'mobile': userData['mobile'] ?? userData['phone'] ?? '',
        'email': userData['email'] ?? '',
        'type': userData['type'] ?? 'user',
        'program_code': userData['program_code'] ?? userData['prg'] ?? '',
        'school_id': userData['school_id'] ?? userData['sch'] ?? '',
        'school_name': userData['school_name'] ?? '',
        'logged_in_at': DateTime.now().toIso8601String(),
        'last_sync_at': DateTime.now().toIso8601String(),
        'raw_data': jsonEncode(userData),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      print('✅ User profile saved to offline database');
    } catch (e) {
      print('❌ Error saving user profile: $e');
    }
  }

  /// Retrieve cached user profile data
  Future<Map<String, dynamic>?> getCachedUserProfile() async {
    try {
      final db = await database;

      final results = await db.query(
        'user_profile',
        limit: 1,
        orderBy: 'logged_in_at DESC',
      );

      if (results.isNotEmpty) {
        print('✅ Retrieved cached user profile: ${results.first['name']}');
        return Map<String, dynamic>.from(results.first);
      }

      return null;
    } catch (e) {
      print('❌ Error retrieving cached user profile: $e');
      return null;
    }
  }

  /// Save cache metadata
  Future<void> saveCacheMetadata(String key, String value, String type) async {
    try {
      final db = await database;

      await db.insert('app_cache', {
        'cache_key': key,
        'cache_value': value,
        'cache_type': type,
        'created_at': DateTime.now().toIso8601String(),
        'expires_at': DateTime.now()
            .add(const Duration(days: 30))
            .toIso8601String(),
        'is_valid': 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      print('❌ Error saving cache metadata: $e');
    }
  }

  /// Get cache metadata
  Future<String?> getCacheMetadata(String key) async {
    try {
      final db = await database;

      final results = await db.query(
        'app_cache',
        where: 'cache_key = ? AND is_valid = 1',
        whereArgs: [key],
        limit: 1,
      );

      if (results.isNotEmpty) {
        return results.first['cache_value'] as String;
      }

      return null;
    } catch (e) {
      print('❌ Error retrieving cache metadata: $e');
      return null;
    }
  }

  /// Check if any offline data exists for the user
  Future<bool> hasOfflineDataCached(String teacherId) async {
    try {
      final db = await database;

      // Check if we have books, students, or classes cached
      final bookCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM books LIMIT 1',
      );

      final studentCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM students WHERE teacherId = ? LIMIT 1',
        [teacherId],
      );

      final classCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM classes LIMIT 1',
      );

      final hasBooks = (bookCount.first['count'] as int) > 0;
      final hasStudents = (studentCount.first['count'] as int) > 0;
      final hasClasses = (classCount.first['count'] as int) > 0;

      final result = hasBooks || hasStudents || hasClasses;

      if (result) {
        print(
          '✅ Offline data cached: books=$hasBooks, students=$hasStudents, classes=$hasClasses',
        );
      }

      return result;
    } catch (e) {
      print('❌ Error checking offline data: $e');
      return false;
    }
  }

  Future<String> saveOfflineCheckout({
    required String teacherId,
    required String bookId,
    required String bookCode,
    required String studentId,
    required String className,
    String? studentName,
    String? bookName,
  }) async {
    try {
      final db = await database;
      // ✅ FIXED: Generate truly unique ID to prevent duplicates with rapid checkouts
      // Use milliseconds + random counter instead of just milliseconds
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = (DateTime.now().microsecond % 1000).toStringAsFixed(0);
      final transactionId = 'checkout_${timestamp}_$random';

      // STRICT VALIDATION: bookId must be numeric (M1_CODE)
      var finalBookId = bookId;
      if (finalBookId.trim().isEmpty) {
        // Try to resolve numeric book ID from bookCode by looking up in books table
        final books = await db.query(
          'books',
          where: 'code = ? OR bookId = ?',
          whereArgs: [bookCode, bookCode],
          limit: 1,
        );
        if (books.isNotEmpty) {
          final resolvedId =
              books.first['bookId']?.toString() ??
              books.first['no']?.toString();
          if (resolvedId != null && resolvedId.isNotEmpty) {
            print('✅ Resolved numeric book ID for checkout: $resolvedId');
            finalBookId = resolvedId;
          } else {
            throw Exception(
              "Could not resolve numeric book ID from bookCode: $bookCode",
            );
          }
        } else {
          throw Exception("Could not find book by code: $bookCode");
        }
      }

      if (finalBookId.toLowerCase() == "null") {
        throw Exception("Invalid bookId: $finalBookId");
      }

      // Resolve student name
      if (studentName == null || studentName.isEmpty) {
        final students = await db.query(
          'students',
          where:
              'code = ? OR id = ? OR code = CAST(? AS TEXT) OR id = CAST(? AS TEXT)',
          whereArgs: [studentId, studentId, studentId, studentId],
        );

        if (students.isNotEmpty) {
          studentName = students.first['name'] as String?;
          print('✅ Found student in DB by ID: $studentId');
        } else {
          // Fallback: If student not found in offline DB, we'll still allow the checkout
          // but without the student name. This prevents the entire checkout from failing.
          studentName = 'Unknown Student';
          print(
            '⚠️  Student $studentId not found in offline DB, using placeholder name',
          );
        }
      }

      // Resolve book name
      if (bookName == null || bookName.isEmpty) {
        final books = await db.query(
          'books',
          where: 'code = ? OR bookId = ? OR no = ?',
          whereArgs: [bookCode, finalBookId, finalBookId],
        );

        if (books.isNotEmpty) {
          bookName = books.first['name'] as String?;
          print('✅ Found book in DB: $bookCode');
        } else {
          // ✅ IMPROVED: Use fallback name instead of throwing
          // This allows offline checkout even if book isn't cached
          bookName = 'Book - $bookCode';
          print(
            '⚠️  Book $bookCode not found in offline DB, using placeholder name: "$bookName"',
          );
        }
      }

      // ✅ NEW: Get F4_LCODE (numeric book code) from books table for display
      String f4Lcode = bookCode; // Default to bookCode if lookup fails
      try {
        final books = await db.query(
          'books',
          where: 'code = ? OR bookId = ? OR no = ?',
          whereArgs: [bookCode, finalBookId, finalBookId],
          limit: 1,
        );

        if (books.isNotEmpty) {
          // Try to get the numeric book code (F4_LCODE)
          final f4LcodeFromDb =
              books.first['bookId']?.toString() ??
              books.first['no']?.toString() ??
              books.first['code']?.toString();
          if (f4LcodeFromDb != null && f4LcodeFromDb.isNotEmpty) {
            f4Lcode = f4LcodeFromDb;
            print('✅ Resolved F4_LCODE for offline checkout: $f4Lcode');
          }
        }
      } catch (e) {
        print('⚠️ Could not resolve F4_LCODE: $e');
      }

      // Get program and school
      String programId = '2014';
      String schoolId = '3898';

      try {
        final authService = Get.find<AuthService>();
        final currentUser = authService.currentUser.value;
        if (currentUser != null) {
          programId = currentUser.group; // ✅ M1_GROUP1 = program_id
          schoolId = currentUser.group1; // ✅ M1_GROUP = school_id
        }
      } catch (_) {}

      final rawData = jsonEncode({
        'teacher_id': teacherId,
        'book_id': finalBookId,
        'student_id': studentId,
        'class': className,
        'program_id': programId,
        'school_id': schoolId,
      });

      await db.insert('offline_transactions_enhanced', {
        'transaction_id': transactionId,
        'teacher_id': teacherId,
        'student_id': studentId,
        'student_name': studentName,
        'book_id': finalBookId,
        'book_name': bookName,
        'book_code': bookCode,
        'class_name': className,
        'transaction_type': 'checkout',
        'transaction_date': DateTime.now().toIso8601String(),
        'raw_data': rawData,
        'sync_status': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await db.insert('checked_out_books', {
        'id': transactionId,
        'teacherId': teacherId,
        'studentId': studentId,
        'studentName': studentName,
        'bookId': bookId,
        'bookName': bookName,
        'bookCode': bookCode,
        'F4_LCODE':
            f4Lcode, // ✅ FIXED: Store resolved F4_LCODE (numeric book code) for display
        'className': className,
        'checkoutDate': DateTime.now().toIso8601String(),
        'dueDate': DateTime.now()
            .add(const Duration(days: 14))
            .toIso8601String(),
        'transactionCode': '1',
        'synced': 0,
        'transactionId': transactionId,
      });

      print("✅ Offline checkout saved: $transactionId");
      return transactionId;
    } catch (e) {
      print("❌ saveOfflineCheckout error: $e");
      rethrow;
    }
  }

  Future<String> saveOfflineCheckin({
    required String bookTransactionCode,
    required String bookCode,
    String? teacherId,
    String? bookId,
    String? studentId,
    String? className,
    String? studentName,
    String? bookName,
    String? programId,
    String? schoolId,
  }) async {
    try {
      final db = await database;
      // ✅ FIXED: Generate truly unique ID to prevent duplicates with rapid checkins
      // Use milliseconds + microseconds for micro-level uniqueness
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = (DateTime.now().microsecond % 1000).toStringAsFixed(0);
      final transactionId = 'checkin_${timestamp}_$random';

      // Use provided values or defaults
      studentName ??= 'Student';
      bookName ??= 'Book';

      // Validating book ID (should be numeric) - if empty, try to resolve from bookCode
      var finalBookId = bookId ?? '';
      if (finalBookId.trim().isEmpty) {
        // Try to resolve numeric book ID from bookCode by looking up in books table
        final books = await db.query(
          'books',
          where: 'code = ? OR bookId = ?',
          whereArgs: [bookCode, bookCode],
          limit: 1,
        );
        if (books.isNotEmpty) {
          finalBookId =
              books.first['bookId']?.toString() ??
              books.first['no']?.toString() ??
              '';
          if (finalBookId.isNotEmpty) {
            print('✅ Resolved numeric book ID from bookCode: $finalBookId');
          } else {
            // Fallback: use bookCode if lookup fails (not ideal but better than null)
            finalBookId = bookCode;
            print(
              '⚠️ Could not resolve numeric book ID, using bookCode as fallback: $finalBookId',
            );
          }
        } else {
          // Fallback: use bookCode if lookup fails (not ideal but better than null)
          finalBookId = bookCode;
          print(
            '⚠️ Could not find book in database, using bookCode as fallback: $finalBookId',
          );
        }
      }

      if (finalBookId.trim().isEmpty || finalBookId.toLowerCase() == "null") {
        throw Exception("Invalid bookId: $finalBookId");
      }

      // Save to enhanced transactions table
      // ✅ bookId should be Numeric ID
      final rawData = jsonEncode({
        'F4_BT': bookTransactionCode,
        'F4_LCODE': bookCode, // M1_CODE/book code
        'teacher_id': teacherId,
        'book_id': finalBookId, // ✅ Numeric ID (API expects this)
        'student_id': studentId,
        'student_name': studentName,
        'book_name': bookName,
        'class': className,
        'program_id': programId,
        'school_id': schoolId,
      });

      await db.insert('offline_transactions_enhanced', {
        'transaction_id': transactionId,
        'teacher_id': teacherId,
        'student_id': studentId,
        'student_name': studentName,
        'book_id': finalBookId,
        'book_name': bookName,
        'book_code': bookCode,
        'class_name': className,
        'transaction_type': 'checkin',
        'transaction_date': DateTime.now().toIso8601String(),
        'raw_data': rawData,
        'sync_status': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      print('✅ Offline checkin saved: $transactionId');
      print('   book_id: $finalBookId (M1_CODE)');

      // ✅ CRITICAL: Do NOT delete from checked_out_books during offline checkin
      // Deleting here can cause the "all data removed" bug if studentId/teacherId are empty (fallback deletes by bookCode only)
      // Instead, let the filtering logic in enhanced_offline_service exclude checked-in books from display
      // After sync completes successfully, the cleanup code in offline_sync_service.dart will delete from checked_out_books
      // This ensures:
      // 1. Offline: UI filtering excludes books with pending checkins
      // 2. After sync: Cleanup removes them from DB
      // 3. No risk of deleting other students' checkouts (the ALL DATA bug)

      return transactionId;
    } catch (e) {
      print('❌ Error saving offline checkin: $e');
      throw e;
    }
  }

  // ============= RETRIEVE OPERATIONS =============

  Future<List<Map<String, dynamic>>> getPendingOfflineTransactions() async {
    try {
      final db = await database;

      final enhanced = await db.query(
        'offline_transactions_enhanced',
        where: 'sync_status = ?',
        whereArgs: [0],
      );

      print(
        '📊 Found ${enhanced.length} pending transactions in enhanced table',
      );
      return enhanced;
    } catch (e) {
      print('❌ Error getting pending transactions: $e');
      return [];
    }
  }

  // ============= SYNC OPERATIONS =============

  Future<void> markOfflineTransactionSynced(String transactionId) async {
    try {
      final db = await database;

      await db.update(
        'offline_transactions_enhanced',
        {'sync_status': 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'transaction_id = ?',
        whereArgs: [transactionId],
      );

      print('✅ Marked transaction as synced: $transactionId');
    } catch (e) {
      print('❌ Error marking transaction as synced: $e');
    }
  }

  Future<void> markCheckinSynced(
    String transactionId,
    Map<String, dynamic> transaction,
  ) async {
    try {
      final db = await database;

      print('🔍 Marking checkin as synced: $transactionId');

      await db.update(
        'offline_transactions_enhanced',
        {'sync_status': 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'transaction_id = ?',
        whereArgs: [transactionId],
      );

      final bookCode =
          transaction['book_code'] ?? transaction['bookCode'] ?? '';
      final studentId =
          transaction['student_id'] ?? transaction['studentId'] ?? '';

      if (bookCode.isNotEmpty) {
        int totalRemoved = 0;

        if (studentId.isNotEmpty) {
          final removed1 = await db.delete(
            'checked_out_books',
            where: 'bookCode = ? AND studentId = ?',
            whereArgs: [bookCode, studentId],
          );
          totalRemoved += removed1;
          print('   Strategy 1 (bookCode + studentId): Removed $removed1');
        }

        if (totalRemoved == 0) {
          final removed2 = await db.delete(
            'checked_out_books',
            where: 'bookCode = ?',
            whereArgs: [bookCode],
          );
          totalRemoved += removed2;
          print('   Strategy 2 (bookCode): Removed $removed2');
        }

        final removed3 = await db.delete(
          'checked_out_books',
          where: 'transactionId = ?',
          whereArgs: [transactionId],
        );
        totalRemoved += removed3;
        print('   Strategy 3 (transactionId): Removed $removed3');

        if (totalRemoved > 0) {
          print('✅ Removed $totalRemoved from checked_out_books');
        }
      }
    } catch (e) {
      print('❌ Error marking checkin as synced: $e');
    }
  }

  Future<void> deleteSyncedTransactions({int retentionMinutes = 15}) async {
    try {
      final db = await database;

      final cutoffTime = DateTime.now().subtract(
        Duration(minutes: retentionMinutes),
      );

      final deletedEnhanced = await db.delete(
        'offline_transactions_enhanced',
        where: 'sync_status = ? AND created_at < ?',
        whereArgs: [1, cutoffTime.toIso8601String()],
      );

      print(
        '🧹 Deleted $deletedEnhanced old synced transactions (retention: $retentionMinutes min)',
      );
    } catch (e) {
      print('❌ Error deleting synced transactions: $e');
    }
  }

  // ============= OFFLINE STATS =============

  Future<Map<String, dynamic>> getOfflineStats() async {
    try {
      final db = await database;

      final students = await db.rawQuery(
        'SELECT COUNT(*) as count FROM students',
      );
      final books = await db.rawQuery('SELECT COUNT(*) as count FROM books');
      final classes = await db.rawQuery(
        'SELECT COUNT(*) as count FROM classes',
      );
      final checkedOut = await db.rawQuery(
        'SELECT COUNT(*) as count FROM checked_out_books WHERE synced = 0',
      );
      final transactions = await db.rawQuery(
        'SELECT COUNT(*) as count FROM offline_transactions_enhanced WHERE sync_status = 0',
      );

      return {
        'students': (students.first['count'] as int?) ?? 0,
        'books': (books.first['count'] as int?) ?? 0,
        'classes': (classes.first['count'] as int?) ?? 0,
        'checkedOutBooks': (checkedOut.first['count'] as int?) ?? 0,
        'pendingTransactions': (transactions.first['count'] as int?) ?? 0,
        'pendingReadingLevelUpdates': 0,
      };
    } catch (e) {
      print('❌ Error getting offline stats: $e');
      return {
        'students': 0,
        'books': 0,
        'classes': 0,
        'checkedOutBooks': 0,
        'pendingTransactions': 0,
        'pendingReadingLevelUpdates': 0,
      };
    }
  }

  // ============= SAVE METHODS =============

  Future<void> saveStudentsOffline(List<Map<String, dynamic>> students) async {
    try {
      final db = await database;

      for (final student in students) {
        await db.insert('students', {
          'id': student['id'] ?? student['M1_NO'] ?? '',
          'code': student['code'] ?? student['M1_CODE'] ?? '',
          'name': student['name'] ?? student['M1_NAME'] ?? '',
          'className': student['className'] ?? student['M1_GROUP2N'] ?? '',
          'readingLevel':
              int.tryParse(student['readingLevel']?.toString() ?? '0') ?? 0,
          'currentLevel':
              int.tryParse(student['currentLevel']?.toString() ?? '0') ?? 0,
          'booksIssued':
              int.tryParse(student['booksIssued']?.toString() ?? '0') ?? 0,
          'lastUpdated':
              student['lastUpdated'] ?? DateTime.now().toIso8601String(),
          'teacherId': student['teacherId'] ?? student['M1_GROUP2'] ?? '',
          'rawData': jsonEncode(student),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      print('✅ Saved ${students.length} students offline');
    } catch (e) {
      print('❌ Error saving students: $e');
    }
  }

  Future<void> saveBooksOffline(List<Map<String, dynamic>> books) async {
    try {
      print('🔥 DEBUG: saveBooksOffline() called with ${books.length} books');
      if (books.isNotEmpty) {
        print('   First book: ${books[0].keys.toList()}');
        print(
          '   Sample code value: ${books[0]['code']}, book_code: ${books[0]['book_code']}, bookId: ${books[0]['bookId']}',
        );
      }
      final db = await database;

      final usedIds = <String>{};
      final usedCodes = <String>{};

      for (int index = 0; index < books.length; index++) {
        final book = books[index];

        // ✅ FIXED: Use bookId or book_id (numeric ID) - this is what hybrid_api_service sends
        // IMPORTANT: Empty string is NOT null in Dart, so check explicitly
        String uniqueId = '';

        if ((book['bookId']?.toString() ?? '').isNotEmpty) {
          uniqueId = book['bookId'].toString().trim();
        } else if ((book['book_id']?.toString() ?? '').isNotEmpty) {
          uniqueId = book['book_id'].toString().trim();
        } else if ((book['M1_CODE']?.toString() ?? '').isNotEmpty) {
          uniqueId = book['M1_CODE'].toString().trim();
        }

        if (uniqueId.isEmpty) {
          print(
            "❌ Skipping book [$index] because numeric ID is missing (bookId/book_id/M1_CODE)",
          );
          continue;
        }

        // Check if already used
        if (usedIds.contains(uniqueId)) {
          print("⚠️ Duplicate book skipped: $uniqueId");
          continue;
        }

        usedIds.add(uniqueId);

        // Code field - use book code if available, fallback to ID
        // IMPORTANT: Empty string is NOT null in Dart, so we must check explicitly
        String uniqueCode = '';

        // Try each field in order, using the first non-empty one
        if ((book['code']?.toString() ?? '').isNotEmpty) {
          uniqueCode = book['code'].toString().trim();
        } else if ((book['book_code']?.toString() ?? '').isNotEmpty) {
          uniqueCode = book['book_code'].toString().trim();
        } else if ((book['M1_NO']?.toString() ?? '').isNotEmpty) {
          uniqueCode = book['M1_NO'].toString().trim();
        } else if ((book['bookId']?.toString() ?? '').isNotEmpty) {
          uniqueCode = book['bookId'].toString().trim();
        } else if ((book['book_id']?.toString() ?? '').isNotEmpty) {
          uniqueCode = book['book_id'].toString().trim();
        } else if ((book['M1_CODE']?.toString() ?? '').isNotEmpty) {
          uniqueCode = book['M1_CODE'].toString().trim();
        }

        print(
          '   🔍 Book[$index] code: final="$uniqueCode", isEmpty=${uniqueCode.isEmpty}',
        );

        if (uniqueCode.isEmpty) {
          print(
            "⚠️ Warning book [$index]: code could not be determined, using ID",
          );
          uniqueCode = uniqueId; // Use the ID as last resort
        }

        if (usedCodes.contains(uniqueCode)) {
          print("⚠️ Duplicate book skipped: $uniqueCode");
          continue;
        }

        usedCodes.add(uniqueCode);

        print(
          '💾 Saving book [$index]: ID=$uniqueId, Code=$uniqueCode, Name=${book['name'] ?? book['book_name'] ?? 'N/A'}',
        );

        try {
          await db.insert('books', {
            'id': uniqueId,
            'code': uniqueCode,
            'no': book['no'] ?? book['bookId'] ?? book['M1_NO'] ?? '',
            'type': book['type'] ?? book['program_code'] ?? '',
            'name': book['name'] ?? book['book_name'] ?? '',
            'lname': book['lname'] ?? book['author_name'] ?? '',
            'dt1': book['dt1'] ?? '',
            'dt2': book['dt2'] ?? '',
            'bt': book['bt']?.toString(),
            'groupField': book['groupField'] ?? '',
            'add1': book['add1'],
            'add2': book['add2'],
            'add3': book['add3'],
            'txt1': book['txt1']?.toString() ?? '0',
            'txt2': book['txt2']?.toString() ?? '0',
            'txt3': book['txt3']?.toString() ?? '0',
            'txt4': book['txt4']?.toString() ?? '0',
            'txt5': book['txt5']?.toString() ?? '0',
            'groupN': book['groupN'] ?? '',
            'bookId': uniqueId, // ✅ FIXED: Use the actual numeric ID
            'rawData': jsonEncode(book),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          print('   ✅ Saved successfully');
        } catch (e) {
          print('   ⚠️ Error saving this book: $e');
        }
      }

      print(
        '✅ Saved ${books.length} books offline (${usedIds.length} unique IDs, ${usedCodes.length} unique codes)',
      );
    } catch (e) {
      print('❌ Error saving books: $e');
    }
  }

  Future<void> saveClassesOffline(List<String> classes) async {
    try {
      final db = await database;

      for (final className in classes) {
        await db.insert('classes', {
          'id': className,
          'name': className,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      print('✅ Saved ${classes.length} classes offline');
    } catch (e) {
      print('❌ Error saving classes: $e');
    }
  }

  Future<void> saveCheckedOutBooksOffline(
    List<Map<String, dynamic>> books,
  ) async {
    try {
      final db = await database;

      // ✅ CRITICAL FIX: Clear old checked-out books before saving new ones from API
      // This ensures that books checked in on the server don't reappear
      // Only clear books with synced=1 (from API), keep synced=0 (offline transactions)
      print('🧹 Clearing old checked-out books from API (synced=1)...');
      final deletedCount = await db.delete(
        'checked_out_books',
        where:
            'synced = 1', // Only delete books from API, keep offline transactions
      );
      print('   ✅ Deleted $deletedCount old books from API');

      // ✅ NEW: Also clear books that have been checked in (marked as consumed)
      // These are books where the original checkout was marked as consumed (sync_status=2)
      print('🧹 Clearing books with consumed checkouts...');
      final consumedCheckouts = await db.rawQuery('''
        SELECT DISTINCT bookCode, studentId, teacherId FROM checked_out_books
        WHERE synced = 0 AND EXISTS (
          SELECT 1 FROM offline_transactions_enhanced
          WHERE transaction_type = 'checkout'
            AND book_code = checked_out_books.bookCode
            AND student_id = checked_out_books.studentId
            AND teacher_id = checked_out_books.teacherId
            AND sync_status = 2
        )
        ''');

      for (final record in consumedCheckouts) {
        final bookCode = record['bookCode'];
        final studentId = record['studentId'];
        final teacherId = record['teacherId'];

        final deletedConsumed = await db.delete(
          'checked_out_books',
          where: 'bookCode = ? AND studentId = ? AND teacherId = ?',
          whereArgs: [bookCode, studentId, teacherId],
        );

        if (deletedConsumed > 0) {
          print(
            '   ✅ Deleted consumed checkout: $bookCode (student: $studentId)',
          );
        }
      }

      // Now save the fresh data from API
      for (final book in books) {
        await db.insert('checked_out_books', {
          'id': book['id'] ?? '${book['F4_LCODE']}_${book['F4_PARTY1N']}',
          'teacherId': book['teacherId'] ?? book['F4_USERADD'] ?? '',
          'studentId': book['studentId'] ?? '',
          'studentName': book['F4_PARTY1N'] ?? book['studentName'] ?? '',
          'bookId': book['bookId'] ?? '',
          'bookName': book['F4_PARTYN'] ?? book['bookName'] ?? '',
          'bookCode': book['F4_LCODE'] ?? book['bookCode'] ?? '',
          'F4_LCODE':
              book['F4_LCODE'] ??
              book['bookCode'] ??
              '', // ✅ NEW: Store F4_LCODE for display
          'className':
              book['F4_TXT2'] ?? book['F4_TXT1'] ?? book['className'] ?? '',
          'checkoutDate': book['F4_USERDT'] ?? book['checkoutDate'] ?? '',
          'dueDate': book['dueDate'] ?? '',
          'transactionCode': book['F4_BT'] ?? '1',
          'synced': 1, // ✅ CRITICAL: Mark as synced=1 (from API, not offline)
          'rawData': jsonEncode(book),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      print(
        '✅ Saved ${books.length} checked-out books offline (from API, synced=1)',
      );
    } catch (e) {
      print('❌ Error saving checked-out books: $e');
    }
  }

  Future<void> clearBooksCache() async {
    try {
      final db = await database;
      final deletedCount = await db.delete('books');
      print('✅ Cleared books cache: Deleted $deletedCount books');
    } catch (e) {
      print('❌ Error clearing books cache: $e');
    }
  }

  // ✅ DEBUG METHOD: Check actual books in database
  Future<void> debugPrintBooksInDatabase() async {
    try {
      final db = await database;
      final allBooks = await db.query('books', limit: 10);
      print('\n🔍 === DATABASE CONTENTS (showing first 10) ===');
      print('Total books in database: ${allBooks.length}');

      if (allBooks.isEmpty) {
        print('⚠️ Database is EMPTY!');
      } else {
        for (int i = 0; i < allBooks.length; i++) {
          final book = allBooks[i];
          print('  Book $i:');
          print('    ID: ${book['id']}');
          print('    Code: ${book['code']}');
          print('    BookId: ${book['bookId']}');
          print('    Name: ${book['name']}');
          print('    Author: ${book['lname']}');
          print('    Available: ${book['txt3']} / Total: ${book['txt2']}');
        }
      }
      print('=== END DATABASE ===\n');
    } catch (e) {
      print('❌ Error debugging database: $e');
    }
  }

  // ============= GET METHODS =============

  Future<List<Map<String, dynamic>>> getStudentsOffline({
    String? teacherId,
  }) async {
    try {
      final db = await database;

      if (teacherId != null && teacherId.isNotEmpty) {
        return await db.query(
          'students',
          where: 'teacherId = ?',
          whereArgs: [teacherId],
        );
      }

      return await db.query('students');
    } catch (e) {
      print('❌ Error getting students: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getBooksOffline({String? search}) async {
    try {
      final db = await database;

      if (search != null && search.isNotEmpty) {
        final results = await db.query(
          'books',
          where:
              'name LIKE ? OR code LIKE ? OR lname LIKE ? OR add1 LIKE ? OR add2 LIKE ?',
          whereArgs: [
            '%$search%',
            '%$search%',
            '%$search%',
            '%$search%',
            '%$search%',
          ],
        );
        print(
          '🔍 Database search for "$search": Found ${results.length} books',
        );
        return results;
      }

      final allBooks = await db.query('books');
      print('📚 Database full query: Retrieved ${allBooks.length} books');
      return allBooks;
    } catch (e) {
      print('❌ Error getting books: $e');
      return [];
    }
  }

  Future<List<String>> getClassesOffline() async {
    try {
      final db = await database;
      final result = await db.query('classes');
      return result.map((c) => c['name'] as String).toList();
    } catch (e) {
      print('❌ Error getting classes: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCheckedOutBooksOffline({
    String? teacherId,
    String? className,
    String? fromDate,
    String? toDate,
    String? search,
  }) async {
    try {
      final db = await database;

      String whereClause = 'synced = 0';
      List<dynamic> whereArgs = [];

      if (teacherId != null && teacherId.isNotEmpty) {
        whereClause += ' AND teacherId = ?';
        whereArgs.add(teacherId);
      }

      if (className != null && className.isNotEmpty) {
        whereClause += ' AND className = ?';
        whereArgs.add(className);
      }

      if (search != null && search.isNotEmpty) {
        whereClause += ' AND (bookName LIKE ? OR studentName LIKE ?)';
        whereArgs.addAll(['%$search%', '%$search%']);
      }

      final books = await db.query(
        'checked_out_books',
        where: whereClause,
        whereArgs: whereArgs,
      );

      return books.map((book) {
        return {
          ...book,
          'F4_PARTYN': book['bookName'] ?? '',
          'F4_PARTY1N': book['studentName'] ?? '',
          'F4_LCODE': book['bookCode'] ?? '',
          'F4_TXT1': book['className'] ?? '',
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting checked out books: $e');
      return [];
    }
  }

  // ============= OFFLINE TRANSACTIONS =============

  Future<List<Map<String, dynamic>>> getOfflineTransactions() async {
    try {
      final db = await database;
      return await db.query(
        'offline_transactions_enhanced',
        orderBy: 'created_at DESC',
      );
    } catch (e) {
      print('❌ Error getting offline transactions: $e');
      return [];
    }
  }

  // ============= READING LEVEL UPDATES =============

  Future<void> saveOfflineReadingLevelUpdate({
    required String studentCode,
    required int oldLevel,
    required int newLevel,
  }) async {
    try {
      final db = await database;

      await db.insert('reading_level_updates', {
        'student_code': studentCode,
        'old_level': oldLevel,
        'new_level': newLevel,
        'sync_status': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      print('✅ Offline reading level update saved');
    } catch (e) {
      print('❌ Error saving reading level update: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getPendingBookStatusUpdates() async {
    try {
      final db = await database;
      return await db.query(
        'book_status_updates',
        where: 'sync_status = ?',
        whereArgs: [0],
      );
    } catch (e) {
      print('❌ Error getting pending book status updates: $e');
      return [];
    }
  }

  Future<void> markBookStatusUpdateSynced(int updateId) async {
    try {
      final db = await database;

      await db.update(
        'book_status_updates',
        {'sync_status': 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [updateId],
      );

      print('✅ Marked book status update as synced: $updateId');
    } catch (e) {
      print('❌ Error marking book status update as synced: $e');
    }
  }

  Future<void> clearOfflineData() async {
    try {
      final db = await database;

      await db.delete('offline_transactions_enhanced');
      await db.delete('offline_transactions');
      await db.delete('checked_out_books');
      await db.delete('reading_level_updates');
      await db.delete('book_status_updates');

      print('✅ Cleared all offline data');
    } catch (e) {
      print('❌ Error clearing offline data: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    try {
      final db = await database;
      return await db.query(
        'offline_transactions_enhanced',
        where: 'sync_status = ?',
        whereArgs: [0],
      );
    } catch (e) {
      print('❌ Error getting pending sync items: $e');
      return [];
    }
  }

  Future<void> markOfflineCheckoutSynced(String transactionId) async {
    try {
      final db = await database;

      await db.update(
        'checked_out_books',
        {'synced': 1},
        where: 'transactionId = ?',
        whereArgs: [transactionId],
      );

      print('✅ Marked checkout as synced: $transactionId');
    } catch (e) {
      print('❌ Error marking checkout as synced: $e');
    }
  }
}
