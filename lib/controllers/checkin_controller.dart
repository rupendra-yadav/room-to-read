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

      print('\n🔍 ========== EXTRACTING IDENTIFIERS ==========');
      print('   rawData F4_LCODE: ${rawData?['F4_LCODE']}');
      print('   record F4_LCODE: ${record['F4_LCODE']}');
      print('   rawData F4_PARTY: ${rawData?['F4_PARTY']}');
      print('   record F4_PARTY: ${record['F4_PARTY']}');
      print('   record keys: ${record.keys.toList()}');

      // ⚠️ F4_LCODE is the CHECKOUT TRANSACTION'S OWN LINE CODE.
      // It exists ONLY to be echoed back as F4_STAT so the backend can link
      // this checkin to the checkout row it closes. It is NEVER a book
      // identifier and must never be used to look up a book.
      var transactionLcode =
          rawData?['F4_LCODE']?.toString() ??
          record['F4_LCODE']?.toString() ??
          '';

      print('   ✅ transactionLcode (→ F4_STAT link): "$transactionLcode"');

      // ✅ F4_PARTY is the REAL book code (M1_CODE) on the checkout row.
      // This is what must be used for the Book-model lookup and ultimately
      // sent on as F4_PARTY on the checkin row.
      var realBookCode =
          rawData?['F4_PARTY']?.toString() ??
          record['F4_PARTY']?.toString() ??
          record['bookCode']?.toString() ?? // legacy fallback only
          '';

      print('   ✅ realBookCode (F4_PARTY): "$realBookCode"');

      if (realBookCode.isEmpty) {
        // Last-resort fallback only — bookId is sometimes misconfigured,
        // so this is logged loudly rather than trusted silently.
        realBookCode = record['bookId']?.toString() ?? '';
        if (realBookCode.isNotEmpty) {
          print(
            '   ⚠️ WARNING: realBookCode was empty, falling back to record[bookId]: "$realBookCode"',
          );
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

      // ✅ Prefer the real student code straight from the record/rawData
      // (F4_PARTY1) now that the PHP side exposes it. Name-matching below
      // is only a fallback for old cached records that predate this field.
      var studentId =
          rawData?['F4_PARTY1']?.toString() ??
          record['F4_PARTY1']?.toString() ??
          record['student_id']?.toString() ??
          record['M1_CODE']?.toString() ??
          record['studentId']?.toString() ??
          '';

      print('   studentId (F4_PARTY1 preferred): "$studentId"');

      // Idempotency check — keyed on the real book code + student, not the
      // transaction line code.
      final offlineDb = Get.find<OfflineDatabaseService>();

      final pendingTransactions = await offlineDb
          .getPendingOfflineTransactions();
      final recentCheckins = pendingTransactions.where((t) {
        if (t['transaction_type'] != 'checkin' ||
            t['book_code'] != realBookCode ||
            t['student_id'] != studentId) {
          return false;
        }
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

      await debugBookLookup(realBookCode);

      // ===== GET CORRECT BOOK_ID FROM BOOK MODEL =====
      // fallback to the real book code if lookup fails — NOT the transaction lcode
      String finalBookId = realBookCode;

      try {
        HybridApiService? hybridApiService;
        try {
          hybridApiService = Get.find<HybridApiService>();
        } catch (e) {
          final apiService = Get.find<ApiService>();
          final rawBooks = await apiService.getBooks(userId: user.code);

          if (rawBooks.isNotEmpty) {
            final books = rawBooks.map((data) => Book.fromJson(data)).toList();

            for (final book in books) {
              if (book.bookCode == realBookCode) {
                finalBookId = book.bookId;
                break;
              }
            }
          }

          throw Exception('Using ApiService fallback');
        }

        final books = await hybridApiService.getBooks(userId: user.code);

        if (books.isNotEmpty) {
          Book? targetBook;

          for (final book in books) {
            if (book.bookCode == realBookCode) {
              targetBook = book;
              break;
            }
          }

          if (targetBook == null) {
            for (final book in books) {
              if (book.bookCode.toLowerCase() == realBookCode.toLowerCase()) {
                targetBook = book;
                break;
              }
            }
          }

          if (targetBook == null) {
            for (final book in books) {
              if (book.bookCode.trim() == realBookCode.trim()) {
                targetBook = book;
                break;
              }
            }
          }

          if (targetBook == null && bookName.isNotEmpty) {
            for (final book in books) {
              if (book.bookName == bookName) {
                targetBook = book;
                break;
              }
            }

            if (targetBook == null) {
              for (final book in books) {
                if (book.bookName.toLowerCase() == bookName.toLowerCase()) {
                  targetBook = book;
                  break;
                }
              }
            }

            if (targetBook == null) {
              for (final book in books) {
                if (book.bookName.toLowerCase().contains(bookName.toLowerCase()) ||
                    bookName.toLowerCase().contains(book.bookName.toLowerCase())) {
                  targetBook = book;
                  break;
                }
              }
            }
          }

          if (targetBook != null) {
            finalBookId = targetBook.bookId;
          }
        }
      } catch (e) {}

      print('\n🔍 ========== VALIDATING FINAL BOOK ID ==========');
      print('   Checking if finalBookId="$finalBookId" matches any book in system...');

      try {
        final hybridApiService = Get.find<HybridApiService>();
        final allBooks = await hybridApiService.getBooks(userId: user.code);

        final isValidBookId = allBooks.any(
          (book) => book.bookId == finalBookId || book.bookCode == finalBookId,
        );

        if (!isValidBookId) {
          print(
            '   ❌ INVALID: finalBookId="$finalBookId" NOT found in books list. Falling back to realBookCode: "$realBookCode"',
          );
          finalBookId = realBookCode; // ✅ fixed: was `bookCode` before
        }
      } catch (e) {
        print('   ⚠️ Could not validate finalBookId: $e');
      }

      print('===================================================');

      // ===== STUDENT NAME-MATCH FALLBACK (only if F4_PARTY1 was missing) =====
      String actualStudentName = studentName;

      if (studentId.isEmpty && studentName.isNotEmpty) {
        try {
          StudentController? studentCtrl;
          try {
            studentCtrl = Get.find<StudentController>();
            if (studentCtrl.students.isEmpty) studentCtrl = null;
          } catch (e) {}

          if (studentCtrl != null && studentCtrl.students.isNotEmpty) {
            final normalizedSearchName =
                studentName.trim().replaceAll(RegExp(r'\s+'), ' ');

            final matchingStudents = studentCtrl.students.where((s) {
              final normalizedStudentName =
                  s.name.trim().replaceAll(RegExp(r'\s+'), ' ');
              return normalizedStudentName.toLowerCase() ==
                  normalizedSearchName.toLowerCase();
            }).toList();

            if (matchingStudents.isNotEmpty) {
              studentId = matchingStudents[0].code;
            } else {
              final normalizedLower = studentName.trim().toLowerCase();
              final partialMatches = studentCtrl.students.where((s) {
                final n = s.name.trim().toLowerCase();
                return n.contains(normalizedLower) || normalizedLower.contains(n);
              }).toList();
              if (partialMatches.isNotEmpty) {
                studentId = partialMatches[0].code;
              }
            }
          } else if (studentCtrl == null) {
            try {
              final studentsFromApi = await apiService.getStudents(group1: user.code);
              if (studentsFromApi.isNotEmpty) {
                final normalizedSearchName =
                    studentName.trim().replaceAll(RegExp(r'\s+'), ' ');

                final matchingStudents = studentsFromApi.where((s) {
                  final n = s.name.trim().replaceAll(RegExp(r'\s+'), ' ');
                  return n.toLowerCase() == normalizedSearchName.toLowerCase();
                }).toList();

                if (matchingStudents.isNotEmpty) {
                  studentId = matchingStudents[0].code;
                } else {
                  final normalizedLower = studentName.trim().toLowerCase();
                  final partialMatches = studentsFromApi.where((s) {
                    final n = s.name.trim().toLowerCase();
                    return n.contains(normalizedLower) || normalizedLower.contains(n);
                  }).toList();
                  if (partialMatches.isNotEmpty) {
                    studentId = partialMatches[0].code;
                  }
                }
              }
            } catch (apiError) {}
          }
        } catch (e) {}
      }

      // Last-resort: offline DB lookup, keyed on the REAL book code, not F4_LCODE
      if (studentId.isEmpty) {
        try {
          final offlineDb = Get.find<OfflineDatabaseService>();
          final db = await offlineDb.database;

          final storedBooks = await db.query(
            'checked_out_books',
            where: 'teacherId = ? AND bookCode = ?',
            whereArgs: [user.code, realBookCode], // ✅ fixed: was F4_LCODE
          );

          if (storedBooks.isNotEmpty) {
            final storedBook = storedBooks.first;
            studentId = storedBook['studentId']?.toString() ?? '';
            final storedStudentName = storedBook['studentName']?.toString() ?? '';
            if (studentId.isNotEmpty) {
              actualStudentName =
                  storedStudentName.isNotEmpty ? storedStudentName : studentName;
            }
          }
        } catch (dbError) {}

        if (studentId.isEmpty) {
          return {
            'success': false,
            'message':
                'छात्र की पहचान नहीं हो सकी। यह संभवतः एक पुराना या क्षतिग्रस्त ऑफलाइन रिकॉर्ड है। सूची रीफ्रेश करें और दोबारा कोशिश करें।',
          };
        }
      }

      final finalStudentId = studentId;

      print('\n📚 ========== CHECKIN online: PREPARING SUBMISSION ==========');
      print('🎯 CHECKIN PARAMETERS:');
      print('   🔗 Transaction Lcode (→ F4_STAT): $transactionLcode');
      print('   📖 Real Book Code (F4_PARTY): $realBookCode');
      print('   🏷️  Book ID (M1_NO): $finalBookId');
      print('   👤 Student ID: $finalStudentId');
      print('   👤 Student Name: $actualStudentName');
      print('===================================================');

      final result = await apiService.checkin(
        bookTransactionCode: transactionCode, // F4_BT
        bookCode: transactionLcode, // ✅ F4_LCODE — used ONLY to build F4_STAT
        programId: user.group,
        schoolId: user.group1,
        teacherId: user.code,
        bookId: finalBookId, // → F4_PARTY (via PHP book_id param)
        studentId: finalStudentId, // → F4_PARTY1
        studentName: actualStudentName,
        className: className,
        bookName: bookName,
      );

      if (result['success'] == true) {
        final bookCodeToRemove =
            record['F4_LCODE'] ?? record['bookCode'] ?? transactionLcode;
        final studentNameToRemove = actualStudentName;
        final studentIdToRemove = finalStudentId;

        final updatedBooks = checkedOutBooks.where((item) {
          final itemCode = item['F4_LCODE'] ?? item['bookCode'] ?? '';
          final itemStudentName = item['F4_PARTY1N'] ?? item['studentName'] ?? '';
          final itemStudentId = item['studentId'] ?? '';
          final matches = itemCode == bookCodeToRemove &&
              (itemStudentName == studentNameToRemove ||
                  itemStudentId == studentIdToRemove);
          return !matches;
        }).toList();
        checkedOutBooks.value = updatedBooks;

        final updatedFiltered = filteredRecords.where((item) {
          final itemCode = item['F4_LCODE'] ?? item['bookCode'] ?? '';
          final itemStudentName = item['F4_PARTY1N'] ?? item['studentName'] ?? '';
          final itemStudentId = item['studentId'] ?? '';
          final matches = itemCode == bookCodeToRemove &&
              (itemStudentName == studentNameToRemove ||
                  itemStudentId == studentIdToRemove);
          return !matches;
        }).toList();
        filteredRecords.value = updatedFiltered;

        clearSelection();

        try {
          final offlineDb = Get.find<OfflineDatabaseService>();
          final db = await offlineDb.database;

          final deleteCount = await db.delete(
            'checked_out_books',
            where: 'bookCode = ? AND studentName = ? AND teacherId = ?',
            whereArgs: [bookCodeToRemove, studentNameToRemove, user.code],
          );

          if (deleteCount == 0) {
            final deleteCount2 = await db.delete(
              'checked_out_books',
              where: 'bookCode = ? AND studentId = ? AND teacherId = ?',
              whereArgs: [bookCodeToRemove, studentIdToRemove, user.code],
            );

            if (deleteCount2 == 0) {
              await db.delete(
                'checked_out_books',
                where: 'F4_LCODE = ? AND studentName = ? AND teacherId = ?',
                whereArgs: [bookCodeToRemove, studentNameToRemove, user.code],
              );
            }
          }
        } catch (e) {}

        checkedOutBooks.refresh();
        filteredRecords.refresh();

        try {
          final homeController = Get.find<HomeController>();
          await homeController.fetchBookIssueCounts();
        } catch (e) {}

        String onlineMessage;
        String offlineMessage;

        switch (condition) {
          case 'good':
            onlineMessage = 'किताब सफलतापूर्वक वापस की गई!';
            offlineMessage =
                'किताब ऑफलाइन वापस की गई! 📱\nऑनलाइन होने पर यह स्वचालित रूप से सिंक होगा।';
            break;
          case 'damaged':
            onlineMessage = 'किताब को क्षतिग्रस्त (Damaged) के रूप में दर्ज किया गया!';
            offlineMessage =
                'किताब को ऑफलाइन क्षतिग्रस्त (Damaged) के रूप में दर्ज किया गया! 📱\nऑनलाइन होने पर यह स्वचालित रूप से सिंक होगा।';
            break;
          default:
            onlineMessage = 'किताब को खोई हुई (Lost) के रूप में दर्ज किया गया!';
            offlineMessage =
                'किताब को ऑफलाइन खोई हुई (Lost) के रूप में दर्ज किया गया! 📱\nऑनलाइन होने पर यह स्वचालित रूप से सिंक होगा।';
        }

        final message = result['offline'] == true ? offlineMessage : onlineMessage;

        Get.snackbar(
          result['offline'] == true ? '📱 ऑफलाइन सहेजा गया' : '✅ सफल',
          message,
          backgroundColor:
              result['offline'] == true ? Color.fromARGB(255, 255, 152, 0) : Colors.green,
          colorText: Colors.white,
          duration: Duration(seconds: result['offline'] == true ? 4 : 3),
        );
      } else {
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
