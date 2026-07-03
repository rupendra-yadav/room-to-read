import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:room_to_read/controllers/home_controller.dart';
import 'package:room_to_read/models/book_model.dart';
import 'package:room_to_read/models/grade_model.dart';
import 'package:room_to_read/services/api_service.dart';
import 'package:room_to_read/services/connectivity_service.dart';
import 'package:room_to_read/services/enhanced_offline_service.dart';
import 'package:room_to_read/services/hybrid_api_service.dart';
import 'package:room_to_read/services/auth_service.dart';
import 'package:room_to_read/services/offline_database_service.dart';
import 'package:room_to_read/services/offline_sync_service.dart';
import 'package:room_to_read/controllers/student_controller.dart';

class CheckinController extends GetxController {
  late HybridApiService apiService;
  final AuthService _authService = Get.find<AuthService>();
  late OfflineSyncService _syncService;

  var selectedRecord = Rxn<Map<String, dynamic>>();
  var selectedCondition = 'good'.obs; // Add selectedCondition variable
  var selectedClass = Rxn<String>(); // Add selectedClass variable
  var classes = <Grade>[].obs; // Add classes variable
  var dateFromFilter = ''.obs; // Add dateFromFilter variable
  var dateToFilter = ''.obs; // Add dateToFilter variable
  var checkedOutBooks = <Map<String, dynamic>>[].obs;
  var filteredRecords = <Map<String, dynamic>>[].obs;
  var searchQuery = ''.obs;
  var isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    apiService = Get.find<HybridApiService>();
    _syncService = Get.find<OfflineSyncService>();

    // ✅ NEW: Listen for sync completion to refresh data
    _setupSyncListener();

    // fetchCheckedOutBooks();
    fetchClasses(); // Add classes fetching
  }

  /// ✅ NEW: Setup listener for offline sync completion
  /// When sync completes, refresh the checked out books list
  void _setupSyncListener() {
    ever(_syncService.lastSyncCompletedAt, (DateTime? timestamp) {
      if (timestamp != null) {
        refreshAfterSync();
      }
    });
  }

  /// ✅ Refresh checked out books after sync completes
  /// This ensures ONLY unsynced records (synced=0) are shown
  /// Any books with checkins are excluded from the list
  Future<void> refreshAfterSync() async {
    try {
      isLoading.value = true;

      final user = _authService.currentUser.value;
      if (user == null) {
        return;
      }

      // Fetch fresh checked out books (should only return unsynced=0 books)
      final freshData = await apiService.getCheckedOutBooks(
        teacherId: user.code,
      );

      // ✅ CRITICAL: Apply additional safety filter to ensure NO synced books are shown
      // This is a belt-and-suspenders approach to prevent checked-in books from reappearing
      final safeFilteredData = freshData.where((book) {
        final synced = book['synced'] ?? 0;
        if (synced == 1) {
          return false;
        }
        return true;
      }).toList();

      // ✅ NEW: Enrich with book names
      final enrichedData = await _enrichWithBookNames(safeFilteredData);

      // Update the observable list
      checkedOutBooks.value = enrichedData
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      // Clear any filters/search
      filteredRecords.clear();
      searchQuery.value = '';
      clearSelection();
    } catch (e) {
    } finally {
      isLoading.value = false;
    }
  }

  // ================= FETCH DATA =================

  // ================= DEBUG METHODS =================

  // Debug method to check offline transactions
  Future<void> debugOfflineTransactions() async {
    try {
      final user = _authService.currentUser.value;
      if (user == null) return;

      final offlineDb = Get.find<OfflineDatabaseService>();
      final db = await offlineDb.database;

      // Check enhanced transactions table
      try {
        final enhancedTransactions = await db.query(
          'offline_transactions_enhanced',
        );

        for (var transaction in enhancedTransactions) {}
      } catch (e) {}

      // Check old transactions table
      try {
        final oldTransactions = await db.query('offline_transactions');

        for (var transaction in oldTransactions) {}
      } catch (e) {}

      // Check checked_out_books table
      try {
        final checkedOutBooks = await db.query('checked_out_books');

        for (var book in checkedOutBooks) {}
      } catch (e) {}
    } catch (e) {}
  }

  /// ✅ Helper to prepare records for display
  /// The API already provides book names in F4_PARTYN, so we just need to extract them
  /// For records where F4_PARTYN is null/empty, the user will see "Unknown Book"
  Future<List<dynamic>> _enrichWithBookNames(List<dynamic> records) async {
    try {
      final List<dynamic> preparedRecords = [];
      int recordsWithBooks = 0;

      for (var record in records) {
        var newRecord = Map<String, dynamic>.from(record);

        // Extract book name from API's F4_PARTYN field
        final apiBookName = newRecord['F4_PARTYN']?.toString() ?? '';

        // Update bookName field for display
        if (apiBookName.isNotEmpty) {
          newRecord['bookName'] = apiBookName;
          recordsWithBooks++;
        } else {
          // Leave bookName empty - UI will show "Unknown Book"
          newRecord['bookName'] = '';
        }

        preparedRecords.add(newRecord);
      }

      return preparedRecords;
    } catch (e) {
      return records;
    }
  }

  Future<void> fetchCheckedOutBooks() async {
    try {
      // Require at least a grade OR a date filter to fetch
      final hasGrade = selectedClass.value != null;
      final hasDate =
          dateFromFilter.value.isNotEmpty || dateToFilter.value.isNotEmpty;

      if (!hasGrade && !hasDate) {
        checkedOutBooks.clear();
        filteredRecords.clear();
        return;
      }
      // ✅ Don't fetch if no date filter is set
      // if (dateFromFilter.value.isEmpty && dateToFilter.value.isEmpty) {
      //   checkedOutBooks.clear();
      //   filteredRecords.clear();
      //   return;
      // }

      isLoading.value = true;
      final user = _authService.currentUser.value;
      if (user == null) return;

      // Pass date filters to the API call
      final data = await apiService.getCheckedOutBooks(
        teacherId: user.code,
        className: selectedClass.value,
        fromDate: dateFromFilter.value.isNotEmpty ? dateFromFilter.value : null,
        toDate: dateToFilter.value.isNotEmpty ? dateToFilter.value : null,
      );
      if (data.isNotEmpty) {
        // Log all books returned
        for (int i = 0; i < data.length; i++) {
          final book = data[i] as Map?;
        }
      }

      // ✅ IMPORTANT: For checkin page, we want to show books that are CURRENTLY ISSUED
      // These are books with synced=1 (already synced to server)
      // We should NOT filter them out - they're the ones we need to check in!

      // ✅ NEW: Enrich with book names if missing
      final enrichedData = await _enrichWithBookNames(data);
      if (enrichedData.isNotEmpty) {
        for (int i = 0; i < enrichedData.length; i++) {
          final book = enrichedData[i] as Map?;
        }
      }

      if (enrichedData.isEmpty) {
      } else {}

      checkedOutBooks.value = enrichedData
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      _applyFilters();

      // ✅ DEBUG: Print all books in the list
      print('\n📚 ========== CHECKED OUT BOOKS LIST ==========');
      print('Total books: ${checkedOutBooks.length}');
      for (int i = 0; i < checkedOutBooks.length; i++) {
        final book = checkedOutBooks[i];
        print('\n[$i] Book Details:');
        print('   F4_LCODE: ${book['F4_LCODE']}');
        print('   F4_PARTY_NO: ${book['F4_PARTY_NO']}');
        print('   bookId: ${book['bookId']}');
        print('   bookCode: ${book['bookCode']}');
        print('   studentName: ${book['studentName']}');
        print('   bookName: ${book['bookName']}');
      }
      print('=============================================\n');
    } catch (e) {
      Get.snackbar('Error', 'Failed to load data: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// ✅ NEW: Filter out books that have been SYNCED to the server
  /// Only exclude books with synced checkins (sync_status=1)
  /// Pending checkins are already handled by enhanced_offline_service
  Future<List<dynamic>> _filterOutLocalCheckins(
    List<dynamic> books,
    String teacherId,
  ) async {
    try {
      final offlineDb = Get.find<OfflineDatabaseService>();
      final db = await offlineDb.database;

      // Get ONLY SYNCED checkin transactions (sync_status=1)
      // Don't exclude pending checkins - those are handled by enhanced_offline_service
      final syncedCheckins = await db.query(
        'offline_transactions_enhanced',
        where: 'transaction_type = ? AND teacher_id = ? AND sync_status = 1',
        whereArgs: ['checkin', teacherId],
      );

      // Build set of book codes that have been synced to the server
      final syncedCheckinCodes = syncedCheckins
          .map((c) => (c['book_code'] ?? '').toString().trim())
          .where((code) => code.isNotEmpty)
          .toSet();

      if (syncedCheckinCodes.isEmpty) {
        return books;
      }

      // Filter out books with SYNCED checkins  (API might still return them)
      final filtered = books.where((book) {
        final bookCode = (book['F4_LCODE'] ?? book['bookCode'] ?? '')
            .toString()
            .trim();
        final hasSyncedCheckin = syncedCheckinCodes.contains(bookCode);

        if (hasSyncedCheckin && bookCode.isNotEmpty) {}

        return !hasSyncedCheckin;
      }).toList();

      return filtered;
    } catch (e) {
      // Return all books if filtering fails
      return books;
    }
  }

  // ================= SELECTION =================

  void selectRecord(Map<String, dynamic> record) {
    selectedRecord.value = record;
  }

  void clearSelection() {
    selectedRecord.value = null;
  }

  // ================= SEARCH =================

  void search(String query) {
    searchQuery.value = query;
    _applyFilters();
  }

  // ================= CHECKIN =================

  // Temporary debug method to test book lookup
  Future<void> debugBookLookup(String bookCode) async {
    final user = _authService.currentUser.value;
    if (user == null) return;

    try {
      final hybridApiService = Get.find<HybridApiService>();
      final books = await hybridApiService.getBooks(userId: user.code);

      if (books.isNotEmpty) {
        for (int i = 0; i < (books.length > 5 ? 5 : books.length); i++) {
          final book = books[i];

          // Verify Book model fields are properly mapped
          if (book.bookCode.isEmpty || book.bookId.isEmpty) {}
          if (book.bookCode == book.bookId) {}
        }

        // Test the specific lookup
        final matchedBooks = books
            .where((b) => b.bookCode == bookCode)
            .toList();

        if (matchedBooks.isNotEmpty) {
          final book = matchedBooks.first;
        } else {
          final allCodes = books.map((b) => b.bookCode).toList();
        }
      } else {
        // Test raw API service directly
        final apiService = Get.find<ApiService>();
        final rawBooks = await apiService.getBooks(userId: user.code);

        if (rawBooks.isNotEmpty) {
          final firstBook = rawBooks.first;

          // Test Book model conversion
          final bookModel = Book.fromJson(firstBook);
        }
      }
    } catch (e) {}
  }

  Future<Map<String, dynamic>> completeCheckin(String condition) async {
    final record = selectedRecord.value;
    final user = _authService.currentUser.value;

    if (record == null || user == null) {
      return {'success': false, 'message': 'Invalid state'};
    }

    isLoading.value = true;

    try {
      // Parse rawData if available
      Map<String, dynamic>? rawData;
      try {
        if (record['rawData'] != null &&
            record['rawData'].toString().isNotEmpty) {
          rawData = jsonDecode(record['rawData']);
        }
      } catch (e) {}

      // Transaction code
      final String transactionCode = condition == 'good'
          ? '2'
          : condition == 'damaged'
          ? '3'
          : '4';

      // Extract core data from record - prioritize rawData, then direct fields
      print('\n🔍 ========== EXTRACTING BOOK CODE ==========');
      print('   rawData F4_LCODE: ${rawData?['F4_LCODE']}');
      print('   record F4_LCODE: ${record['F4_LCODE']}');
      print('   record bookCode: ${record['bookCode']}');
      print('   record bookId: ${record['bookId']}');
      print('   record keys: ${record.keys.toList()}');

      // ✅ CRITICAL FIX: F4_LCODE is the book code (M1_CODE), NOT a numeric ID
      // Extract it first from rawData, then from record fields
      var bookCode =
          rawData?['F4_PARTY_NO']?.toString() ??
          record['F4_PARTY_NO']?.toString() ??
          record['bookCode']?.toString() ??
          '';

      print('   ✅ Selected bookCode (F4_LCODE): "$bookCode"');

      // ✅ CRITICAL: Do NOT use 'bookId' from record as fallback for bookCode
      // 'bookId' in the record is often wrong (set to numeric ID incorrectly)
      // We should NEVER use it as bookCode - it will be sent as F4_LCODE to API
      if (bookCode.isEmpty) {
        // Only use bookId as ABSOLUTE last resort, but mark it as suspicious
        bookCode = record['bookId']?.toString() ?? '';
        if (bookCode.isNotEmpty) {
          print(
            '   ⚠️ WARNING: bookCode was empty, falling back to record[bookId]: "$bookCode"',
          );
          print('   ⚠️ This might be wrong! bookId is often misconfigured.');
        }
      }
      print('===================================================\n');

      final studentName =
          rawData?['F4_PARTY1N']?.toString() ??
          record['F4_PARTY1N']?.toString() ??
          record['M1_NAME']?.toString() ??
          record['studentName']?.toString() ??
          record['student_name']?.toString() ??
          '';
      final bookName =
          rawData?['F4_PARTYN']?.toString() ??
          record['F4_PARTYN']?.toString() ??
          record['bookName']?.toString() ??
          '';
      final className =
          rawData?['F4_TXT2']?.toString() ??
          record['F4_TXT2']?.toString() ??
          rawData?['F4_TXT1']?.toString() ??
          record['F4_TXT1']?.toString() ??
          record['className']?.toString() ??
          '';

      // Also print the initial studentId before lookup
      final studentId =
          record['student_id']?.toString() ??
          record['M1_CODE']?.toString() ??
          record['studentId']?.toString() ??
          '';

      // Print raw record structure for diagnosis
      record.forEach((key, value) {});

      // ✅ NEW: Idempotency check - verify book is not already checked in
      // This prevents duplicate check-ins if the user taps checkin multiple times
      // CRITICAL FIX: Check by BOTH book code AND student to allow same book to be checked in by different students
      final offlineDb = Get.find<OfflineDatabaseService>();

      // Check 1: Already synced checkin in the last 24 hours
      // Get pending transactions to check for recent check-ins
      final pendingTransactions = await offlineDb
          .getPendingOfflineTransactions();
      final recentCheckins = pendingTransactions.where((t) {
        // ✅ CRITICAL FIX: Match by BOTH book_code AND student_id
        if (t['transaction_type'] != 'checkin' ||
            t['book_code'] != bookCode ||
            t['student_id'] != studentId) // ✅ Also check student
          return false;
        final transactionDate = DateTime.tryParse(
          t['transaction_date']?.toString() ?? '',
        );
        if (transactionDate == null) return false;
        return DateTime.now().difference(transactionDate) < Duration(hours: 24);
      }).toList();

      if (recentCheckins.isNotEmpty) {
        return {
          'success': false,
          'message':
              'यह किताब इस छात्र द्वारा पहले से ही वापस की जा चुकी है। कृपया सूची को रीफ्रेश करें।',
        };
      }

      // Debug book lookup
      await debugBookLookup(bookCode);

      // ===== GET CORRECT BOOK_ID FROM BOOK MODEL =====
      String finalBookId = bookCode; // fallback to book code if lookup fails

      try {
        // Try to get HybridApiService - this might be the issue
        HybridApiService? hybridApiService;
        try {
          hybridApiService = Get.find<HybridApiService>();
        } catch (e) {
          // Fallback to ApiService directly
          final apiService = Get.find<ApiService>();
          final rawBooks = await apiService.getBooks(userId: user.code);

          if (rawBooks.isNotEmpty) {
            // Convert raw data to Book objects manually
            final books = rawBooks.map((data) => Book.fromJson(data)).toList();

            // Look for matching book
            for (final book in books) {
              if (book.bookCode == bookCode) {
                finalBookId = book
                    .bookId; // ✅ FIXED: Use bookId (M1_NO) not bookCode (M1_CODE)
                break;
              }
            }

            if (finalBookId == bookCode) {
              books.map((b) => b.bookCode).take(10).toList();
            }
          } else {}

          // Skip the rest of the hybrid service logic
          throw Exception('Using ApiService fallback');
        }

        final books = await hybridApiService.getBooks(userId: user.code);

        if (books.isNotEmpty) {
          // Debug: Show sample of available books
          for (int i = 0; i < (books.length > 5 ? 5 : books.length); i++) {}

          // Find the book with matching code OR name
          Book? targetBook;

          // Try exact match on code first
          for (final book in books) {
            if (book.bookCode == bookCode) {
              targetBook = book;
              break;
            }
          }

          // If no exact match, try case-insensitive on code
          if (targetBook == null) {
            for (final book in books) {
              if (book.bookCode.toLowerCase() == bookCode.toLowerCase()) {
                targetBook = book;
                break;
              }
            }
          }

          // If still no match, try trimmed comparison on code
          if (targetBook == null) {
            for (final book in books) {
              if (book.bookCode.trim() == bookCode.trim()) {
                targetBook = book;
                break;
              }
            }
          }

          // If code didn't work, try matching by book name (for offline records with wrong codes)
          if (targetBook == null && bookName.isNotEmpty) {
            // Try exact name match first
            for (final book in books) {
              if (book.bookName == bookName) {
                targetBook = book;
                break;
              }
            }

            // Try case-insensitive name match
            if (targetBook == null) {
              for (final book in books) {
                if (book.bookName.toLowerCase() == bookName.toLowerCase()) {
                  targetBook = book;
                  break;
                }
              }
            }

            // Try partial name match (for books with slight name variations)
            if (targetBook == null) {
              for (final book in books) {
                if (book.bookName.toLowerCase().contains(
                      bookName.toLowerCase(),
                    ) ||
                    bookName.toLowerCase().contains(
                      book.bookName.toLowerCase(),
                    )) {
                  targetBook = book;
                  break;
                }
              }
            }
          }

          if (targetBook != null) {
            // Successfully found the book - extract the book_id (M1_NO, NOT M1_CODE)
            finalBookId = targetBook
                .bookId; // ✅ FIXED: Use bookId (M1_NO) not bookCode (M1_CODE)
          } else {
            // Book not found - show available codes for debugging
            books.map((b) => b.bookCode).take(20).toList();
          }
        } else {}
      } catch (e) {}

      // Validate that we have different values (this is the key requirement)
      if (finalBookId == bookCode) {
        print(
          '   ⚠️ finalBookId == bookCode ("$finalBookId"), no Book model found',
        );
      } else {
        print(
          '   ✅ finalBookId ("$finalBookId") differs from bookCode ("$bookCode")',
        );
      }

      // ✅ CRITICAL SAFETY CHECK: Validate finalBookId exists in books list
      // If finalBookId doesn't match ANY book in the system, it's wrong value
      print('\n🔍 ========== VALIDATING FINAL BOOK ID ==========');
      print(
        '   Checking if finalBookId="$finalBookId" matches any book in system...',
      );

      try {
        final hybridApiService = Get.find<HybridApiService>();
        final allBooks = await hybridApiService.getBooks(userId: user.code);

        final isValidBookId = allBooks.any(
          (book) => book.bookId == finalBookId || book.bookCode == finalBookId,
        );

        if (isValidBookId) {
          print('   ✅ VALID: finalBookId="$finalBookId" found in books list');
        } else {
          print(
            '   ❌ INVALID: finalBookId="$finalBookId" NOT found in books list',
          );
          print(
            '      This is suspicious! Falling back to bookCode: "$bookCode"',
          );

          // If finalBookId is not valid, use bookCode instead
          finalBookId = bookCode;
          print('   ✅ Using bookCode as finalBookId: "$finalBookId"');
        }
      } catch (e) {
        print('   ⚠️ Could not validate finalBookId: $e');
        print('      Proceeding with Current value: "$finalBookId"');
      }

      print('===================================================');

      // ===== GET STUDENT_ID FROM RECORD =====
      // For checkin records, extract the student code from the Student model
      // The student code is what the API expects, not the system ID
      String finalStudentId =
          record['student_id']?.toString() ??
          record['M1_CODE']?.toString() ??
          record['studentId']?.toString() ??
          '';

      // Always try to look up by student name to get the correct student code from Student model
      // This is crucial for checkin because the record might not have the correct student code
      if (studentName.isNotEmpty) {
        try {
          // First, try to get StudentController if it's available
          StudentController? studentCtrl;
          try {
            studentCtrl = Get.find<StudentController>();

            if (studentCtrl.students.isEmpty) {
              studentCtrl = null; // Force API fallback
            }
          } catch (e) {}

          if (studentCtrl != null && studentCtrl.students.isNotEmpty) {
            for (final s in studentCtrl.students.take(5)) {}

            // Normalize the search name (trim spaces, remove extra whitespace)
            final normalizedSearchName = studentName.trim().replaceAll(
              RegExp(r'\s+'),
              ' ',
            );

            // Search for student by name in the loaded students list (exact match first)
            final matchingStudents = studentCtrl.students.where((s) {
              final normalizedStudentName = s.name.trim().replaceAll(
                RegExp(r'\s+'),
                ' ',
              );
              return normalizedStudentName.toLowerCase() ==
                  normalizedSearchName.toLowerCase();
            }).toList();

            if (matchingStudents.isNotEmpty) {
              final matchedStudent = matchingStudents[0];
              finalStudentId =
                  matchedStudent.code; // ✅ Extract code from Student model
            } else {
              // Try partial match if exact match fails
              final normalizedSearchName = studentName.trim().toLowerCase();
              final partialMatches = studentCtrl.students.where((s) {
                final normalizedName = s.name.trim().toLowerCase();
                return normalizedName.contains(normalizedSearchName) ||
                    normalizedSearchName.contains(normalizedName);
              }).toList();

              if (partialMatches.isNotEmpty) {
                final matchedStudent = partialMatches[0];
                finalStudentId =
                    matchedStudent.code; // ✅ Extract code from Student model
              } else {
                for (final s in studentCtrl.students.take(10)) {}
              }
            }
          } else if (studentCtrl == null && finalStudentId.isEmpty) {
            // StudentController not available and no direct student_id - try to load from API
            try {
              final studentsFromApi = await apiService.getStudents(
                group1: user.code,
              );

              if (studentsFromApi.isNotEmpty) {
                for (final s in studentsFromApi.take(5)) {}

                // Normalize the search name (trim spaces, remove extra whitespace)
                final normalizedSearchName = studentName.trim().replaceAll(
                  RegExp(r'\s+'),
                  ' ',
                );

                // Search for student by name in the loaded students list
                final matchingStudents = studentsFromApi.where((s) {
                  final normalizedStudentName = s.name.trim().replaceAll(
                    RegExp(r'\s+'),
                    ' ',
                  );
                  return normalizedStudentName.toLowerCase() ==
                      normalizedSearchName.toLowerCase();
                }).toList();

                if (matchingStudents.isNotEmpty) {
                  final matchedStudent = matchingStudents[0];
                  finalStudentId =
                      matchedStudent.code; // ✅ Extract code from Student model
                } else {
                  // Try partial match if exact match fails
                  final normalizedSearchName = studentName.trim().toLowerCase();
                  final partialMatches = studentsFromApi.where((s) {
                    final normalizedName = s.name.trim().toLowerCase();
                    return normalizedName.contains(normalizedSearchName) ||
                        normalizedSearchName.contains(normalizedName);
                  }).toList();

                  if (partialMatches.isNotEmpty) {
                    final matchedStudent = partialMatches[0];
                    finalStudentId = matchedStudent
                        .code; // ✅ Extract code from Student model
                  } else {
                    for (final s in studentsFromApi.take(10)) {}
                  }
                }
              }
              // ignore: empty_catches
            } catch (apiError) {}
          }
          // ignore: empty_catches
        } catch (e) {}
      }

      String actualStudentName = studentName;

      // Validation: Make sure we have a valid student ID
      if (finalStudentId.isEmpty) {
        // Try to get student ID from offline database checked_out_books table
        try {
          final offlineDb = Get.find<OfflineDatabaseService>();
          final db = await offlineDb.database;

          // Query checked_out_books table for this specific book
          final bookCode = record['F4_LCODE']?.toString() ?? '';
          final storedBooks = await db.query(
            'checked_out_books',
            where: 'teacherId = ? AND bookCode = ?',
            whereArgs: [user.code, bookCode],
          );

          if (storedBooks.isNotEmpty) {
            // Get the first matching book's student ID
            final storedBook = storedBooks.first;
            finalStudentId = storedBook['studentId']?.toString() ?? '';
            final storedStudentName =
                storedBook['studentName']?.toString() ?? '';

            if (finalStudentId.isNotEmpty) {
              actualStudentName = storedStudentName.isNotEmpty
                  ? storedStudentName
                  : studentName;
            } else {}
          } else {}
        } catch (dbError) {}

        // If still no student ID, this is a critical error
        if (finalStudentId.isEmpty) {
          return {
            'success': false,
            'message':
                'छात्र की पहचान नहीं हो सकी। यह संभवतः एक पुराना या क्षतिग्रस्त ऑफलाइन रिकॉर्ड है। सूची रीफ्रेश करें और दोबारा कोशिश करें।',
          };
        }
      }

      // Use HybridApiService for proper offline handling
      print('\n📚 ========== CHECKIN online: PREPARING SUBMISSION ==========');
      print('🎯 CHECKIN PARAMETERS:');
      print('   📖 Book Code (F4_LCODE): $bookCode');
      print('   🏷️  Book ID (M1_NO): $finalBookId');
      print('   👤 Student ID: $finalStudentId');
      print('   👤 Student Name: $actualStudentName');
      print('   📝 Book Name: $bookName');
      print('   📊 Transaction Code: $transactionCode');
      print('   teacherId: ${user.code}');
      print('   className: $className');
      print('   programId: ${user.group}');
      print('   schoolId: ${user.group1}');
      print('===================================================');

      final result = await apiService.checkin(
        bookTransactionCode: transactionCode, // F4_BT
        bookCode: bookCode, // F4_LCODE (primary)
        programId: user.group, // ✅ M1_GROUP = program_id
        schoolId: user.group1, // ✅ M1_GROUP1 = school_id
        teacherId: user.code, // teacher_id
        bookId: finalBookId, // book_id (from Book model lookup)
        studentId: finalStudentId, // student_id (from Student model lookup)
        studentName: actualStudentName, // ✅ Pass student name for display
        className: className, // class
        bookName: bookName, // Pass book name for matching
      );

      if (result['success'] == true) {
        // ✅ CRITICAL FIX: Match by BOTH book code AND student to remove only this student's checkout
        // This prevents removing all instances of the same book when multiple students have it
        final bookCodeToRemove =
            record['F4_LCODE'] ?? record['bookCode'] ?? bookCode;
        final studentNameToRemove = actualStudentName;
        final studentIdToRemove = finalStudentId;

        print('\n📚 ========== REMOVING BOOK FROM CHECKIN LIST ==========');
        print('   Book Code: $bookCodeToRemove');
        print('   Student Name: $studentNameToRemove');
        print('   Student ID: $studentIdToRemove');
        print('   Current list size: ${checkedOutBooks.length}');

        // ✅ IMPROVED: Use explicit list reconstruction instead of removeWhere
        // This ensures the observable list change is properly detected
        // CRITICAL: Match BOTH book code AND student name/ID
        final updatedBooks = checkedOutBooks.where((item) {
          final itemCode = item['F4_LCODE'] ?? item['bookCode'] ?? '';
          final itemStudentName =
              item['F4_PARTY1N'] ?? item['studentName'] ?? '';
          final itemStudentId = item['studentId'] ?? '';

          // Match only if BOTH book code AND student match
          final bookMatches = itemCode == bookCodeToRemove;
          final studentMatches =
              itemStudentName == studentNameToRemove ||
              itemStudentId == studentIdToRemove;
          final matches = bookMatches && studentMatches;

          if (matches) {
            print('   ✅ MATCHED: $itemCode - $itemStudentName (removing)');
          }
          return !matches;
        }).toList();

        int removedCount = checkedOutBooks.length - updatedBooks.length;
        print('   Removed: $removedCount books');
        print('   New list size: ${updatedBooks.length}');

        checkedOutBooks.value = updatedBooks;

        // Update filteredRecords with the same list
        final updatedFiltered = filteredRecords.where((item) {
          final itemCode = item['F4_LCODE'] ?? item['bookCode'] ?? '';
          final itemStudentName =
              item['F4_PARTY1N'] ?? item['studentName'] ?? '';
          final itemStudentId = item['studentId'] ?? '';

          // Match only if BOTH book code AND student match
          final bookMatches = itemCode == bookCodeToRemove;
          final studentMatches =
              itemStudentName == studentNameToRemove ||
              itemStudentId == studentIdToRemove;
          final matches = bookMatches && studentMatches;

          return !matches;
        }).toList();

        int removedFilteredCount =
            filteredRecords.length - updatedFiltered.length;
        filteredRecords.value = updatedFiltered;

        print('===================================================\n');

        clearSelection();

        // ✅ NEW: Delete from database (book has been returned)
        // After successful checkin, the book is no longer issued, so remove it completely
        // CRITICAL FIX: Delete ONLY this student's checkout, not all checkouts of that book
        try {
          final offlineDb = Get.find<OfflineDatabaseService>();
          final db = await offlineDb.database;

          print('\n🗑️ ========== DELETING FROM DATABASE ==========');
          print('   Attempting to delete from checked_out_books table');
          print('   Book Code: $bookCodeToRemove');
          print('   Student Name: $studentNameToRemove');
          print('   Student ID: $studentIdToRemove');
          print('   Teacher ID: ${user.code}');

          // Strategy 1: Delete by bookCode + studentName + teacherId (most specific)
          final deleteCount = await db.delete(
            'checked_out_books',
            where: 'bookCode = ? AND studentName = ? AND teacherId = ?',
            whereArgs: [bookCodeToRemove, studentNameToRemove, user.code],
          );

          if (deleteCount > 0) {
            print('   ✅ Strategy 1 SUCCESS: Deleted $deleteCount record(s)');
          } else {
            print('   ⚠️ Strategy 1: No records deleted, trying Strategy 2...');

            // Strategy 2: Try by studentId if name didn't match
            final deleteCount2 = await db.delete(
              'checked_out_books',
              where: 'bookCode = ? AND studentId = ? AND teacherId = ?',
              whereArgs: [bookCodeToRemove, studentIdToRemove, user.code],
            );

            if (deleteCount2 > 0) {
              print('   ✅ Strategy 2 SUCCESS: Deleted $deleteCount2 record(s)');
            } else {
              print(
                '   ⚠️ Strategy 2: No records deleted, trying Strategy 3...',
              );

              // Strategy 3: Try by F4_LCODE field
              final deleteCount3 = await db.delete(
                'checked_out_books',
                where: 'F4_LCODE = ? AND studentName = ? AND teacherId = ?',
                whereArgs: [bookCodeToRemove, studentNameToRemove, user.code],
              );

              if (deleteCount3 > 0) {
                print(
                  '   ✅ Strategy 3 SUCCESS: Deleted $deleteCount3 record(s)',
                );
              } else {
                print('   ⚠️ Strategy 3: No records deleted');

                // Debug: Show what's actually in the database
                print('   🔍 DEBUG: Checking what\'s in the database...');
                final allBooks = await db.query('checked_out_books');
                print('      Total records in table: ${allBooks.length}');
                for (
                  int i = 0;
                  i < (allBooks.length > 5 ? 5 : allBooks.length);
                  i++
                ) {
                  final book = allBooks[i];
                  print(
                    '      [$i] Code: ${book['bookCode']}, Student: ${book['studentName']}, Teacher: ${book['teacherId']}',
                  );
                }
              }
            }
          }

          print('===================================================\n');
        } catch (e) {
          print('❌ Error deleting from database: $e');
        }

        // ✅ Additional: Explicitly trigger observable update with refresh
        print('🔄 Triggering UI refresh...');
        checkedOutBooks.refresh();
        filteredRecords.refresh();
        print('✅ UI refresh triggered');

        // ✅ NEW: Refresh home page book issue count
        try {
          final homeController = Get.find<HomeController>();
          await homeController.fetchBookIssueCounts();
          print('✅ Home controller refreshed');
        } catch (e) {
          print('⚠️ Could not refresh home controller: $e');
        }

        // ✅ DO NOT refresh from database immediately as it may re-add the book
        // if the backend hasn't processed the checkin yet
        // The book will be removed from the backend on next sync or refresh

        // Show appropriate success message
        String onlineMessage;
        String offlineMessage;

        switch (condition) {
          case 'good':
            onlineMessage = 'किताब सफलतापूर्वक वापस की गई!';
            offlineMessage =
                'किताब ऑफलाइन वापस की गई! 📱\nऑनलाइन होने पर यह स्वचालित रूप से सिंक होगा।';
            break;

          case 'damaged':
            onlineMessage =
                'किताब को क्षतिग्रस्त (Damaged) के रूप में दर्ज किया गया!';
            offlineMessage =
                'किताब को ऑफलाइन क्षतिग्रस्त (Damaged) के रूप में दर्ज किया गया! 📱\nऑनलाइन होने पर यह स्वचालित रूप से सिंक होगा।';
            break;

          default: // lost
            onlineMessage = 'किताब को खोई हुई (Lost) के रूप में दर्ज किया गया!';
            offlineMessage =
                'किताब को ऑफलाइन खोई हुई (Lost) के रूप में दर्ज किया गया! 📱\nऑनलाइन होने पर यह स्वचालित रूप से सिंक होगा।';
        }

        final message = result['offline'] == true
            ? offlineMessage
            : onlineMessage;

        print('\n✅ CHECKIN SUCCESS:');
        print('   Offline: ${result['offline']}');
        print('   Message: $message');
        print('   Books remaining in list: ${checkedOutBooks.length}');

        Get.snackbar(
          result['offline'] == true ? '📱 ऑफलाइन सहेजा गया' : '✅ सफल',
          message,
          backgroundColor: result['offline'] == true
              ? Color.fromARGB(255, 255, 152, 0)
              : Colors.green,
          colorText: Colors.white,
          duration: Duration(seconds: result['offline'] == true ? 4 : 3),
        );
      } else {
        // Show error message
        print('\n❌ CHECKIN FAILED:');
        print('   Success: ${result['success']}');
        print('   Message: ${result['message']}');
        print('   Offline: ${result['offline']}');

        Get.snackbar(
          'त्रुटि',
          result['message'] ?? 'चेकइन असफल',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );
      }

      return result;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    } finally {
      isLoading.value = false;
    }
  }

  // ================= MISSING METHODS =================

  void selectCondition(String condition) {
    selectedCondition.value = condition;
  }

  void selectClass(Grade grade) {
    selectedClass.value = grade.name;

    checkedOutBooks.clear();
    filteredRecords.clear();
    fetchCheckedOutBooks();
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = checkedOutBooks.toList();

    // Class filter — normalize "null" string and empty values
    if (selectedClass.value != null && selectedClass.value!.isNotEmpty) {
      filtered = filtered.where((book) {
        final rawClass = book['F4_TXT2']?.toString() ?? '';
        final bookClass = (rawClass == 'null' || rawClass.isEmpty)
            ? (book['F4_TXT1']?.toString() ?? '')
            : rawClass;
        return bookClass.trim().toLowerCase() ==
            selectedClass.value!.trim().toLowerCase();
      }).toList();
    }

    // Date filter — unchanged
    if (dateFromFilter.value.isNotEmpty || dateToFilter.value.isNotEmpty) {
      // ... your existing date filter code
    }

    // Search filter — unchanged
    if (searchQuery.value.isNotEmpty) {
      final q = searchQuery.value.toLowerCase().trim();
      filtered = filtered.where((r) {
        final studentName =
            (r['F4_PARTY1N'] ?? r['studentName'] ?? r['M1_NAME'] ?? '')
                .toString()
                .toLowerCase();
        final bookName = (r['F4_PARTYN'] ?? r['bookName'] ?? '')
            .toString()
            .toLowerCase();
        final bookCode = (r['F4_LCODE'] ?? r['bookCode'] ?? '')
            .toString()
            .toLowerCase();
        return studentName.contains(q) ||
            bookName.contains(q) ||
            bookCode.contains(q);
      }).toList();
    }

    filteredRecords.value = filtered;
  }

  /// ✅ Clear class filter
  void clearClassFilter() {
    selectedClass.value = null;
    checkedOutBooks.clear(); // Clear data when class is deselected
    filteredRecords.clear();
    dateFromFilter.value = ''; // Reset date filters too
    dateToFilter.value = '';
    checkedOutBooks.clear();
    filteredRecords.clear();
  }

  void selectRecordByData(Map<String, dynamic> record) {
    selectedRecord.value = record;
  }

  void clearRecordSelection() {
    selectedRecord.value = null;
    selectedCondition.value = 'good';
  }

  void searchRecords(String query) {
    search(query); // Delegate to existing search method
    // _applyFilters();
  }

  Future<void> refreshCheckedOutBooks() async {
    checkedOutBooks.clear();
    filteredRecords.clear();
    searchQuery.value = '';
    // dateFromFilter and dateToFilter intentionally NOT cleared here
    // so refresh re-fetches with the same date range the user set
    await fetchCheckedOutBooks();
    checkedOutBooks.refresh();
  }

  void setDateFilter(String from, String to) {
    // If both dates set and 'to' is before 'from', reset 'to'
    if (from.isNotEmpty && to.isNotEmpty) {
      final fromDate = DateTime.tryParse(from);
      final toDate = DateTime.tryParse(to);
      if (fromDate != null && toDate != null && toDate.isBefore(fromDate)) {
        dateToFilter.value = ''; // Clear invalid 'to' date
        dateFromFilter.value = from;
        return;
      }
    }

    dateFromFilter.value = from;
    dateToFilter.value = to;

    if (from.isEmpty && to.isEmpty) {
      checkedOutBooks.clear();
      filteredRecords.clear();
    } else {
      fetchCheckedOutBooks();
    }
  }

  // Fetch classes method
  Future<void> fetchClasses() async {
    try {
      final gradeList = await apiService.getGrades();
      classes.value = gradeList;
    } catch (e) {
      classes.value = [];
    }
  }

  /// ✅ NEW: Comprehensive diagnostic method for checkin data display issue
  /// This method tests all data sources and identifies where data is being lost
  Future<void> diagnoseCheckinDataIssue() async {
    try {
      final user = _authService.currentUser.value;
      if (user == null) {
        return;
      }

      // Test 1: API Service directly
      try {
        final apiBooks = await apiService.getCheckedOutBooks(
          teacherId: user.code,
        );
        if (apiBooks.isNotEmpty) {}
      } catch (e) {}

      // Test 2: Enhanced Offline Service
      try {
        final enhancedService = Get.find<EnhancedOfflineService>();
        final enhancedBooks = await enhancedService.getCheckedOutBooks(
          teacherId: user.code,
        );
        if (enhancedBooks.isNotEmpty) {}
      } catch (e) {}

      // Test 3: Direct Database Query
      try {
        final offlineDb = Get.find<OfflineDatabaseService>();
        final db = await offlineDb.database;

        final dbBooks = await db.query('checked_out_books');
        if (dbBooks.isNotEmpty) {}
      } catch (e) {}

      // Test 4: Current Controller State
      if (checkedOutBooks.isNotEmpty) {}

      // Test 5: Filtering Logic
      try {
        final testData = await apiService.getCheckedOutBooks(
          teacherId: user.code,
        );

        final filtered = await _filterOutLocalCheckins(testData, user.code);

        if (testData.length != filtered.length) {}
      } catch (e) {}
    } catch (e) {}
  }

  /// ✅ NEW: Force reload checked out books with detailed logging
  Future<void> forceReloadCheckedOutBooks() async {
    try {
      isLoading.value = true;

      // Clear current data
      checkedOutBooks.clear();
      filteredRecords.clear();
      searchQuery.value = '';

      // Fetch fresh data
      await fetchCheckedOutBooks();

      if (checkedOutBooks.isEmpty) {}

      Get.snackbar(
        'रीलोड पूरा',
        'डेटा सफलतापूर्वक रीलोड किया गया (${checkedOutBooks.length} किताबें)',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'त्रुटि',
        'डेटा रीलोड करने में त्रुटि: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // Force complete refresh - useful for debugging
  Future<void> forceCompleteRefresh() async {
    // Reset all state
    checkedOutBooks.clear();
    filteredRecords.clear();
    searchQuery.value = '';
    selectedRecord.value = null;
    selectedCondition.value = 'good';

    // Force refresh from server
    isLoading.value = true;

    try {
      await Future.delayed(Duration(milliseconds: 100)); // Small delay
      await fetchCheckedOutBooks();

      Get.snackbar(
        'रिफ्रेश',
        'डेटा सफलतापूर्वक रिफ्रेश किया गया',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        'त्रुटि',
        'रिफ्रेश में त्रुटि: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );
    } finally {
      isLoading.value = false;
    }
  }

  // Debug method for offline checkin testing
  Future<void> debugOfflineCheckin() async {
    try {
      final user = _authService.currentUser.value;
      if (user == null) {
        return;
      }

      final db = await Get.find<OfflineDatabaseService>().database;

      // Check current checked_out_books
      final books = await db.query(
        'checked_out_books',
        where: 'teacherId = ?',
        whereArgs: [user.code],
      );

      for (var book in books) {}

      // Check offline transactions
      final transactions = await db.query(
        'offline_transactions',
        where: 'synced = ?',
        whereArgs: [0],
      );

      for (var transaction in transactions) {}
    } catch (e) {}
  }

  // Test offline book loading functionality
  Future<void> testOfflineBookLoading() async {
    try {
      final user = _authService.currentUser.value;
      if (user == null) {
        return;
      }

      // Test 1: Check connectivity status
      final connectivityService = Get.find<ConnectivityService>();

      // Test 2: Test enhanced offline service directly
      final enhancedOfflineService = Get.find<EnhancedOfflineService>();
      final enhancedBooks = await enhancedOfflineService.getCheckedOutBooks(
        teacherId: user.code,
      );

      // Test 3: Test hybrid API service
      final hybridBooks = await apiService.getCheckedOutBooks(
        teacherId: user.code,
      );

      // Test 4: Test direct database access
      final offlineDb = Get.find<OfflineDatabaseService>();
      final directBooks = await offlineDb.getCheckedOutBooksOffline(
        teacherId: user.code,
      );

      // Test 5: Check database tables and structure
      final db = await offlineDb.database;

      // Check if tables exist
      await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");

      // Check checked_out_books table specifically
      try {
        final tableInfo = await db.rawQuery(
          "PRAGMA table_info(checked_out_books)",
        );
        for (final column in tableInfo) {}

        // Count records
        final totalCount = await db.rawQuery(
          'SELECT COUNT(*) as count FROM checked_out_books',
        );
        final total = totalCount.first['count'] as int;

        await db.rawQuery(
          'SELECT COUNT(*) as count FROM checked_out_books WHERE teacherId = ?',
          [user.code],
        );

        // Show sample records if any exist
        if (total > 0) {
          final sampleRecords = await db.query('checked_out_books', limit: 3);
          for (int i = 0; i < sampleRecords.length; i++) {}
        }
      } catch (e) {}

      // Test 6: Check offline transactions
      try {
        final transactions = await db.query(
          'offline_transactions',
          where: 'teacherId = ?',
          whereArgs: [user.code],
        );

        if (transactions.isNotEmpty) {
          for (
            int i = 0;
            i < (transactions.length > 3 ? 3 : transactions.length);
            i++
          ) {}
        }
      } catch (e) {}

      // Test 7: Force generate sample data if needed
      if (hybridBooks.isEmpty && !connectivityService.isOnline.value) {
        // Trigger sample data generation by calling the method again
        await apiService.getCheckedOutBooks(teacherId: user.code);
      }

      // Summary

      // Show results to user
      Get.snackbar(
        'ऑफलाइन टेस्ट पूरा',
        'Enhanced: ${enhancedBooks.length}, Hybrid: ${hybridBooks.length}, Direct: ${directBooks.length} books found',
        backgroundColor: Colors.blue.shade100,
        duration: Duration(seconds: 5),
      );
    } catch (e) {
      Get.snackbar(
        'टेस्ट त्रुटि',
        'ऑफलाइन टेस्ट में त्रुटि: $e',
        backgroundColor: Colors.red.shade100,
        duration: Duration(seconds: 3),
      );
    }
  }

  // Force remove a book from the checkin list (for debugging/fixing stuck items)
  Future<void> forceRemoveBookFromList(String bookCode) async {
    try {
      final user = _authService.currentUser.value;
      if (user == null) {
        return;
      }

      final db = await Get.find<OfflineDatabaseService>().database;

      // Remove from database using multiple strategies

      // ✅ CRITICAL FIX: Delete ONLY THIS STUDENT'S checkout, not all checkouts of that book
      // This prevents removing multiple checkins as pairs
      final studentNameToRemove = selectedRecord.value?['F4_PARTY1N'] ?? '';
      final studentIdToRemove = selectedRecord.value?['F4_PARTY1'] ?? '';

      // Strategy 1: Delete by bookCode + studentName + teacherId (most specific)
      if (bookCode.isNotEmpty && studentNameToRemove.isNotEmpty) {
        final removed1 = await db.delete(
          'checked_out_books',
          where: 'bookCode = ? AND studentName = ? AND teacherId = ?',
          whereArgs: [bookCode, studentNameToRemove, user.code],
        );
        if (removed1 > 0) {}
      }

      // Strategy 2: Delete by bookCode + studentId + teacherId (if student ID available)
      if (bookCode.isNotEmpty && studentIdToRemove.isNotEmpty) {
        final removed2 = await db.delete(
          'checked_out_books',
          where: 'bookCode = ? AND studentId = ? AND teacherId = ?',
          whereArgs: [bookCode, studentIdToRemove, user.code],
        );
        if (removed2 > 0) {}
      }

      // Strategy 3: Delete by F4_LCODE + F4_PARTY1N + teacherId (API field names)
      if (bookCode.isNotEmpty && studentNameToRemove.isNotEmpty) {
        final removed3 = await db.delete(
          'checked_out_books',
          where: 'F4_LCODE = ? AND F4_PARTY1N = ? AND teacherId = ?',
          whereArgs: [bookCode, studentNameToRemove, user.code],
        );
        if (removed3 > 0) {}
      }

      // Remove from UI lists - ONLY the specific student's checkout
      checkedOutBooks.removeWhere((book) {
        final bookMatches =
            book['F4_LCODE'] == bookCode ||
            book['bookCode'] == bookCode ||
            book['bookId'] == bookCode;

        final studentMatches =
            (studentNameToRemove.isNotEmpty &&
                book['F4_PARTY1N'] == studentNameToRemove) ||
            (studentIdToRemove.isNotEmpty &&
                book['F4_PARTY1'] == studentIdToRemove);

        // Only remove if BOTH book AND student match
        final shouldRemove = bookMatches && studentMatches;

        if (shouldRemove) {}

        return shouldRemove;
      });

      filteredRecords.removeWhere((book) {
        final bookMatches =
            book['F4_LCODE'] == bookCode ||
            book['bookCode'] == bookCode ||
            book['bookId'] == bookCode;

        final studentMatches =
            (studentNameToRemove.isNotEmpty &&
                book['F4_PARTY1N'] == studentNameToRemove) ||
            (studentIdToRemove.isNotEmpty &&
                book['F4_PARTY1'] == studentIdToRemove);

        return bookMatches && studentMatches;
      });

      // Force UI refresh
      checkedOutBooks.refresh();
      filteredRecords.refresh();

      // Clear selection if it was the selected book
      if (selectedRecord.value != null) {
        final selected = selectedRecord.value!;
        if (selected['F4_LCODE'] == bookCode ||
            selected['bookCode'] == bookCode ||
            selected['bookId'] == bookCode) {
          clearSelection();
        }
      }

      Get.snackbar(
        'बुक हटाई गई',
        'किताब "$bookCode" को चेकइन लिस्ट से हटा दिया गया',
        backgroundColor: Colors.green.shade100,
        duration: Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        'त्रुटि',
        'बुक हटाने में त्रुटि: $e',
        backgroundColor: Colors.red.shade100,
        duration: Duration(seconds: 3),
      );
    }
  }

  // Debug method to analyze unknown students in checkin list
  Future<void> debugUnknownStudents() async {
    try {
      final user = _authService.currentUser.value;
      if (user == null) return;

      int unknownStudentCount = 0;
      int knownStudentCount = 0;

      for (var record in checkedOutBooks) {
        final studentName = record['F4_PARTY1N']?.toString() ?? 'N/A';
        final bookName = record['F4_PARTYN']?.toString() ?? 'N/A';
        final bookCode = record['F4_LCODE']?.toString() ?? 'N/A';

        if (studentName == 'N/A' ||
            studentName.isEmpty ||
            studentName == 'Unknown Student' ||
            studentName == bookCode) {
          unknownStudentCount++;

          // Check if this is from offline transaction
          final rawData = record['rawData']?.toString();
          if (rawData != null) {}
        } else {
          knownStudentCount++;
        }
      }

      if (unknownStudentCount > 0) {}
    } catch (e) {}
  }

  // Method to test the offline fixes - can be called from UI
  Future<void> testOfflineFixes() async {
    try {
      // Test 1: Check database content
      await debugOfflineTransactions();

      // Test 2: Analyze unknown students
      await debugUnknownStudents();

      // Show result to user
      Get.snackbar(
        'टेस्ट पूर्ण',
        'ऑफलाइन फिक्स टेस्ट पूर्ण। लॉग देखें।',
        backgroundColor: Colors.blue,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );
    } catch (e) {
      Get.snackbar(
        'टेस्ट त्रुटि',
        'टेस्ट में त्रुटि: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );
    }
  }

  // ✅ NEW: Diagnostic method to trace offline checkout flow
  Future<void> diagnosticCheckOfflineCheckout() async {
    try {
      final user = _authService.currentUser.value;
      if (user == null) {
        return;
      }

      // Step 1: Check database directly
      final offlineDb = Get.find<OfflineDatabaseService>();
      final db = await offlineDb.database;

      final allBooks = await db.query('checked_out_books');

      if (allBooks.isNotEmpty) {
        final Map<String, List<Map>> byTeacher = {};
        for (final book in allBooks) {
          final tid = book['teacherId'] as String? ?? 'NULL';
          byTeacher.putIfAbsent(tid, () => []).add(book);
        }

        for (final entry in byTeacher.entries) {
          for (final book in entry.value) {}
        }
      } else {}

      // Step 2: Test query with exact teacher ID
      final queryResult = await db.query(
        'checked_out_books',
        where: 'teacherId = ? AND synced = 0',
        whereArgs: [user.code],
      );
      for (final book in queryResult) {}

      // Step 3: Test enhanced service
      final enhancedService = Get.find<EnhancedOfflineService>();
      await enhancedService.getCheckedOutBooks(teacherId: user.code);

      // Step 4: Test hybrid API
      await apiService.getCheckedOutBooks(teacherId: user.code);

      // Step 5: Test checkin controller fetch
      await fetchCheckedOutBooks();
    } catch (e) {}
  }
}
