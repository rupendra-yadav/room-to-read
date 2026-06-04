import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:room_to_read/services/offline_database_service.dart';
import 'package:room_to_read/services/connectivity_service.dart';
import 'package:room_to_read/services/offline_sync_service.dart';
import 'package:room_to_read/models/book_model.dart';
import 'package:room_to_read/models/student_model.dart';
import 'package:sqflite/sqflite.dart';

class EnhancedOfflineService extends GetxService {
  final OfflineDatabaseService _offlineDb = Get.find<OfflineDatabaseService>();
  final ConnectivityService _connectivityService =
      Get.find<ConnectivityService>();

  final RxBool isOfflineMode = false.obs;
  final RxString offlineStatus = 'ऑनलाइन'.obs;
  final RxInt pendingTransactions = 0.obs;

  @override
  void onInit() {
    super.onInit();

    // Listen to connectivity changes
    ever(_connectivityService.isOnline, (isOnline) {
      isOfflineMode.value = !isOnline;
      offlineStatus.value = isOnline ? 'ऑनलाइन' : 'ऑफलाइन';
      _updatePendingTransactions();

      // Show user-friendly offline status
      if (!isOnline) {
        Get.snackbar(
          'ऑफलाइन मोड सक्रिय',
          'आप ऑफलाइन हैं। सभी चेकइन/चेकआउट स्थानीय रूप से सेव होंगे।',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.orange.shade100,
          duration: const Duration(seconds: 4),
        );
      }
    });

    // Initialize offline mode status
    isOfflineMode.value = !_connectivityService.isOnline.value;
    offlineStatus.value = _connectivityService.isOnline.value
        ? 'ऑनलाइन'
        : 'ऑफलाइन';
    _updatePendingTransactions();
  }

  // Enhanced Books Management - Fully Offline Capable
  Future<List<Book>> getBooks({String? search}) async {
    try {
      print('📚 Enhanced Offline: Getting books (search: $search)');

      final offlineBooks = await _offlineDb.getBooksOffline(search: search);
      print('📱 Found ${offlineBooks.length} books in offline storage');

      if (offlineBooks.isEmpty) {
        print('⚠️ No offline books found');
        return [];
      }

      // Convert to Book objects
      final books = offlineBooks.map((data) {
        // Debug logging for the first few books
        if (offlineBooks.indexOf(data) < 3) {
          print('🔍 Raw offline data for book ${data['name']}:');
          print('   txt2 (total): "${data['txt2']}"');
          print('   txt3 (avail): "${data['txt3']}"');
          print('   txt4 (issue): "${data['txt4']}"');
        }

        return Book(
          programCode: data['groupField'] ?? '',
          bookId: data['bookId'] ?? '',
          bookCode: data['code'] ?? '',
          bookName: data['name'] ?? '',
          bookRomanName: data['lname'] ?? '', // Using lname as roman name
          bookLocalName: data['name'] ?? '', // Using name as local name
          authorName: data['lname'] ?? '',
          totalCopy: int.tryParse(data['txt2'] ?? '0') ?? 0,
          availableCopy: int.tryParse(data['txt3'] ?? '0') ?? 0,
          issuedCopy: int.tryParse(data['txt4'] ?? '0') ?? 0,
          damagedCopy: int.tryParse(data['txt5'] ?? '0') ?? 0,
          lostCopy: 0, // Default value
          returnedCopy: 0, // Default value
          isActive: data['bt']?.toString().toLowerCase() != 'false',
          readingLevel: 0,
        );
      }).toList();

      print('✅ Enhanced Offline: Returning ${books.length} books');
      return books;
    } catch (e) {
      print('❌ Enhanced Offline: Error getting books: $e');
      return [];
    }
  }

  // Enhanced Students Management - Fully Offline Capable
  Future<List<Student>> getStudents({String? teacherId}) async {
    try {
      print('👥 Enhanced Offline: Getting students (teacherId: $teacherId)');

      final offlineStudents = await _offlineDb.getStudentsOffline(
        teacherId: teacherId,
      );
      print('📱 Found ${offlineStudents.length} students in offline storage');

      if (offlineStudents.isEmpty) {
        print('⚠️ No offline students found');
        return [];
      }

      // Convert to Student objects
      final students = offlineStudents
          .map(
            (data) => Student(
              id: data['id'] ?? '',
              code: data['code'] ?? '',
              name: data['name'] ?? '',
              className: data['className'] ?? '',
              readingLevel: data['readingLevel'] ?? 0,
              booksIssued: data['booksIssued'] ?? 0,
              lastUpdated:
                  DateTime.tryParse(data['lastUpdated'] ?? '') ??
                  DateTime.now(),
              previousLevel: data['previousLevel'] ?? 0,
              teacherId: data['teacherId'] ?? '',
              currentLevel: data['currentLevel'] ?? 0,
            ),
          )
          .toList();

      print('✅ Enhanced Offline: Returning ${students.length} students');
      return students;
    } catch (e) {
      print('❌ Enhanced Offline: Error getting students: $e');
      return [];
    }
  }

  // Enhanced Checkout - Fully Offline Capable
  Future<Map<String, dynamic>> checkout({
    required String teacherId,
    required String bookId,
    required String bookCode,
    required String studentId,
    required String className,
  }) async {
    try {
      print('📤 Enhanced Offline: Processing checkout');
      print(
        '   Teacher: $teacherId, Book: $bookId, Student: $studentId, Class: $className',
      );

      // Always save to offline database first
      final transactionId = await _offlineDb.saveOfflineCheckout(
        teacherId: teacherId,
        bookId: bookId,
        bookCode: bookCode,
        studentId: studentId,
        className: className,
        studentName: null, // Let the method resolve it from database
        bookName: null, // Let the method resolve it from database
      );

      // Update book availability locally
      await _updateBookAvailabilityLocally(bookId, -1);

      // Update student books issued count
      await _updateStudentBooksIssuedLocally(studentId, 1);

      _updatePendingTransactions();

      final message = isOfflineMode.value
          ? 'ऑफलाइन चेकआउट सफल - सिंक के लिए इंतजार में'
          : 'चेकआउट सफल';

      print(
        '✅ Enhanced Offline: Checkout completed - Transaction ID: $transactionId',
      );

      return {
        'success': true,
        'message': message,
        'transactionId': transactionId,
        'offline': isOfflineMode.value,
      };
    } catch (e) {
      print('❌ Enhanced Offline: Checkout error: $e');
      return {'success': false, 'message': 'चेकआउट में त्रुटि: $e'};
    }
  }

  // Enhanced Checkin - Fully Offline Capable
  Future<Map<String, dynamic>> checkin({
    required String bookTransactionCode,
    required String bookCode,
    String? teacherId,
    String? bookId,
    String? studentId,
    String? className,
    String? programId,
    String? schoolId,
  }) async {
    try {
      print('📥 Enhanced Offline: Processing checkin');
      print('   Transaction: $bookTransactionCode, Book: $bookCode');
      print(
        '   Additional fields - teacherId: $teacherId, bookId: $bookId, studentId: $studentId, className: $className',
      );

      // Always save to offline database first
      final transactionId = await _offlineDb.saveOfflineCheckin(
        bookTransactionCode: bookTransactionCode,
        bookCode: bookCode,
        teacherId: teacherId,
        bookId: bookId,
        studentId: studentId,
        className: className,
        programId: programId,
        schoolId: schoolId,
      );

      // Update book availability locally
      await _updateBookAvailabilityLocally(bookCode, 1);

      // Find and update student books issued count
      await _updateStudentBooksIssuedForCheckin(bookTransactionCode);

      _updatePendingTransactions();

      final message = isOfflineMode.value
          ? 'ऑफलाइन चेकइन सफल - सिंक के लिए इंतजार में'
          : 'चेकइन सफल';

      print(
        '✅ Enhanced Offline: Checkin completed - Transaction ID: $transactionId',
      );

      return {
        'success': true,
        'message': message,
        'transactionId': transactionId,
        'offline': isOfflineMode.value,
        'removedFromList':
            true, // Indicate that item should be removed from list
      };
    } catch (e) {
      print('❌ Enhanced Offline: Checkin error: $e');
      return {'success': false, 'message': 'चेकइन में त्रुटि: $e'};
    }
  }

  // Enhanced Reading Level Update - Fully Offline Capable
  Future<Map<String, dynamic>> updateReadingLevel(
    String studentCode,
    int newReadingLevel,
  ) async {
    try {
      print('📈 Enhanced Offline: Updating reading level');
      print('   Student: $studentCode, New Level: $newReadingLevel');

      // Get current student data
      final students = await _offlineDb.getStudentsOffline();
      final student = students.firstWhere(
        (s) => s['code'] == studentCode,
        orElse: () => <String, dynamic>{},
      );

      final oldLevel = student['readingLevel'] ?? 0;

      // Save offline reading level update
      await _offlineDb.saveOfflineReadingLevelUpdate(
        studentCode: studentCode,
        oldLevel: oldLevel,
        newLevel: newReadingLevel,
      );

      // Update student data locally
      await _updateStudentReadingLevelLocally(
        studentCode,
        newReadingLevel,
        oldLevel,
      );

      _updatePendingTransactions();

      final message = isOfflineMode.value
          ? 'ऑफलाइन रीडिंग लेवल अपडेट - सिंक के लिए इंतजार में'
          : 'रीडिंग लेवल अपडेट हुआ';

      print('✅ Enhanced Offline: Reading level updated');

      return {
        'success': true,
        'message': message,
        'offline': isOfflineMode.value,
      };
    } catch (e) {
      print('❌ Enhanced Offline: Reading level update error: $e');
      return {'success': false, 'message': 'रीडिंग लेवल अपडेट में त्रुटि: $e'};
    }
  }

  // ✅ CRITICAL FIX: Get Checked Out Books - Include Both Synced and Unsynced
  // This is the main fix for the offline books not displaying issue
  Future<List<dynamic>> getCheckedOutBooks({
    required String teacherId,
    String? className,
    String? fromDate,
    String? toDate,
    String? search,
  }) async {
    try {
      print('📋 Enhanced Offline: Getting checked out books');
      print(
        '   teacherId: "$teacherId" (length: ${teacherId.length}, type: ${teacherId.runtimeType})',
      );
      print('   className: $className');
      print('   fromDate: $fromDate, toDate: $toDate, search: $search');
      print('   isOfflineMode: ${isOfflineMode.value}');

      // Step 1: Check database connectivity and table existence
      final db = await _offlineDb.database;

      // Verify table exists
      final tableInfo = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='checked_out_books'",
      );
      if (tableInfo.isEmpty) {
        print('❌ checked_out_books table does not exist! Creating it...');
        await _createCheckedOutBooksTable(db);
      }

      // Step 2: Get comprehensive database statistics
      await _logDatabaseStats(db, teacherId);

      // Step 3: Try multiple retrieval strategies
      List<dynamic> checkedOutBooks = [];

      // ✅ STRATEGY 1: Standard query - GET ONLY UNSYNCED BOOKS
      // CRITICAL: Show ONLY books that need to be checked in:
      // - synced=0: Pending offline checkout/checkin transactions
      // - synced=1: Books from server API (already checked in, should NOT appear)
      // DO NOT show synced books in the checkin list
      print('🔍 Strategy 1: Query unsynced books for teacher...');
      try {
        // First, let's see what's in the database
        print('   📊 Checking ALL records in checked_out_books table...');
        final allBooks = await db.query('checked_out_books');
        print('      🔹 TOTAL records in table: ${allBooks.length}');
        for (int i = 0; i < allBooks.length; i++) {
          final book = allBooks[i];
          print(
            '         [$i] Teacher: "${book['teacherId']}", Student: "${book['studentName']}", Book: "${book['bookCode']}", Synced: ${book['synced']}',
          );
        }

        print(
          '   🔍 Querying for: teacherId = "$teacherId" AND (synced = 0 OR synced = 1)',
        );
        checkedOutBooks = await db.query(
          'checked_out_books',
          where: 'teacherId = ? AND (synced = 0 OR synced = 1)',
          whereArgs: [teacherId],
        );
        print(
          '      📊 Found: ${checkedOutBooks.length} books (offline + API) for this teacher',
        );

        // ✅ NEW: Filter out books with consumed checkouts
        if (checkedOutBooks.isNotEmpty) {
          print('   🔍 Filtering out consumed checkouts...');

          // Get all consumed checkouts
          final consumedCheckouts = await db.rawQuery('''
            SELECT DISTINCT book_code, student_id FROM offline_transactions_enhanced
            WHERE transaction_type = 'checkout' AND sync_status = 2
            ''');

          final consumedSet = consumedCheckouts
              .map((c) => '${c['book_code']}_${c['student_id']}')
              .toSet();

          print(
            '      Found ${consumedSet.length} consumed checkouts to exclude',
          );

          // Filter out consumed books
          checkedOutBooks = checkedOutBooks.where((book) {
            final key = '${book['bookCode']}_${book['studentId']}';
            final isConsumed = consumedSet.contains(key);
            if (isConsumed) {
              print(
                '      ⏭️ Filtering out consumed: ${book['bookCode']} (student: ${book['studentId']})',
              );
            }
            return !isConsumed;
          }).toList();

          print(
            '      After filtering: ${checkedOutBooks.length} books remain',
          );
        }

        if (checkedOutBooks.isNotEmpty) {
          print(
            '✅ Strategy 1 SUCCESS: Found ${checkedOutBooks.length} books (offline + API)',
          );
          for (int i = 0; i < checkedOutBooks.length; i++) {
            final book = checkedOutBooks[i];
            print(
              '   [$i] ${book['studentName']} - ${book['bookName']} (${book['bookCode']}) | Synced: ${book['synced']}',
            );
          }
          return _applyFiltersAndValidate(
            checkedOutBooks,
            className,
            fromDate,
            toDate,
            search,
            db,
            teacherId,
          );
        }
      } catch (e) {
        print('⚠️ Strategy 1 failed: $e');
        print('   Stack: $e');
      }

      // Strategy 2: Query unsynced books without other filters (fallback)
      print(
        '🔍 Strategy 2: Query unsynced books without additional filters...',
      );
      try {
        checkedOutBooks = await db.query(
          'checked_out_books',
          where: 'synced = 0',
        );
        print(
          '📊 Strategy 2 returned ${checkedOutBooks.length} unsynced books (total)',
        );

        if (checkedOutBooks.isNotEmpty) {
          // Filter by teacher manually
          checkedOutBooks = checkedOutBooks
              .where((b) => b['teacherId'].toString() == teacherId)
              .toList();
          print('   After teacher filter: ${checkedOutBooks.length} books');

          if (checkedOutBooks.isNotEmpty) {
            print(
              '✅ Strategy 2 SUCCESS: Found unsynced books after manual filtering',
            );
            return _applyFiltersAndValidate(
              checkedOutBooks,
              className,
              fromDate,
              toDate,
              search,
              db,
              teacherId,
            );
          }
        }
      } catch (e) {
        print('⚠️ Strategy 2 failed: $e');
      }

      // Strategy 3: Direct SQL queries with case-insensitive matching
      print('🔍 Strategy 3: Direct SQL queries...');
      try {
        // Try case-insensitive match for all books
        var results = await db.rawQuery(
          'SELECT * FROM checked_out_books WHERE LOWER(teacherId) = LOWER(?)',
          [teacherId],
        );
        print('   Case-insensitive match: ${results.length} records');

        if (results.isEmpty) {
          // Try partial match for teacher
          results = await db.rawQuery(
            'SELECT * FROM checked_out_books WHERE (teacherId LIKE ? OR teacherId LIKE ?)',
            ['%$teacherId%', '$teacherId%'],
          );
          print('   Partial match: ${results.length} records');
        }

        if (results.isNotEmpty) {
          checkedOutBooks = results;
          print('✅ Strategy 3 SUCCESS: Found books using SQL queries');
          return _applyFiltersAndValidate(
            checkedOutBooks,
            className,
            fromDate,
            toDate,
            search,
            db,
            teacherId,
          );
        }
      } catch (e) {
        print('⚠️ Strategy 3 failed: $e');
      }

      // Strategy 4: Check for pending offline transactions
      print('🔍 Strategy 4: Checking pending offline transactions...');
      try {
        print('📊 Strategy 4: Teacher ID being queried: $teacherId');

        // Log what's actually in the transaction tables
        final allEnhacedCheckouts = await db.query(
          'offline_transactions_enhanced',
          where: 'transaction_type = ?',
          whereArgs: ['checkout'],
        );
        print(
          '   Total checkout transactions in DB (all teachers): ${allEnhacedCheckouts.length}',
        );
        for (var t in allEnhacedCheckouts) {
          print(
            '      - Teacher: ${t['teacher_id']}, Book: ${t['book_code']}, Status: ${t['sync_status']}',
          );
        }

        checkedOutBooks = await _getCheckedOutBooksFromTransactions(
          db,
          teacherId,
        );
        print(
          '📊 Strategy 4 found ${checkedOutBooks.length} books from transactions',
        );

        if (checkedOutBooks.isNotEmpty) {
          print('✅ Strategy 4 SUCCESS: Found books from pending transactions');
          for (var book in checkedOutBooks) {
            print(
              '   - ${book['bookName']} (${book['bookCode']}) for ${book['studentName']}',
            );
          }
          return _applyFiltersAndValidate(
            checkedOutBooks,
            className,
            fromDate,
            toDate,
            search,
            db,
            teacherId,
          );
        } else {
          print(
            '❌ Strategy 4: No books found from transactions for teacher $teacherId',
          );
        }
      } catch (e) {
        print('⚠️ Strategy 4 failed: $e');
        print('   Stack trace: $e');
      }

      // Final result logging
      print(
        'ℹ️ Enhanced Offline: No checked out books found - this is normal if no books are currently checked out',
      );
      await _logTroubleshootingInfo(db, teacherId);

      return [];
    } catch (e) {
      print('❌ Enhanced Offline: Error getting checked out books: $e');
      print('   Stack trace: ${e.toString()}');
      return [];
    }
  }

  // ✅ NEW: Apply filters and validate data quality
  Future<List<dynamic>> _applyFiltersAndValidate(
    List<dynamic> books,
    String? className,
    String? fromDate,
    String? toDate,
    String? search,
    Database db,
    String teacherId,
  ) async {
    try {
      var filtered = books;

      for (final b in books.take(5)) {
        print(
          'DEBUG CLASS -> F4_TXT2=${b['F4_TXT2']} | F4_TXT1=${b['F4_TXT1']} | className=${b['className']}',
        );
      }

      // Apply class filter
      if (className != null && className.isNotEmpty) {
        filtered = filtered.where((b) {
          final bookClass =
              (b['F4_TXT2'] ??
                      b['F4_TXT1'] ??
                      b['className'] ??
                      b['class'] ??
                      '')
                  .toString()
                  .trim();

          print('📚 Grade Filter: bookClass="$bookClass" filter="$className"');

          return bookClass == className;
        }).toList();

        print('📚 After grade filter: ${filtered.length}/${books.length}');
      }

      // Apply search filter
      if (search != null && search.isNotEmpty) {
        final query = search.toLowerCase();

        filtered = filtered.where((b) {
          return (b['studentName'] ?? '').toString().toLowerCase().contains(
                query,
              ) ||
              (b['bookName'] ?? '').toString().toLowerCase().contains(query) ||
              (b['bookCode'] ?? '').toString().toLowerCase().contains(query);
        }).toList();
      }

      // Apply from date filter
      if (fromDate != null && fromDate.isNotEmpty) {
        filtered = filtered.where((b) {
          try {
            final rawDate =
                b['F4_DATE1']?.toString() ??
                b['checkoutDate']?.toString() ??
                b['F4_DATE']?.toString() ??
                '';

            if (rawDate.isEmpty) return true;

            final normalized = rawDate.trim().replaceFirst(' ', 'T');

            final bookDate = DateTime.tryParse(normalized);

            if (bookDate == null) return true;

            final bookDay = DateTime(
              bookDate.year,
              bookDate.month,
              bookDate.day,
            );

            final fromParsed = DateTime.tryParse(fromDate);

            if (fromParsed == null) return true;

            final fromDay = DateTime(
              fromParsed.year,
              fromParsed.month,
              fromParsed.day,
            );

            return !bookDay.isBefore(fromDay);
          } catch (e) {
            return true;
          }
        }).toList();
      }

      // Apply to date filter
      if (toDate != null && toDate.isNotEmpty) {
        filtered = filtered.where((b) {
          try {
            final rawDate =
                b['F4_DATE1']?.toString() ??
                b['checkoutDate']?.toString() ??
                b['F4_DATE']?.toString() ??
                '';

            if (rawDate.isEmpty) return true;

            final normalized = rawDate.trim().replaceFirst(' ', 'T');

            final bookDate = DateTime.tryParse(normalized);

            if (bookDate == null) return true;

            final bookDay = DateTime(
              bookDate.year,
              bookDate.month,
              bookDate.day,
            );

            final toParsed = DateTime.tryParse(toDate);

            if (toParsed == null) return true;

            final toDay = DateTime(toParsed.year, toParsed.month, toParsed.day);

            return !bookDay.isAfter(toDay);
          } catch (e) {
            return true;
          }
        }).toList();
      }

      // Add API-style field names to all books for UI compatibility
      final booksWithApiFields = filtered.map((book) {
        final bookMap = Map<String, dynamic>.from(book as Map);

        // Decode rawData safely
        final rawDataString = bookMap['rawData']?.toString();

        Map<String, dynamic> rawData = {};

        if (rawDataString != null && rawDataString.isNotEmpty) {
          try {
            rawData = jsonDecode(rawDataString);
          } catch (_) {}
        }

        // API compatibility fields
        bookMap['F4_PARTYN'] =
            bookMap['F4_PARTYN'] ??
            rawData['F4_PARTYN'] ??
            bookMap['bookName'] ??
            '';

        bookMap['F4_PARTY1N'] =
            bookMap['F4_PARTY1N'] ??
            rawData['F4_PARTY1N'] ??
            bookMap['studentName'] ??
            '';

        bookMap['F4_LCODE'] =
            bookMap['F4_LCODE'] ??
            rawData['F4_LCODE'] ??
            bookMap['bookCode'] ??
            '';

        // 🔥 FIXED: Restore class/grade fields from rawData
        bookMap['F4_TXT1'] =
            bookMap['F4_TXT1'] ??
            rawData['F4_TXT1'] ??
            bookMap['className'] ??
            '';

        bookMap['F4_TXT2'] =
            bookMap['F4_TXT2'] ??
            rawData['F4_TXT2'] ??
            bookMap['className'] ??
            '';

        // Clean invalid string "null"
        if (bookMap['F4_TXT1']?.toString() == 'null') {
          bookMap['F4_TXT1'] = null;
        }

        if (bookMap['F4_TXT2']?.toString() == 'null') {
          bookMap['F4_TXT2'] = null;
        }

        return bookMap;
      }).toList();

      print(
        '✅ Enhanced Offline: Successfully found ${booksWithApiFields.length} checked out books (after filters)',
      );

      _logSampleBooks(booksWithApiFields);

      await _validateCheckedOutBooksData(booksWithApiFields);

      return booksWithApiFields;
    } catch (e) {
      print('❌ Error applying filters and validation: $e');

      return books;
    }
  }

  // Helper method to validate checked out books data quality
  Future<void> _validateCheckedOutBooksData(List<dynamic> books) async {
    try {
      int validBooks = 0;
      int invalidBooks = 0;

      for (final book in books) {
        final studentName = book['studentName']?.toString() ?? '';
        final bookName = book['bookName']?.toString() ?? '';
        final bookCode = book['bookCode']?.toString() ?? '';

        if (studentName.isNotEmpty &&
            bookName.isNotEmpty &&
            bookCode.isNotEmpty &&
            studentName != 'Unknown Student' &&
            bookName != 'Unknown Book') {
          validBooks++;
        } else {
          invalidBooks++;
        }
      }

      print('📊 Data Quality Check:');
      print('   Valid books: $validBooks');
      print('   Invalid books: $invalidBooks');
    } catch (e) {
      print('❌ Error validating book data: $e');
    }
  }

  // Helper method to create checked_out_books table if missing
  Future<void> _createCheckedOutBooksTable(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS checked_out_books (
          id TEXT PRIMARY KEY,
          teacherId TEXT,
          studentId TEXT,
          studentName TEXT,
          bookId TEXT,
          bookName TEXT,
          bookCode TEXT,
          className TEXT,
          checkoutDate TEXT,
          dueDate TEXT,
          transactionCode TEXT,
          synced INTEGER DEFAULT 0,
          rawData TEXT
        )
      ''');
      print('✅ Created checked_out_books table');
    } catch (e) {
      print('❌ Error creating checked_out_books table: $e');
    }
  }

  // Helper method to log database statistics
  Future<void> _logDatabaseStats(Database db, String teacherId) async {
    try {
      // Count total records
      final totalCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM checked_out_books',
      );
      final total = totalCount.first['count'] as int;

      // Count records for this teacher
      final teacherCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM checked_out_books WHERE teacherId = ?',
        [teacherId],
      );
      final teacher = teacherCount.first['count'] as int;

      // Count by sync status
      final syncedCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM checked_out_books WHERE synced = 1',
      );
      final synced = syncedCount.first['count'] as int;

      final unsyncedCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM checked_out_books WHERE synced = 0',
      );
      final unsynced = unsyncedCount.first['count'] as int;

      print('📊 Database Statistics:');
      print('   Total checked_out_books: $total');
      print('   For teacher $teacherId: $teacher');
      print('   Synced: $synced, Unsynced: $unsynced');
    } catch (e) {
      print('❌ Error getting database stats: $e');
    }
  }

  // Helper method to get checked out books from pending transactions
  Future<List<dynamic>> _getCheckedOutBooksFromTransactions(
    Database db,
    String teacherId,
  ) async {
    try {
      // Look for pending checkout transactions in legacy table
      final transactions = await db.rawQuery(
        '''
        SELECT * FROM offline_transactions 
        WHERE teacherId = ? AND type = 'checkout' AND synced = 0
      ''',
        [teacherId],
      );

      // ✅ NEW: Get all checkin transactions (both pending and synced) to filter out checked-in books
      // CRITICAL FIX: Include sync_status=0 (pending), sync_status=1 (synced), AND sync_status=2 (completed)
      // After offline sync completes, checkins become synced but should still be excluded from the list
      // IMPORTANT: Match by BOTH book_code AND student_id to only exclude the specific student's checkout
      final pendingCheckins = await db.rawQuery(
        '''
        SELECT DISTINCT book_code, student_id FROM offline_transactions_enhanced 
        WHERE teacher_id = ? AND transaction_type = 'checkin' AND sync_status IN (0, 1, 2)
      ''',
        [teacherId],
      );
      final checkedInBookStudents = pendingCheckins
          .map(
            (c) => {
              'book_code': (c['book_code'] ?? '').toString().trim(),
              'student_id': (c['student_id'] ?? '').toString().trim(),
            },
          )
          .where(
            (item) =>
                item['book_code']!.isNotEmpty && item['student_id']!.isNotEmpty,
          )
          .toSet();
      print(
        '   Found ${checkedInBookStudents.length} book-student pairs with checkins (pending or synced, to exclude)',
      );
      for (final item in checkedInBookStudents) {
        print(
          '      - Book: ${item['book_code']}, Student: ${item['student_id']}',
        );
      }

      // Look for pending checkout transactions in ENHANCED table
      // Exclude consumed transactions (sync_status=2) which have been checked in
      var enhancedTransactions = await db.rawQuery(
        '''
        SELECT * FROM offline_transactions_enhanced 
        WHERE teacher_id = ? AND transaction_type = 'checkout' AND sync_status != 2
      ''',
        [teacherId],
      );

      // ✅ NEW: Filter out checkouts that have been checked in offline
      // CRITICAL FIX: Match by BOTH book_code AND student_id to only exclude the specific student's checkout
      // Use trimmed comparison to handle whitespace issues
      enhancedTransactions = enhancedTransactions.where((t) {
        final checkoutCode = (t['book_code'] ?? '').toString().trim();
        final checkoutStudentId = (t['student_id'] ?? '').toString().trim();

        final isCheckedIn = checkedInBookStudents.any(
          (item) =>
              item['book_code'] == checkoutCode &&
              item['student_id'] == checkoutStudentId,
        );

        if (isCheckedIn && checkoutCode.isNotEmpty) {
          print(
            '   ⏭️ Filtering out checked-in book: code="$checkoutCode", student="$checkoutStudentId"',
          );
        }
        return !isCheckedIn;
      }).toList();

      print(
        '   Found ${transactions.length} legacy and ${enhancedTransactions.length} enhanced pending checkout transactions (after filtering checked-in books)',
      );

      final checkedOutBooks = <Map<String, dynamic>>[];

      // Process legacy transactions
      for (final transaction in transactions) {
        try {
          final data = transaction['data'] as String?;
          if (data != null) {
            final transactionData = Map<String, dynamic>.from(jsonDecode(data));

            final studentName =
                transactionData['student_name']?.toString() ?? '';
            final bookName = transactionData['book_name']?.toString() ?? '';
            final bookCode =
                transaction['F4_CODE']?.toString() ??
                transactionData['F4_CODE']?.toString() ??
                '';

            if (studentName.isEmpty || bookName.isEmpty || bookCode.isEmpty)
              continue;

            final book = {
              'id': transaction['id'],
              'teacherId': transaction['teacherId'],
              'studentId':
                  transaction['studentId'] ??
                  transactionData['student_id'] ??
                  '',
              'studentName': studentName,
              'bookId':
                  transaction['bookId'] ?? transactionData['book_id'] ?? '',
              'bookName': bookName,
              'bookCode': bookCode,
              'className':
                  transaction['className'] ?? transactionData['class'] ?? '',
              'checkoutDate':
                  transaction['timestamp'] ?? DateTime.now().toIso8601String(),
              'dueDate': DateTime.now()
                  .add(const Duration(days: 14))
                  .toIso8601String(),
              'transactionCode': '1',
              'synced': 0,
              'rawData': data,
              // API-style field names for UI compatibility
              'F4_PARTYN': bookName,
              'F4_PARTY1N': studentName,
              'F4_LCODE': bookCode,
              'F4_TXT1':
                  transaction['className'] ?? transactionData['class'] ?? '',
            };

            checkedOutBooks.add(book);
          }
        } catch (e) {
          print('⚠️ Error processing legacy transaction: $e');
        }
      }

      // Process enhanced transactions
      for (final transaction in enhancedTransactions) {
        try {
          final rawData = transaction['raw_data'] as String?;
          if (rawData != null) {
            final transactionData = Map<String, dynamic>.from(
              jsonDecode(rawData),
            );

            final studentName =
                transaction['student_name']?.toString() ??
                transactionData['student_name']?.toString() ??
                '';
            final bookName =
                transaction['book_name']?.toString() ??
                transactionData['book_name']?.toString() ??
                '';
            final bookCode =
                transaction['F4_CODE']?.toString() ??
                transactionData['F4_CODE']?.toString() ??
                '';

            if (studentName.isEmpty || bookName.isEmpty || bookCode.isEmpty) {
              print(
                '   ⏭️ Skipping incomplete transaction: student="$studentName", book="$bookName", code="$bookCode"',
              );
              continue;
            }

            final book = {
              'id': transaction['transaction_id'],
              'teacherId': transaction['teacher_id'],
              'studentId': transaction['student_id'],
              'studentName': studentName,
              'bookId': transaction['book_id'],
              'bookName': bookName,
              'bookCode': bookCode,
              'className': transaction['class_name'],
              'checkoutDate': transaction['transaction_date'],
              'dueDate': DateTime.now()
                  .add(const Duration(days: 14))
                  .toIso8601String(),
              'transactionCode': '1',
              'synced': 0,
              'rawData': rawData,
              // API-style field names for UI compatibility
              'F4_PARTYN': bookName,
              'F4_PARTY1N': studentName,
              'F4_LCODE': bookCode,
              'F4_TXT1': transaction['class_name'],
            };

            checkedOutBooks.add(book);
            print('   ✅ Added transaction: $bookName → $studentName');
          }
        } catch (e) {
          print('⚠️ Error processing enhanced transaction: $e');
        }
      }

      if (checkedOutBooks.isNotEmpty) {
        print(
          '✅ Created ${checkedOutBooks.length} valid checked out books from transactions',
        );
      }

      return checkedOutBooks;
    } catch (e) {
      print('❌ Error getting books from transactions: $e');
      return [];
    }
  }

  // Helper method to log sample books
  void _logSampleBooks(List<dynamic> books) {
    print('📋 Sample of found books:');
    for (int i = 0; i < (books.length > 3 ? 3 : books.length); i++) {
      final book = books[i];
      print(
        '   [$i] ${book['bookName']} (${book['bookCode']}) - ${book['studentName']}',
      );
    }
  }

  // Helper method to log troubleshooting information
  Future<void> _logTroubleshootingInfo(Database db, String teacherId) async {
    try {
      print('🔧 Troubleshooting Information:');

      // Check all tables
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      print('   Available tables: ${tables.map((t) => t['name']).toList()}');

      // Check if there are any records in any table for this teacher
      final studentRecords = await db.rawQuery(
        'SELECT COUNT(*) as count FROM students WHERE teacherId = ?',
        [teacherId],
      );
      final studentCount = studentRecords.first['count'] as int;

      final bookRecords = await db.rawQuery(
        'SELECT COUNT(*) as count FROM books',
      );
      final bookCount = bookRecords.first['count'] as int;

      final transactionRecords = await db.rawQuery(
        'SELECT COUNT(*) as count FROM offline_transactions WHERE teacherId = ?',
        [teacherId],
      );
      final transactionCount = transactionRecords.first['count'] as int;

      print('   Students for teacher: $studentCount');
      print('   Total books: $bookCount');
      print('   Transactions for teacher: $transactionCount');

      // Check connectivity
      print(
        '   Connectivity status: ${_connectivityService.isOnline.value ? "Online" : "Offline"}',
      );
      print('   Connection type: ${_connectivityService.connectionType.value}');
    } catch (e) {
      print('❌ Error getting troubleshooting info: $e');
    }
  }

  // Get Classes - Fully Offline Capable
  Future<List<String>> getClasses() async {
    try {
      print('🏫 Enhanced Offline: Getting classes');

      final classes = await _offlineDb.getClassesOffline();

      if (classes.isEmpty) {
        // Return empty list if no cached classes (no fake defaults)
        print('⚠️ Enhanced Offline: No classes cached yet');
        return [];
      }

      print('✅ Enhanced Offline: Found ${classes.length} classes');
      return classes;
    } catch (e) {
      print('❌ Enhanced Offline: Error getting classes: $e');
      return [];
    }
  }

  // Get Book Issue Count - Fully Offline Capable
  Future<Map<String, dynamic>> getBookIssueCount({
    required String teacherId,
  }) async {
    try {
      print('📊 Enhanced Offline: Getting book issue count');

      final db = await _offlineDb.database;

      // Ensure the table exists by trying to query it
      try {
        await db.rawQuery('SELECT COUNT(*) FROM checked_out_books LIMIT 1');
      } catch (e) {
        print('🔧 Creating checked_out_books table...');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS checked_out_books (
            id TEXT PRIMARY KEY,
            teacherId TEXT,
            studentId TEXT,
            studentName TEXT,
            bookId TEXT,
            bookName TEXT,
            bookCode TEXT,
            className TEXT,
            checkoutDate TEXT,
            dueDate TEXT,
            transactionCode TEXT,
            synced INTEGER DEFAULT 1,
            rawData TEXT
          )
        ''');
      }

      // Count active checked out books (F4_BT = '1' means still checked out)
      final result = await db.rawQuery(
        '''
        SELECT COUNT(*) as count 
        FROM checked_out_books 
        WHERE teacherId = ? AND (transactionCode = '1' OR transactionCode IS NULL)
      ''',
        [teacherId],
      );

      final count = result.first['count'] as int;

      print('✅ Enhanced Offline: Found $count active checked out books');

      return {
        'success': true,
        'count': count,
        'offline': true,
        'message': 'ऑफलाइन काउंट',
      };
    } catch (e) {
      print('❌ Enhanced Offline: Error getting book issue count: $e');
      return {'success': false, 'count': 0, 'message': 'Error: $e'};
    }
  }

  // Helper methods for local data updates
  Future<void> _updateBookAvailabilityLocally(String bookId, int change) async {
    try {
      final db = await _offlineDb.database;

      print('📚 Updating book availability locally:');
      print('   bookId: $bookId, change: $change');

      // Get current book data for debugging
      final currentBook = await db.query(
        'books',
        where: 'code = ? OR bookId = ?',
        whereArgs: [bookId, bookId],
        limit: 1,
      );

      if (currentBook.isNotEmpty) {
        final book = currentBook.first;
        final currentAvailable =
            int.tryParse(book['txt3']?.toString() ?? '0') ?? 0;
        final currentIssued =
            int.tryParse(book['txt4']?.toString() ?? '0') ?? 0;

        print('   Current: Available=$currentAvailable, Issued=$currentIssued');
        print(
          '   After update: Available=${currentAvailable + change}, Issued=${currentIssued - change}',
        );
      }

      // Update available copies (decrease when checking out, increase when checking in)
      await db.rawUpdate(
        '''
        UPDATE books 
        SET txt3 = CAST(txt3 AS INTEGER) + ? 
        WHERE code = ? OR bookId = ?
      ''',
        [change, bookId, bookId],
      );

      // Update issued copies (opposite of available - increase when checking out, decrease when checking in)
      await db.rawUpdate(
        '''
        UPDATE books 
        SET txt4 = CAST(txt4 AS INTEGER) + ? 
        WHERE code = ? OR bookId = ?
      ''',
        [-change, bookId, bookId],
      );

      // Verify the update
      final updatedBook = await db.query(
        'books',
        where: 'code = ? OR bookId = ?',
        whereArgs: [bookId, bookId],
        limit: 1,
      );

      if (updatedBook.isNotEmpty) {
        final book = updatedBook.first;
        final newAvailable = int.tryParse(book['txt3']?.toString() ?? '0') ?? 0;
        final newIssued = int.tryParse(book['txt4']?.toString() ?? '0') ?? 0;

        print('✅ Book availability updated locally:');
        print('   New values: Available=$newAvailable, Issued=$newIssued');
      }
    } catch (e) {
      print('❌ Error updating book availability: $e');
    }
  }

  Future<void> _updateStudentBooksIssuedLocally(
    String studentId,
    int change,
  ) async {
    try {
      final db = await _offlineDb.database;

      await db.rawUpdate(
        '''
        UPDATE students 
        SET booksIssued = booksIssued + ? 
        WHERE code = ?
      ''',
        [change, studentId],
      );

      print('✅ Student books issued count updated locally');
    } catch (e) {
      print('❌ Error updating student books issued: $e');
    }
  }

  Future<void> _updateStudentBooksIssuedForCheckin(
    String transactionCode,
  ) async {
    try {
      // Find the student from the transaction and decrease their books issued count
      final db = await _offlineDb.database;

      final result = await db.rawQuery(
        '''
        SELECT studentId FROM offline_transactions 
        WHERE id = ? AND type = 'checkout'
      ''',
        [transactionCode],
      );

      if (result.isNotEmpty) {
        final studentId = result.first['studentId'] as String;
        await _updateStudentBooksIssuedLocally(studentId, -1);
      }
    } catch (e) {
      print('❌ Error updating student books for checkin: $e');
    }
  }

  Future<void> _updateStudentReadingLevelLocally(
    String studentCode,
    int newLevel,
    int oldLevel,
  ) async {
    try {
      final db = await _offlineDb.database;

      await db.rawUpdate(
        '''
        UPDATE students 
        SET readingLevel = ?, previousLevel = ?, lastUpdated = ?
        WHERE code = ?
      ''',
        [newLevel, oldLevel, DateTime.now().toIso8601String(), studentCode],
      );

      print('✅ Student reading level updated locally');
    } catch (e) {
      print('❌ Error updating student reading level: $e');
    }
  }

  Future<void> _updatePendingTransactions() async {
    try {
      final db = await _offlineDb.database;

      final result = await db.rawQuery('''
        SELECT COUNT(*) as count FROM offline_transactions WHERE synced = 0
      ''');

      final count = result.first['count'] as int;
      pendingTransactions.value = count;

      print('📊 Pending transactions: $count');
    } catch (e) {
      print('❌ Error updating pending transactions count: $e');
      pendingTransactions.value = 0;
    }
  }

  // Get offline statistics
  Future<Map<String, dynamic>> getOfflineStats() async {
    try {
      final stats = await _offlineDb.getOfflineStats();

      return {
        'books': stats['books'] ?? 0,
        'students': stats['students'] ?? 0,
        'classes': stats['classes'] ?? 0,
        'checkedOutBooks': stats['checkedOutBooks'] ?? 0,
        'pendingTransactions': stats['pendingTransactions'] ?? 0,
        'isOfflineMode': isOfflineMode.value,
        'offlineStatus': offlineStatus.value,
      };
    } catch (e) {
      print('❌ Error getting offline stats: $e');
      return {
        'books': 0,
        'students': 0,
        'classes': 0,
        'checkedOutBooks': 0,
        'pendingTransactions': 0,
        'isOfflineMode': isOfflineMode.value,
        'offlineStatus': offlineStatus.value,
      };
    }
  }

  // Remove checked-in item from local checked-out books list
  Future<void> removeCheckedInBookFromList(String transactionCode) async {
    try {
      print('🗑️ Enhanced Offline: Removing checked-in book from list');
      print('   Transaction Code: $transactionCode');

      final db = await _offlineDb.database;

      // Remove from checked_out_books table
      final deletedCount = await db.delete(
        'checked_out_books',
        where: 'transactionCode = ? OR id = ?',
        whereArgs: [transactionCode, transactionCode],
      );

      print(
        '✅ Enhanced Offline: Removed $deletedCount item(s) from checked-out books list',
      );
    } catch (e) {
      print('❌ Enhanced Offline: Error removing checked-in book from list: $e');
    }
  }

  // Trigger comprehensive sync of all cached data
  Future<Map<String, dynamic>> syncAllCachedData() async {
    try {
      print('🚀 Enhanced Offline: Triggering comprehensive sync');

      final offlineSyncService = Get.find<OfflineSyncService>();
      final result = await offlineSyncService.syncAllOfflineData();

      print('📊 Comprehensive sync result: $result');
      return result;
    } catch (e) {
      print('❌ Enhanced Offline: Error triggering comprehensive sync: $e');
      return {'success': false, 'message': 'सिंक में त्रुटि: $e'};
    }
  }
}
