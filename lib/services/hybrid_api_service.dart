import 'dart:convert';

import 'package:get/get.dart';
import 'package:room_to_read/models/book_model.dart';
import 'package:room_to_read/models/grade_model.dart';
import 'package:room_to_read/models/student_model.dart';
import 'package:room_to_read/services/api_service.dart';
import 'package:room_to_read/services/auth_service.dart';
import 'package:room_to_read/services/connectivity_service.dart';
import 'package:room_to_read/services/offline_database_service.dart';
import 'package:room_to_read/services/enhanced_offline_service.dart';
import 'package:sqflite/sqflite.dart';

class HybridApiService extends GetxService {
  final ApiService _apiService = Get.find<ApiService>();
  final ConnectivityService _connectivityService =
      Get.find<ConnectivityService>();
  final OfflineDatabaseService _offlineDb = Get.find<OfflineDatabaseService>();
  final EnhancedOfflineService _enhancedOfflineService =
      Get.find<EnhancedOfflineService>();

  // =========================================================
  // STUDENTS
  // =========================================================

  Future<List<Student>> getStudents({String? group1}) async {
    if (_connectivityService.isOnline.value) {
      try {
        final online = await _apiService.getStudents(group1: group1);
        final students = online
            .map<Student>((e) => e is Student ? e : Student.fromJson(e))
            .toList();

        if (students.isNotEmpty) {
          final db = await _offlineDb.database;
          final localRows = await db.query('students');
          final localMap = {for (var r in localRows) r['code']: r};

          // A student with a pending (not-yet-synced) local reading level
          // change hasn't reached the admin portal yet, so the server value
          // for them is stale — keep the local value until it syncs. For
          // everyone else, the admin portal is the source of truth.
          final pendingUpdates = await _offlineDb
              .getPendingReadingLevelUpdates();
          final pendingCodes = pendingUpdates
              .map((u) => u['student_code'] as String?)
              .whereType<String>()
              .toSet();

          final mergedForSave = <Map<String, dynamic>>[];
          final mergedStudents = <Student>[];

          for (final s in students) {
            final local = localMap[s.code];
            final hasPendingUpdate = pendingCodes.contains(s.code);
            final mergedReadingLevel = hasPendingUpdate
                ? (local?['readingLevel'] as int? ?? s.readingLevel)
                : s.readingLevel;
            final mergedPreviousLevel = hasPendingUpdate
                ? (local?['previousLevel'] as int? ?? s.previousLevel)
                : s.previousLevel;

            mergedForSave.add({
              'M1_NO': s.id,
              'M1_CODE': s.code,
              'M1_NAME': s.name,
              'M1_GROUP2N': s.className,
              'M1_GROUP2': s.teacherId,
              'books_issued': s.booksIssued,
              'last_updated': s.lastUpdated.toIso8601String(),
              'readingLevel': mergedReadingLevel,
              'previousLevel': mergedPreviousLevel,
            });

            mergedStudents.add(
              s.copyWith(
                readingLevel: mergedReadingLevel,
                previousLevel: mergedPreviousLevel,
              ),
            );
          }

          await _offlineDb.saveStudentsOffline(mergedForSave);
          return mergedStudents; // ✅ now returns the merged data
        }
      } catch (_) {}
    }

    final offline = await _offlineDb.getStudentsOffline(teacherId: group1);
    return offline
        .map(
          (e) => Student(
            id: e['id'] ?? '',
            code: e['code'] ?? '',
            name: e['name'] ?? '',
            className: e['className'] ?? '',
            booksIssued: e['booksIssued'] ?? 0,
            lastUpdated:
                DateTime.tryParse(e['lastUpdated'] ?? '') ?? DateTime.now(),
            teacherId: e['teacherId'] ?? '',
            readingLevel: e['readingLevel'] ?? 0,
            previousLevel: e['previousLevel'] ?? 0,
          ),
        )
        .toList();
  }

  // =========================================================
  // BOOKS
  // =========================================================

  Future<List<Book>> getBooks({String? search, String? userId}) async {
    print('📚 HybridApiService.getBooks called');
    print('   Online: ${_connectivityService.isOnline.value}');
    print('   Search: $search');
    print('   UserId: $userId');

    if (_connectivityService.isOnline.value) {
      try {
        print('🌐 Online: Fetching fresh books from server...');
        final online = await _apiService.getBooks(
          search: search,
          userId: userId,
        );

        print('📖 API returned ${online.length} raw records');
        if (online.isNotEmpty) {
          print('   First raw record keys: ${online.first.keys.toList()}');
          print('   First raw record: ${online.first}');
        }

        final books = online
            .map<Book>((e) => e is Book ? e : Book.fromJson(e))
            .toList();

        print('📖 Parsed into ${books.length} Book objects');
        if (books.isNotEmpty) {
          final first = books.first;
          print(
            '   First Book parsed: bookId="${first.bookId}", bookCode="${first.bookCode}", name="${first.bookName}"',
          );
        }

        if (books.isNotEmpty) {
          print('💾 Saving ${books.length} fresh books to offline storage...');

          // IMPORTANT: Always use fresh server data when online
          print('✅ Using fresh server data - clearing local cache');
          await _offlineDb.clearBooksCache();

          await _offlineDb.saveBooksOffline(
            books
                .map(
                  (b) => {
                    // ✅ CORRECTED: Store correct IDs
                    // bookId (from Book model) = M1_CODE (numeric ID like "2016")
                    // bookCode (from Book model) = M1_NO (book code like "IN-LLP-...")
                    'book_id': b.bookId.isNotEmpty
                        ? b.bookId
                        : b.bookCode, // Numeric M1_CODE
                    'book_code': b.bookCode, // Book code M1_NO
                    'book_name': b.bookName,
                    'available_copy': b.availableCopy,
                    'issued_copy': b.issuedCopy,
                    'total_copy': b.totalCopy,
                    'damaged_copy': b.damagedCopy,
                    'lost_copy': b.lostCopy,
                    'reading_level': b.readingLevel,
                    'program_code': b.programCode,
                    'code': b.bookCode, // M1_NO - book code
                    'no': b.bookId, // M1_CODE - numeric ID
                    'name': b.bookName,
                    'lname': b.authorName,
                    'author_name': b.authorName,
                    'add1': b.bookRomanName,
                    'add2': b.bookLocalName,
                    'txt1': b.readingLevel.toString(),
                    'txt2': b.totalCopy.toString(),
                    'txt3': b.availableCopy.toString(),
                    'txt4': b.issuedCopy.toString(),
                    'txt5': b.damagedCopy.toString(),
                    'bookId': b
                        .bookId, // ✅ CORRECTED: Use bookId (M1_CODE - numeric ID)
                    'type': b.programCode,
                  },
                )
                .toList(),
          );

          print('✅ Fresh books data saved, local modifications overridden');
          await _offlineDb.debugPrintBooksInDatabase();
          return books;
        } else {
          print('⚠️ Online API returned 0 books, falling back to offline...');
        }
      } catch (e) {
        print('❌ Error fetching online books: $e');
        print('   Falling back to offline storage...');
      }
    }

    print('📱 Offline: Loading books from local storage...');
    final offlineBooks = await _offlineDb.getBooksOffline(search: search);
    print('📱 Offline storage returned ${offlineBooks.length} books');

    if (offlineBooks.isEmpty) {
      print('⚠️ No books in offline storage!');
      print('   User needs to download data while online first');
    }

    print(
      '🔄 Converting ${offlineBooks.length} offline records to Book model...',
    );
    final convertedBooks = offlineBooks.map((e) {
      final converted = Book(
        bookId: e['bookId'] ?? e['book_id'] ?? e['no'] ?? '', // Numeric ID
        bookCode: e['code'] ?? e['book_code'] ?? e['M1_NO'] ?? '', // Book code
        bookName: e['name'] ?? e['book_name'] ?? '',
        bookRomanName: e['add1'] ?? e['roman_name'] ?? '',
        bookLocalName: e['add2'] ?? e['local_name'] ?? e['lname'] ?? '',
        authorName: e['lname'] ?? e['author_name'] ?? e['add2'] ?? '',
        totalCopy: int.tryParse(e['txt2'] ?? '0') ?? 0,
        availableCopy: int.tryParse(e['txt3'] ?? '0') ?? 0,
        issuedCopy: int.tryParse(e['txt4'] ?? '0') ?? 0,
        damagedCopy: int.tryParse(e['txt5'] ?? '0') ?? 0,
        lostCopy: 0,
        returnedCopy: 0,
        isActive: true,
        readingLevel: int.tryParse(e['txt1'] ?? '0') ?? 0,
        programCode: e['program_code'] ?? e['type'] ?? '',
      );
      return converted;
    }).toList();

    print('📱 Converted ${convertedBooks.length} offline books to Book model');
    if (convertedBooks.isNotEmpty && convertedBooks.length <= 5) {
      for (int i = 0; i < convertedBooks.length; i++) {
        final b = convertedBooks[i];
        print('   ✓ Book ${i + 1}: ${b.title}');
      }
    }
    return convertedBooks;
  }

  // =========================================================
  // CHECKOUT
  // =========================================================

  Future<Map<String, dynamic>> checkout({
    required String teacherId,
    required List<Map<String, dynamic>> books,
    required String studentId,
    required String className,
    String? programId,
    String? schoolId,
    String? studentName,
  }) async {
    if (books.isEmpty) {
      return {'success': false, 'message': 'No books selected'};
    }

    if (_connectivityService.isOnline.value) {
      try {
        return await _apiService.checkout(
          teacherId: teacherId,
          books: books,
          studentId: studentId,
          className: className,
          programId: programId,
          schoolId: schoolId,
          studentName: studentName,
        );
      } catch (e) {
        return {'success': false, 'message': 'Online checkout failed: $e'};
      }
    }

    try {
      final List<String> transactionIds = [];

      for (final book in books) {
        final transactionId = await _offlineDb.saveOfflineCheckout(
          teacherId: teacherId,
          bookId: book['bookId'].toString(),
          bookCode: book['bookCode'].toString(),
          studentId: studentId,
          className: className,
          studentName: studentName,
          bookName: book['bookName']?.toString(),
        );

        transactionIds.add(transactionId.toString());
      }

      return {
        'success': true,
        'offline': true,
        'transactionIds': transactionIds,
        'message': '${books.length} books issued offline. Will sync later.',
      };
    } catch (e) {
      return {'success': false, 'message': 'Offline checkout failed: $e'};
    }
  }

  // Helper method to update book availability for checkin
  Future<void> _updateBookAvailabilityForCheckin(String bookId) async {
    try {
      final db = await _offlineDb.database;

      print('📚 Updating book availability for checkin:');
      print('   bookId: $bookId');

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
      }

      await db.rawUpdate(
        '''
        UPDATE books 
        SET txt3 = CAST(txt3 AS INTEGER) + 1 
        WHERE code = ? OR bookId = ?
      ''',
        [bookId, bookId],
      );

      await db.rawUpdate(
        '''
        UPDATE books 
        SET txt4 = CAST(txt4 AS INTEGER) - 1 
        WHERE code = ? OR bookId = ?
      ''',
        [bookId, bookId],
      );

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

        print('✅ Book availability updated for checkin:');
        print('   New values: Available=$newAvailable, Issued=$newIssued');
      }
    } catch (e) {
      print('❌ Error updating book availability for checkin: $e');
    }
  }

  // Helper method to update student books issued count for checkin
  Future<void> _updateStudentBooksIssuedForCheckin(String studentId) async {
    try {
      final db = await _offlineDb.database;

      print('👥 Updating student books issued for checkin:');
      print('   studentId: $studentId');

      final currentStudent = await db.query(
        'students',
        where: 'code = ? OR id = ?',
        whereArgs: [studentId, studentId],
        limit: 1,
      );

      if (currentStudent.isNotEmpty) {
        final student = currentStudent.first;
        final currentIssued =
            int.tryParse(student['booksIssued']?.toString() ?? '0') ?? 0;

        print('   Current books issued: $currentIssued');
      }

      await db.rawUpdate(
        '''
        UPDATE students 
        SET booksIssued = CASE WHEN booksIssued > 0 THEN booksIssued - 1 ELSE 0 END
        WHERE code = ? OR id = ?
      ''',
        [studentId, studentId],
      );

      final updatedStudent = await db.query(
        'students',
        where: 'code = ? OR id = ?',
        whereArgs: [studentId, studentId],
        limit: 1,
      );

      if (updatedStudent.isNotEmpty) {
        final student = updatedStudent.first;
        final newIssued =
            int.tryParse(student['booksIssued']?.toString() ?? '0') ?? 0;

        print('✅ Student books issued updated for checkin:');
        print('   New books issued: $newIssued');
      }
    } catch (e) {
      print('❌ Error updating student books issued for checkin: $e');
    }
  }

  // =========================================================
  // CHECKIN
  // =========================================================

  Future<Map<String, dynamic>> checkin({
    required String bookTransactionCode,
    required String bookCode,
    String? teacherId,
    String? bookId,
    String? studentId,
    String? className,
    String? programId,
    String? schoolId,
    String? bookName,
    String? studentName,
  }) async {
    print('🔍 HybridApiService.checkin called with:');
    print('   bookCode (F4_LCODE): "$bookCode"');
    print('   bookName: "${bookName ?? "null"}"');
    print('   bookId (received): "${bookId ?? "null"}"');
    print('   Online: ${_connectivityService.isOnline.value}');

    // ✅ PRESERVE NUMERIC bookId - this is what gets sent to API
    String finalBookId = bookId ?? bookCode;

    print('🎯 Final values for API call:');
    print('   bookCode (F4_LCODE): "$bookCode"');
    print('   bookId (book_id): "$finalBookId"');

    if (_connectivityService.isOnline.value) {
      try {
        print('🌐 Online: Attempting API checkin...');
        final result = await _apiService.checkin(
          bookTransactionCode: bookTransactionCode,
          bookCode: bookCode,
          teacherId: teacherId ?? '',
          bookId: finalBookId,
          studentId: studentId ?? '',
          className: className ?? '',
          programId: programId,
          schoolId: schoolId,
        );

        if (result['success'] == true) {
          // ApiService.checkin() runs its own connectivity check and can
          // take its offline branch (e.g. connectivity dropped between this
          // check and that one), queuing the transaction locally instead of
          // reaching the server. Trust what actually happened instead of
          // assuming this is a synced online success — otherwise the UI
          // reports (and this layer finalizes) a checkin that never made it
          // to the backend, and it silently sits unsynced until the user
          // manually triggers a sync.
          if (result['offline'] == true) {
            print(
              '📱 API checkin actually saved offline (connectivity changed mid-call)',
            );
            try {
              await _updateBookAvailabilityForCheckin(bookCode);
              if (studentId != null) {
                await _updateStudentBooksIssuedForCheckin(studentId);
              }
            } catch (e) {
              print('⚠️ Warning: Could not update book availability: $e');
            }

            return {
              'success': true,
              'offline': true,
              'synced': false,
              'removedFromList': true,
              'message':
                  result['message'] ?? 'Book returned offline! Will sync when online.',
            };
          }

          print('✅ Online checkin successful');

          await _updateLocalDataForCheckin(
            bookCode,
            bookTransactionCode,
            studentId: (studentId != null && studentId.isNotEmpty)
                ? studentId
                : null,
          );

          return {
            'success': true,
            'offline': false,
            'synced': true,
            'removedFromList': true,
            'message': result['message'] ?? 'Book returned successfully!',
          };
        } else {
          print('❌ Online checkin failed: ${result['message']}');
          return {
            'success': false,
            'offline': false,
            'message': result['message'] ?? 'Checkin failed',
          };
        }
      } catch (e) {
        print('❌ Online checkin error: $e');
        return {
          'success': false,
          'offline': false,
          'message': 'Network error: $e',
        };
      }
    } else {
      // OFFLINE MODE
      print('📱 Offline: Saving checkin for later sync...');

      final transactionId = await _offlineDb.saveOfflineCheckin(
        bookTransactionCode: bookTransactionCode,
        bookCode: bookCode,
        teacherId: teacherId,
        bookId: finalBookId, // ✅ Pass preserved bookId (hopefully numeric)
        studentId: studentId,
        studentName: studentName,
        className: className,
        bookName: bookName,
        programId: programId,
        schoolId: schoolId,
      );

      try {
        print('✅ Updating book availability for offline checkin');
        await _updateBookAvailabilityForCheckin(bookCode);
        if (studentId != null) {
          await _updateStudentBooksIssuedForCheckin(studentId);
        }
        print('✅ Offline checkin: Book availability updated');
      } catch (e) {
        print('⚠️ Warning: Could not update book availability: $e');
      }

      print('✅ Offline checkin saved with transaction ID: $transactionId');
      return {
        'success': true,
        'offline': true,
        'synced': false,
        'transactionId': transactionId,
        'removedFromList': true,
        'message': 'Book returned offline! Will sync when online.',
      };
    }
  }

  // =========================================================
  // CHECKED OUT BOOKS
  // =========================================================

  Future<List<dynamic>> getCheckedOutBooks({
    required String teacherId,
    String? className,
    String? fromDate,
    String? toDate,
    String? search,
  }) async {
    print('📋 HybridApiService: Getting checked out books');
    print(
      '   teacherId: $teacherId, online: ${_connectivityService.isOnline.value}',
    );

    if (_connectivityService.isOnline.value) {
      try {
        print('🌐 Attempting to fetch from online API...');
        final online = await _apiService.getCheckedOutBooks(
          teacherId: teacherId,
          className: className,
          fromDate: fromDate,
          toDate: toDate,
          search: search,
        );

        print('📊 Online API returned ${online.length} books');

        // ✅ FIX: Before saving API response, identify and preserve local pending transactions
        // We don't want to re-add books that were already checked in locally
        // Only add API books that don't conflict with local pending transactions
        if (online.isNotEmpty) {
          try {
            print('🔍 Checking for conflicts with locally checked-in books...');
            final db = await _offlineDb.database;

            // ✅ CRITICAL FIX: Get ALL checkin transactions (not just recent)
            // Include both synced and unsynced checkins from ALL TIME
            // This is the key fix - we need to exclude ALL books that were ever checked in, not just recent ones
            final allCheckins = await db.query(
              'offline_transactions_enhanced',
              where: 'transaction_type = ?',
              whereArgs: ['checkin'],
            );

            print(
              '   Found ${allCheckins.length} TOTAL checkin transactions (all time)',
            );

            // Extract book codes from ALL checkins
            final checkedInBookCodes = allCheckins
                .map((t) => t['book_code']?.toString() ?? '')
                .where((code) => code.isNotEmpty)
                .toSet();

            print('   Book codes with checkin history: $checkedInBookCodes');

            // ✅ REMOVED: Don't exclude books with synced=1 status
            // synced=1 means "synced to server", NOT "checked in"
            // For the checkin page, we NEED to show books with synced=1 (currently issued books)
            // Only exclude books that have actual checkin transactions

            // Combine all codes to exclude from API response
            final allExcludedCodes = {...checkedInBookCodes};
            print(
              '   ✅ Total codes to exclude from API: ${allExcludedCodes.length}',
            );

            // ✅ IMPROVED FILTERING: Multiple matching strategies for better reliability
            final filteredOnline = online.where((apiBook) {
              // Get book code from API response (try multiple field names)
              final apiBookCode1 = apiBook['F4_LCODE']?.toString() ?? '';
              final apiBookCode2 = apiBook['bookCode']?.toString() ?? '';
              final apiBookCode = apiBookCode1.isNotEmpty
                  ? apiBookCode1
                  : apiBookCode2;

              // Check exclusion using multiple strategies
              final isExcludedExact = allExcludedCodes.contains(apiBookCode);
              final isExcludedTrimmed = allExcludedCodes.contains(
                apiBookCode.trim(),
              );
              final isExcludedLower = allExcludedCodes.any(
                (code) => code.toLowerCase() == apiBookCode.toLowerCase(),
              );

              final isExcluded =
                  isExcludedExact || isExcludedTrimmed || isExcludedLower;

              if (isExcluded) {
                print(
                  '   ⏭️ EXCLUDED: API book "$apiBookCode" - was checked in locally',
                );
              }
              return !isExcluded;
            }).toList();

            print(
              '📋 FILTERING RESULT: ${filteredOnline.length}/${online.length} API books will be saved',
            );

            // ✅ CLEANUP: Delete ALL excluded books from local database
            print(
              '🗑️ CLEANUP: Deleting excluded books from local database...',
            );
            for (final bookCode in allExcludedCodes) {
              try {
                final deleted = await db.delete(
                  'checked_out_books',
                  where: 'bookCode = ?',
                  whereArgs: [bookCode],
                );
                if (deleted > 0) {
                  print(
                    '   ✅ Deleted $deleted record(s) for book code \"$bookCode\"',
                  );
                }
              } catch (e) {
                print('   ⚠️ Error deleting book \"$bookCode\": $e');
              }
            }

            // Save only the filtered online books
            if (filteredOnline.isNotEmpty) {
              print('💾 Updating offline storage with filtered API data...');
              await _offlineDb.saveCheckedOutBooksOffline(
                filteredOnline
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList(),
                teacherId: teacherId,
              );
              print('✅ Local cache updated with filtered API data');
            } else {
              print('ℹ️ No new API books to update (all are pending locally)');
            }
          } catch (e) {
            print('⚠️ Error filtering API response: $e');
            // Safety: Don't save if filtering fails
            print('❌ SAFETY: NOT saving API data due to filtering error');
          }
        }
      } catch (e) {
        print('❌ Online API failed: $e, using existing offline data...');
      }
    } else {
      print('📱 Device is offline, using offline data...');
    }

    print('📱 Fetching from offline storage (UNSYNCED BOOKS ONLY)...');

    List<dynamic> offlineBooks = [];

    try {
      offlineBooks = await _enhancedOfflineService.getCheckedOutBooks(
        teacherId: teacherId,
        className: className,
        fromDate: fromDate,
        toDate: toDate,
        search: search,
      );
      print(
        '📊 Enhanced offline service returned ${offlineBooks.length} unsynced books',
      );
    } catch (e) {
      print('❌ Enhanced offline service failed: $e');
    }

    if (offlineBooks.isEmpty) {
      print(
        '🔍 Enhanced offline service returned empty, trying direct DB query...',
      );
      try {
        offlineBooks = await _offlineDb.getCheckedOutBooksOffline(
          teacherId: teacherId,
          className: className,
          fromDate: fromDate,
          toDate: toDate,
          search: search,
        );
        print(
          '📊 Direct DB query returned ${offlineBooks.length} unsynced books',
        );
      } catch (e) {
        print('❌ Direct DB query failed: $e');
      }
    }

    // ✅ REMOVED: The "FINAL SAFETY CHECK" that was filtering out all synced books
    // This was preventing the checkin page from displaying issued books
    // For the checkin page, we NEED to show books with synced=1 (currently issued books)
    // The filtering of synced books should happen at the controller level, not here

    if (offlineBooks.isEmpty && !_connectivityService.isOnline.value) {
      print('⚠️ No offline data found - sample data generation disabled');
    }

    if (offlineBooks.isNotEmpty) {
      print('✅ HybridApiService: Returning ${offlineBooks.length} books');
      _logSampleBooks(offlineBooks);
    } else {
      print('❌ HybridApiService: No books found after all strategies');
    }

    return offlineBooks;
  }

  void _logSampleBooks(List<dynamic> books) {
    print('📋 Sample of returned books:');
    for (int i = 0; i < (books.length > 3 ? 3 : books.length); i++) {
      final book = books[i];
      final bookName = book['F4_PARTYN'] ?? book['bookName'] ?? 'Unknown Book';
      final bookCode = book['F4_LCODE'] ?? book['bookCode'] ?? 'Unknown Code';
      final studentName =
          book['F4_PARTY1N'] ?? book['studentName'] ?? 'Unknown Student';
      print('   [$i] $bookName ($bookCode) - $studentName');
    }
  }

  // =========================================================
  // CLASSES
  // =========================================================

  Future<List<String>> getClasses() async {
    try {
      if (_connectivityService.isOnline.value) {
        print('🌐 Online: Fetching classes from API...');
        final online = await _apiService.getClasses();

        if (online.isNotEmpty) {
          print('✅ API returned ${online.length} classes, caching them');
          await _offlineDb.saveClassesOffline(online);
          return online;
        }
        print('⚠️ API returned empty class list');
      }

      print('📱 Fetching classes from offline cache...');
      final offline = await _offlineDb.getClassesOffline();

      if (offline.isEmpty) {
        print('⚠️ No classes in API or offline cache - returning empty list');
        // Don't return default classes - only return actual data from API or cache
        return [];
      }

      print('✅ Loaded ${offline.length} cached classes');
      return offline;
    } catch (e) {
      print('❌ Error getting classes: $e');
      return [];
    }
  }

  // =========================================================
  // LOCAL DB HELPERS
  // =========================================================

  Future<void> _updateLocalDataForCheckin(
    String bookCode,
    String transactionCode, {
    String? studentId,
  }) async {
    final db = await _offlineDb.database;

    if (bookCode.isEmpty) {
      print('⚠️ WARNING: bookCode is empty');
      return;
    }

    await db.rawUpdate(
      '''
      UPDATE books 
      SET txt3 = CAST(txt3 AS INTEGER) + 1,
          txt4 = CAST(txt4 AS INTEGER) - 1
      WHERE code = ? OR bookId = ?
      ''',
      [bookCode, bookCode],
    );

    try {
      print('🔍 HybridApiService: Marking checked_out_book as synced');
      print('   bookCode: "$bookCode"');

      int totalMarked = 0;

      if (studentId != null && studentId.isNotEmpty && bookCode.isNotEmpty) {
        final markedByCodeAndStudent = await db.update(
          'checked_out_books',
          {'synced': 1},
          where: 'bookCode = ? AND studentId = ?',
          whereArgs: [bookCode, studentId],
        );
        totalMarked += markedByCodeAndStudent;
        print(
          '   Strategy 1 (bookCode + studentId): Marked $markedByCodeAndStudent book(s) as synced',
        );
      }

      if (totalMarked == 0 && bookCode.isNotEmpty) {
        final markedByCode = await db.update(
          'checked_out_books',
          {'synced': 1},
          where: 'bookCode = ?',
          whereArgs: [bookCode],
        );
        totalMarked += markedByCode;
        print(
          '   Strategy 2 (bookCode only): Marked $markedByCode book(s) as synced',
        );
      }

      if (totalMarked > 0) {
        print(
          '✅ Successfully marked $totalMarked checked_out_book record(s) as synced',
        );
      }
    } catch (e) {
      print('❌ Error marking checked_out_book as synced: $e');
    }
  }

  // ================= ADDITIONAL METHODS =================

  Future<Map<String, dynamic>> getAnalytics({
    String? teacherId,
    String? className,
    String? dateFrom,
    String? dateTo,
    String? aggregation,
  }) async {
    if (_connectivityService.isOnline.value) {
      try {
        return await _apiService.getAnalytics(
          teacherId: teacherId,
          className: className,
          dateFrom: dateFrom,
          dateTo: dateTo,
          aggregation: aggregation,
        );
      } catch (e) {
        print('❌ Analytics online fetch failed, falling back offline: $e');
      }
    }

    // Offline: derive summary + chart from cached CICO rows
    final rows = await _offlineDb.getCicoReportOffline(
      teacherId: teacherId ?? '',
      className: className,
      fromDate: dateFrom,
      toDate: dateTo,
    );

    int checkouts = 0;
    int checkins = 0;

    final Map<String, int> byPeriod = {};
    final List<Map<String, dynamic>> reportList = [];

    for (final r in rows) {
      // Transaction type from API
      final bt = (r['F4_BT'] ?? '').toString();

      if (bt == '1') {
        checkouts++;
      } else {
        checkins++;
      }

      // Use update date for chart grouping
      final dateStr = (r['F4_USERDT'] ?? r['transactionDate'] ?? '').toString();

      if (dateStr.isNotEmpty) {
        final dt = DateTime.tryParse(dateStr.replaceFirst(' ', 'T'));

        if (dt != null) {
          String key;

          switch (aggregation) {
            case 'daily':
              key =
                  '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
              break;

            case 'weekly':
              final week = ((dt.day - 1) ~/ 7) + 1;
              key = '${dt.year}-${dt.month}-W$week';
              break;

            case 'yearly':
              key = '${dt.year}';
              break;

            case 'monthly':
            default:
              key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
          }

          byPeriod[key] = (byPeriod[key] ?? 0) + 1;
        }
      }

      // Convert API row into UI format
      reportList.add({
        'student_name': r['F4_PARTY1N'] ?? '',
        'book_name': r['F4_PARTYN'] ?? '',
        'F4_BT': r['F4_BT'] ?? bt,
        'F4_DATE1': r['F4_DATE1'] ?? r['F4_DATE'] ?? '',
        'F4_DATE2': r['F4_DATE2'] ?? '',
      });
    }

    return {
      'success': true,
      'offline': true,
      'summary': {
        'totalCheckouts': checkouts,
        'totalCheckins': checkins,
        'totalTransactions': rows.length,
      },
      'chart': byPeriod,
      'list': reportList,
    };
  }

  Future<Map<dynamic, dynamic>> getBookDetails(String bookIdentifier) async {
    try {
      if (_connectivityService.isOnline.value) {
        return await _apiService.getBookDetails(bookIdentifier);
      } else {
        final books = await _offlineDb.getBooksOffline();
        final book = books.firstWhere(
          (b) => b['code'] == bookIdentifier || b['bookId'] == bookIdentifier,
          orElse: () => <String, dynamic>{},
        );
        return book.isNotEmpty ? book : {};
      }
    } catch (e) {
      return {};
    }
  }

  // Future<List<dynamic>> getCicoReport({
  //   required String teacherId,
  //   String? className,
  //   String? fromDate,
  //   String? toDate,
  // }) async {
  //   try {
  //     if (_connectivityService.isOnline.value) {
  //       return await _apiService.getCicoReport(
  //         teacherId: teacherId,
  //         className: className,
  //         fromDate: fromDate,
  //         toDate: toDate,
  //       );
  //     } else {
  //       return [];
  //     }
  //   } catch (e) {
  //     return [];
  //   }
  // }

  Future<List<dynamic>> getCicoReport({
    required String teacherId,
    String? className,
    String? fromDate,
    String? toDate,
  }) async {
    if (_connectivityService.isOnline.value) {
      try {
        final online = await _apiService.getCicoReport(
          teacherId: teacherId,
          className: className,
          fromDate: fromDate,
          toDate: toDate,
        );

        if (online.isNotEmpty) {
          await _offlineDb.saveCicoReportOffline(
            online.cast<Map<String, dynamic>>(),
            teacherId,
          );
        }
        return online;
      } catch (e) {
        print('❌ CICO report online fetch failed, falling back offline: $e');
      }
    }

    // Offline: cached server rows + any not-yet-synced local checkin/checkout activity
    final cached = await _offlineDb.getCicoReportOffline(
      teacherId: teacherId,
      className: className,
      fromDate: fromDate,
      toDate: toDate,
    );

    final pending = await _offlineDb.getPendingOfflineTransactions();
    final pendingForTeacher = pending
        .where((t) => t['teacher_id'] == teacherId)
        .map((t) {
          // A pending checkin's real condition (good=2/damaged=3/lost=4) is
          // only in its raw_data JSON — transaction_type alone can't tell
          // good from damaged from lost, so hardcoding '2' here made every
          // not-yet-synced damaged/lost checkin show up as a normal good
          // return until it synced.
          String bt = t['transaction_type'] == 'checkout' ? '1' : '2';
          if (t['transaction_type'] != 'checkout') {
            try {
              final raw =
                  jsonDecode(t['raw_data'] as String? ?? '{}')
                      as Map<String, dynamic>;
              bt = (raw['F4_BT'] ?? '2').toString();
            } catch (_) {}
          }
          return {
            'F4_PARTY1N': t['student_name'],
            'F4_PARTYN': t['book_name'],
            'F4_LCODE': t['book_code'],
            'F4_TXT2': t['class_name'],
            'F4_BT': bt,
            'F4_USERDT': t['transaction_date'],
          };
        })
        .toList();

    return [...cached, ...pendingForTeacher];
  }

  Future<int> getBookIssueCount(String teacherId) async {
    try {
      if (_connectivityService.isOnline.value) {
        final books = await getCheckedOutBooks(teacherId: teacherId);
        return books.length;
      } else {
        // ✅ FIX: Use EnhancedOfflineService which includes BOTH
        // synced API books (checked_out_books) AND pending offline
        // transactions (offline_transactions_enhanced, synced=0)
        final books = await _enhancedOfflineService.getCheckedOutBooks(
          teacherId: teacherId,
        );
        return books.length;
      }
    } catch (e) {
      print('❌ Error getting book issue count: $e');
      return 0;
    }
  }

  /// Get total checkout count (issued books) from all books
  /// This is calculated as: total_copy - avail_copy for all books
  Future<int> getCheckoutCount(String teacherId) async {
    try {
      print(
        '📊 HybridApiService: Getting checkout count for teacher: $teacherId',
      );

      if (_connectivityService.isOnline.value) {
        // Get all books and calculate total issued
        final books = await getBooks(userId: teacherId);

        int totalIssued = 0;
        for (final book in books) {
          final totalCopy = book.totalCopies;
          final availableCopy = book.availableCopies;
          final issued = totalCopy - availableCopy;
          totalIssued += issued;

          print(
            '   📖 ${book.title}: $issued issued (total: $totalCopy, available: $availableCopy)',
          );
        }

        print('   📊 Total checkout count: $totalIssued');
        return totalIssued;
      } else {
        // Offline: get from local database
        final books = await _offlineDb.getBooksOffline();

        int totalIssued = 0;
        for (final bookData in books) {
          final totalCopy =
              int.tryParse(bookData['total_copy']?.toString() ?? '0') ?? 0;
          final availableCopy =
              int.tryParse(bookData['available_copy']?.toString() ?? '0') ?? 0;
          final issued = totalCopy - availableCopy;
          totalIssued += issued;
        }

        print('   📊 Total checkout count (offline): $totalIssued');
        return totalIssued;
      }
    } catch (e) {
      print('❌ Error getting checkout count: $e');
      return 0;
    }
  }

  Future<Map<String, dynamic>> updateReadingLevel(
    String studentCode,
    int newReadingLevel,
  ) async {
    try {
      if (_connectivityService.isOnline.value) {
        return await _apiService.updateReadingLevel(
          studentCode,
          newReadingLevel,
        );
      } else {
        await _offlineDb.saveOfflineReadingLevelUpdate(
          studentCode: studentCode,
          oldLevel: 0,
          newLevel: newReadingLevel,
        );
        return {
          'success': true,
          'message': 'Reading level updated offline - will sync when online',
          'offline': true,
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error updating reading level: $e'};
    }
  }

  Future<Map<String, dynamic>> downloadAllDataForOffline() async {
    try {
      print('📥 Starting manual data download for offline use...');

      if (!_connectivityService.isOnline.value) {
        return {'success': false, 'message': 'इंटरनेट कनेक्शन की आवश्यकता है'};
      }

      final currentUser = Get.find<AuthService>().currentUser.value;
      if (currentUser == null) {
        return {'success': false, 'message': 'कृपया पहले लॉगिन करें'};
      }

      final teacherId = currentUser.code;

      // Download books
      print('📚 Downloading books...');
      try {
        final booksRaw = await _apiService.getBooks(userId: teacherId);
        print('   API returned ${booksRaw.length} books');

        if (booksRaw.isNotEmpty) {
          final books = booksRaw
              .map<Book>((e) => e is Book ? e : Book.fromJson(e))
              .toList();

          await _offlineDb.clearBooksCache();

          final booksToSave = books
              .map(
                (b) => {
                  'book_id': b.bookId.isNotEmpty
                      ? b.bookId
                      : b.bookCode, // Numeric M1_CODE
                  'bookId': b.bookId.isNotEmpty
                      ? b.bookId
                      : b.bookCode, // Numeric M1_CODE
                  'book_code': b.bookCode,
                  'book_name': b.bookName,
                  'available_copy': b.availableCopy,
                  'issued_copy': b.issuedCopy,
                  'total_copy': b.totalCopy,
                  'damaged_copy': b.damagedCopy,
                  'lost_copy': b.lostCopy,
                  'reading_level': b.readingLevel,
                  'program_code': b.programCode,
                  'code': b.bookCode,
                  'no': b.bookId,
                  'name': b.bookName,
                  'txt1': b.readingLevel.toString(),
                  'txt2': b.totalCopy.toString(),
                  'txt3': b.availableCopy.toString(),
                  'txt4': b.issuedCopy.toString(),
                  'txt5': b.damagedCopy.toString(),
                },
              )
              .toList();

          await _offlineDb.saveBooksOffline(booksToSave);
          print('✅ Cached ${books.length} books successfully');
        }
      } catch (e) {
        print('❌ Books download failed: $e');
      }

      // Download students
      print('👥 Downloading students...');
      try {
        // Use getStudents() rather than the raw API call so the M1_TXT2/
        // M1_TXT1 fields get mapped to readingLevel/previousLevel (and
        // merged with any pending local edits) before being cached —
        // caching the raw API rows directly used to silently zero out
        // every student's reading level on each full offline download.
        final students = await getStudents(group1: teacherId);
        if (students.isNotEmpty) {
          print('✅ Cached ${students.length} students');
        }
      } catch (e) {
        print('⚠️ Students download failed: $e');
      }

      // Download classes
      print('🏫 Downloading classes...');
      try {
        final classes = await _apiService.getClasses();
        if (classes.isNotEmpty) {
          await _offlineDb.saveClassesOffline(classes);
          print('✅ Cached ${classes.length} classes');
        }
      } catch (e) {
        print('⚠️ Classes download failed: $e');
      }

      // Download grades
      print('🎓 Downloading grades...');
      try {
        final grades = await _apiService.getGrades();
        if (grades.isNotEmpty) {
          await _cacheGradesOffline(grades);
          print('✅ Cached ${grades.length} grades');
        }
      } catch (e) {
        print('⚠️ Grades download failed: $e');
      }

      print('🎉 Manual data download completed successfully');

      return {
        'success': true,
        'message': 'सभी डेटा ऑफलाइन उपयोग के लिए डाउनलोड हो गया',
      };
    } catch (e) {
      print('❌ Error in manual data download: $e');
      return {'success': false, 'message': 'डेटा डाउनलोड में त्रुटि: $e'};
    }
  }

  Future<List<Grade>> getGrades() async {
    try {
      if (_connectivityService.isOnline.value) {
        print('🌐 Online: Fetching grades from API...');
        final online = await _apiService.getGrades();

        if (online.isNotEmpty) {
          print('✅ API returned ${online.length} grades, caching them');
          await _cacheGradesOffline(online);
          return online;
        }
        print('⚠️ API returned empty grades list');
      }

      print('📱 Fetching grades from offline cache...');
      return await _getGradesOffline();
    } catch (e) {
      print('❌ Error getting grades: $e');
      return [];
    }
  }

  Future<void> _cacheGradesOffline(List<Grade> grades) async {
    try {
      final db = await _offlineDb.database;
      await db.delete('grades_cache');
      final batch = db.batch();
      for (final grade in grades) {
        batch.insert('grades_cache', {
          'code': grade.code,
          'name': grade.name,
          'cached_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace); // ✅
      }
      await batch.commit(noResult: true);
      print('💾 Cached ${grades.length} grades offline');
    } catch (e) {
      print('❌ Error caching grades: $e');
    }
  }

  Future<List<Grade>> _getGradesOffline() async {
    try {
      final db = await _offlineDb.database;
      final rows = await db.rawQuery(
        'SELECT DISTINCT code, name FROM grades_cache ORDER BY CAST(name AS INTEGER) ASC', // ✅
      );
      return rows
          .map(
            (row) =>
                Grade(code: row['code'] as String, name: row['name'] as String),
          )
          .toList();
    } catch (e) {
      print('❌ Error reading cached grades: $e');
      return [];
    }
  }
}
