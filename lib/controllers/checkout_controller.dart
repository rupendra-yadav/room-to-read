import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:room_to_read/controllers/checkin_controller.dart';
import 'package:room_to_read/controllers/student_controller.dart';
import 'package:room_to_read/services/hybrid_api_service.dart';
import 'package:room_to_read/services/auth_service.dart';
import 'package:room_to_read/services/offline_database_service.dart';
import 'package:room_to_read/services/connectivity_service.dart';
import 'package:room_to_read/controllers/book_controller.dart';
import 'package:room_to_read/controllers/home_controller.dart';

class CheckoutController extends GetxController {
  late HybridApiService apiService;
  final AuthService _authService = Get.find<AuthService>();
  final ConnectivityService _connectivityService =
      Get.find<ConnectivityService>();

  // Text controllers for search fields
  final TextEditingController studentSearchController = TextEditingController();
  final TextEditingController bookSearchController = TextEditingController();

  var selectedClass = ''.obs;
  var selectedStudent = Rxn();
  var selectedBook = Rxn();
  var hasPotentialDuplicate =
      false.obs; // Track if selected book might be duplicate
  var studentSearchQuery = ''.obs;
  var bookSearchQuery = ''.obs;
  var checkoutHistory = <Map<String, dynamic>>[].obs;
  var classes = <String>[].obs;
  var isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    apiService = Get.find<HybridApiService>();

    // Load all required data for checkout
    _initializeCheckoutData();
  }

  Future<void> _initializeCheckoutData() async {
    try {
      print('🔄 CheckoutController: Initializing all required data...');
      isLoading.value = true;

      final isOnline = _connectivityService.isOnline.value;
      print('   Online: $isOnline');

      // Parallel loading of all required data
      await Future.wait([
        _ensureClassesLoaded(),
        _ensureStudentsLoaded(),
        _ensureBooksLoaded(),
      ]);

      // After loading, check if we need to prompt user to download data for offline
      if (isOnline) {
        await _checkAndPromptForDataDownload();
      }

      print('✅ CheckoutController: All data initialization complete');
      isLoading.value = false;
    } catch (e) {
      print('⚠️ CheckoutController: Error initializing data: $e');
      isLoading.value = false;
      Get.snackbar(
        'चेतावनी',
        'कुछ डेटा लोड नहीं हो सका। कृपया ऑनलाइन होकर "डेटा डाउनलोड करें" दबाएं।',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _checkAndPromptForDataDownload() async {
    try {
      print('🔍 Checking if offline cache needs updating...');

      final offlineDb = Get.find<OfflineDatabaseService>();
      final cachedBooks = await offlineDb.getBooksOffline();
      final cachedStudents = await offlineDb.getStudentsOffline();
      final cachedClasses = await offlineDb.getClassesOffline();

      print('   Cached books: ${cachedBooks.length}');
      print('   Cached students: ${cachedStudents.length}');
      print('   Cached classes: ${cachedClasses.length}');

      // If cache is empty or minimal, suggest data download
      if (cachedBooks.isEmpty || cachedStudents.isEmpty) {
        print('⚠️ Offline cache is incomplete');

        // Show subtle notification, not a blocking dialog
        print(
          '💡 Suggests user to use "डेटा डाउनलोड करें" button to cache data for offline use',
        );
      } else {
        print('✅ Offline cache is complete');
      }
    } catch (e) {
      print('⚠️ Error checking cache status: $e');
    }
  }

  Future<void> _ensureClassesLoaded() async {
    try {
      print('📚 CheckoutController: Ensuring classes are loaded...');
      if (classes.isEmpty) {
        print('   Classes not loaded, fetching...');
        await fetchClasses();
      } else {
        print('   Classes already loaded: ${classes.length} items');
      }
    } catch (e) {
      print('⚠️ Error loading classes: $e');
    }
  }

  Future<void> _ensureStudentsLoaded() async {
    try {
      print('👥 CheckoutController: Ensuring students are loaded...');
      final studentController = Get.find<StudentController>();

      if (studentController.students.isEmpty) {
        print('   Students not loaded, fetching...');
        await studentController.loadStudents();
      } else {
        print(
          '   Students already loaded: ${studentController.students.length} items',
        );
      }
    } catch (e) {
      print('⚠️ Error loading students: $e');
    }
  }

  Future<void> _ensureBooksLoaded() async {
    try {
      print('📖 CheckoutController: Ensuring books are loaded...');
      final bookController = Get.find<BookController>();
      final connectivity = Get.find<ConnectivityService>();

      print('   Online: ${connectivity.isOnline.value}');
      print('   Books in controller: ${bookController.books.length}');

      // Always reload books to ensure fresh data, not just when empty
      print('   Reloading books to ensure fresh data...');
      await bookController.loadBooks();

      print('   Books load completed. Count: ${bookController.books.length}');

      if (bookController.books.isEmpty) {
        print('⚠️ WARNING: No books loaded even after reload');
        print('   This might indicate an API or connectivity issue');
      } else {
        print('✅ ${bookController.books.length} books successfully loaded');
      }
    } catch (e) {
      print('⚠️ CheckoutController: Error ensuring books loaded: $e');
    }
  }

  @override
  void onClose() {
    studentSearchController.dispose();
    bookSearchController.dispose();
    super.onClose();
  }

  Future<void> fetchClasses() async {
    try {
      isLoading.value = true;
      print('📚 Fetching classes from HybridApiService...');

      final classList = await apiService.getClasses();

      print('   Classes returned: ${classList.length}');

      if (classList.isEmpty) {
        print('⚠️ No classes available from API or cache');
        classes.value = [];

        // Show message but don't block - user can still try to checkout if offline
        if (_connectivityService.isOnline.value) {
          Get.snackbar(
            'जानकारी',
            'कोई कक्षा सूचना उपलब्ध नहीं है। कृपया ऑनलाइन होकर "डेटा डाउनलोड करें" दबाएं।',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
        }
      } else {
        print('✅ Classes loaded: ${classList.length} items');
        for (
          int i = 0;
          i < (classList.length > 5 ? 5 : classList.length);
          i++
        ) {
          print('   • कक्षा: ${classList[i]}');
        }
        classes.value = classList;
      }
    } catch (e) {
      print('⚠️ Error fetching classes: $e');
      classes.value = [];
      Get.snackbar(
        'त्रुटि',
        'कक्षाएं लोड करने में विफल: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } finally {
      isLoading.value = false;
    }
  }

  void selectClass(String className) {
    selectedClass.value = className;
  }

  void selectStudent(dynamic student) {
    print('🔍 selectStudent called with student data:');
    print('   student.id: "${student.id}"');
    print('   student.code: "${student.code}"');
    print('   student.name: "${student.name}"');
    print('   student.className: "${student.className}"');

    selectedStudent.value = student;

    // Remove the selected student from the filtered list
    final studentController = Get.find<StudentController>();
    studentController.removeStudentFromFilteredList(student);

    // Clear the search text field
    studentSearchController.clear();
  }

  void selectBook(dynamic book) async {
    print('🔍 selectBook called with book: ${book.bookCode} (${book.bookId})');
    print(
      '🔍 Currently selected book: ${selectedBook.value?.bookCode} (${selectedBook.value?.bookId})',
    );

    // Check if this book is already selected
    if (selectedBook.value != null &&
        (selectedBook.value.bookCode == book.bookCode ||
            selectedBook.value.bookId == book.bookId)) {
      print('⚠️ Duplicate book selection prevented: ${book.bookCode}');
      Get.snackbar(
        'पहले से चयनित',
        'यह किताब पहले से चयनित है।',
        backgroundColor: Colors.blue,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
      return; // Don't select the same book again
    }

    // Check if the selected student already has this book checked out
    if (selectedStudent.value != null) {
      final student = selectedStudent.value;
      final currentUser = _authService.currentUser.value;

      if (currentUser != null) {
        try {
          print(
            '🔍 Checking if student ${student.code} already has book ${book.bookCode}...',
          );

          // Get fresh checked out books data
          final checkedOutBooks = await apiService.getCheckedOutBooks(
            teacherId: currentUser.code,
          );

          print(
            '📊 Found ${checkedOutBooks.length} checked out books for teacher ${currentUser.code}',
          );

          // DEBUG: Log all checked out books data
          print('📊 RAW CHECKED OUT BOOKS DATA:');
          for (int i = 0; i < checkedOutBooks.length; i++) {
            final book = checkedOutBooks[i];
            print('📖 Book $i: ${jsonEncode(book)}');
          }

          // Enhanced checking with multiple ID formats and comprehensive matching
          bool hasBookAlready = false;
          String matchDetails = '';

          for (final checkedOutBook in checkedOutBooks) {
            // Get all possible identifiers from the API response
            final bookCode =
                checkedOutBook['F4_LCODE']?.toString() ??
                checkedOutBook['bookCode']?.toString() ??
                '';
            final bookId = checkedOutBook['bookId']?.toString() ?? '';
            final bookName = checkedOutBook['F4_PARTYN']?.toString() ?? '';

            // Get student identifiers
            final studentId = checkedOutBook['F4_PARTY1']?.toString() ?? '';
            final studentName = checkedOutBook['F4_PARTY1N']?.toString() ?? '';

            print('🔍 Enhanced Comparing:');
            print(
              '   Target: Book=${book.bookCode}/${book.bookId}/"${book.title}", Student=${student.code}/${student.id}/${student.name}',
            );
            print(
              '   Existing: Book=$bookCode/$bookId/"$bookName", Student=$studentId/$studentName',
            );

            // Enhanced book matching - check all possible combinations
            final bookMatches =
                (bookCode.isNotEmpty &&
                    (bookCode == book.bookCode || bookCode == book.bookId)) ||
                (bookId.isNotEmpty &&
                    (bookId == book.bookCode || bookId == book.bookId)) ||
                (bookName.isNotEmpty &&
                    book.title.isNotEmpty &&
                    bookName.toLowerCase().trim() ==
                        book.title.toLowerCase().trim());

            // Enhanced student matching - check both ID and name
            final studentMatches =
                (studentId.isNotEmpty &&
                    (studentId == student.code || studentId == student.id)) ||
                (studentName.isNotEmpty &&
                    student.name.isNotEmpty &&
                    studentName.toLowerCase().trim() ==
                        student.name.toLowerCase().trim());

            print(
              '   Enhanced matches: Book=$bookMatches, Student=$studentMatches',
            );

            if (bookMatches && studentMatches) {
              hasBookAlready = true;
              matchDetails =
                  'Book: $bookCode/$bookId/"$bookName", Student: $studentId/$studentName';
              print('🚫 Enhanced match found: $matchDetails');
              break;
            }
          }

          if (hasBookAlready) {
            print(
              '⚠️ Student already has this book: ${book.bookCode} - $matchDetails',
            );

            // Check if the duplicate was found by book title match
            bool isDuplicateByTitle = false;
            for (final checkedOutBook in checkedOutBooks) {
              final existingBookName =
                  checkedOutBook['F4_PARTYN']?.toString() ?? '';
              if (existingBookName.toLowerCase().trim() ==
                  book.title.toLowerCase().trim()) {
                final existingStudentName =
                    checkedOutBook['F4_PARTY1N']?.toString() ?? '';
                if (existingStudentName.toLowerCase() ==
                    student.name.toLowerCase()) {
                  isDuplicateByTitle = true;
                  break;
                }
              }
            }

            if (isDuplicateByTitle) {
              // For duplicate by title, show warning but allow selection
              // The final validation will happen at checkout time
              Get.snackbar(
                'चेतावनी',
                'यह छात्र को यह किताब ("${book.title}") पहले से जारी है। चेकआउट के समय यह रोका जाएगा।',
                backgroundColor: Colors.orange,
                colorText: Colors.white,
                duration: const Duration(seconds: 3),
              );
              // Allow selection but mark it for final validation
            } else {
              // Show warning but allow selection for other cases
              Get.snackbar(
                'चेतावनी',
                'यह छात्र को यह किताब या समान किताब पहले से जारी हो सकती है। कृपया चेक इन सूची देखें।',
                backgroundColor: Colors.amber,
                colorText: Colors.white,
                duration: const Duration(seconds: 3),
              );
              // Allow selection but show warning
            }
          } else {
            print('✅ No duplicate found - student can have this book');
          }
        } catch (e) {
          print('⚠️ Error checking duplicate books: $e');
          // Show warning but allow selection
          Get.snackbar(
            'चेतावनी',
            'डुप्लिकेट चेक नहीं हो सका। कृपया सुनिश्चित करें कि यह किताब पहले से जारी नहीं है।',
            backgroundColor: Colors.amber,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
        }
      }
    }

    print('✅ Selecting book: ${book.bookCode}');
    selectedBook.value = book;

    // 🎯 COMPREHENSIVE LOGGING: Print all details of the SELECTED BOOK that will be used for checkout
    print('\n📚 BOOK SELECTED - COMPLETE DETAILS FOR CHECKOUT:');
    print('   📖 Title (display): "${book.title}"');
    print('   📝 BookName (EN): "${book.bookRomanName}"');
    print('   📝 BookName (Local): "${book.bookLocalName}"');
    print('   🏷️  BookId (M1_CODE / Database ID): "${book.bookId}"');
    print('   🏷️  BookCode (M1_NO / API Code): "${book.bookCode}"');
    print('   👤 Author: "${book.author}"');
    print(
      '   📊 Status: "${book.statusText}" (Available: ${book.availableCopies}/${book.totalCopies})',
    );
    print('   🔴 Reading Level: ${book.readingLevel}');
    print('   ✅ Is Active: ${book.isActive}');
    print('   🎓 Program Code: "${book.programCode}"');
    print('   ✅ Stored in selectedBook.value');
    print('===============================================');

    // 💾 CHECK OFFLINE DATABASE for this book
    _logSelectedBookInOfflineDB(book);
  }

  // Helper method to log selected book details in offline database
  Future<void> _logSelectedBookInOfflineDB(dynamic book) async {
    try {
      final offlineDb = Get.find<OfflineDatabaseService>();
      final db = await offlineDb.database;

      print('\n💾 CHECKING OFFLINE DATABASE FOR SELECTED BOOK:');
      print(
        '   Searching for bookId: "${book.bookId}" OR bookCode: "${book.bookCode}"',
      );

      // Query offline database for this book
      final dbBooks = await db.query(
        'books',
        where: 'bookId = ? OR code = ? OR no = ?',
        whereArgs: [book.bookId, book.bookCode, book.bookId],
      );

      print(
        '   📊 Found ${dbBooks.length} matching book(s) in offline database',
      );

      if (dbBooks.isNotEmpty) {
        for (int i = 0; i < dbBooks.length; i++) {
          final dbBook = dbBooks[i];
          print('\n   📖 OFFLINE DB - Book Entry $i:');
          print('      id: "${dbBook['id']}"');
          print('      bookId: "${dbBook['bookId']}"');
          print('      code: "${dbBook['code']}"');
          print('      no: "${dbBook['no']}"');
          print('      name: "${dbBook['name']}"');
          print('      lname: "${dbBook['lname']}"');
          print('      txt1: "${dbBook['txt1']}"');
          print('      txt2: "${dbBook['txt2']}"');
          print('      txt3: "${dbBook['txt3']}"');
          print('      txt4: "${dbBook['txt4']}"');
          print('      txt5: "${dbBook['txt5']}"');
          print('      type: "${dbBook['type']}"');

          // Compare with selected book
          print('\n   ✅ COMPARISON WITH SELECTED BOOK:');
          print(
            '      Match bookId: ${dbBook['bookId'].toString() == book.bookId}',
          );
          print(
            '      Match code: ${dbBook['code'].toString() == book.bookCode}',
          );
          print('      Match no: ${dbBook['no'].toString() == book.bookId}');
          print('      DB txt3 (available): ${dbBook['txt3']}');
          print('      Dart availableCopies: ${book.availableCopies}');
        }
      } else {
        print('   ❌ NO MATCHING BOOK FOUND IN OFFLINE DATABASE!');
        print('   📝 This book may not have been cached locally');
      }

      // Also check for pending offline transactions for this book
      if (selectedStudent.value != null) {
        final student = selectedStudent.value;
        print('\n💾 CHECKING PENDING OFFLINE TRANSACTIONS:');
        print('   For Student: "${student.name}" (ID: ${student.code})');
        print('   For Book: "${book.title}" (ID: ${book.bookId})');

        try {
          List<Map<String, dynamic>> pendingTransactions = [];
          List<Map<String, dynamic>> pendingTransactionsEnh = [];

          try {
            pendingTransactions = await db.query(
              'offline_transactions',
              where: 'studentId = ? AND bookId = ? AND type = ?',
              whereArgs: [student.code, book.bookId, 'checkout'],
            );
          } catch (e) {
            print('   ⚠️ Error querying legacy transactions: $e');
          }

          try {
            pendingTransactionsEnh = await db.query(
              'offline_transactions_enhanced',
              where: 'student_id = ? AND book_id = ? AND transaction_type = ?',
              whereArgs: [student.code, book.bookId, 'checkout'],
            );
          } catch (e) {
            print('   ⚠️ Error querying enhanced transactions: $e');
          }

          print(
            '   Found ${pendingTransactions.length} unsynced checkout(s) (legacy table)',
          );
          print(
            '   Found ${pendingTransactionsEnh.length} unsynced checkout(s) (enhanced table)',
          );

          if (pendingTransactions.isNotEmpty) {
            for (int i = 0; i < pendingTransactions.length; i++) {
              final txn = pendingTransactions[i];
              print('\n   📋 PENDING TRANSACTION (Legacy) $i:');
              print('      id: "${txn['id']}"');
              print('      studentId: "${txn['studentId']}"');
              print('      bookId: "${txn['bookId']}"');
              print('      bookName: "${txn['bookName']}"');
              print('      bookCode: "${txn['bookCode']}"');
              print('      synced: ${txn['synced']}');
              print('      timestamp: "${txn['timestamp']}"');
            }
          }

          if (pendingTransactionsEnh.isNotEmpty) {
            for (int i = 0; i < pendingTransactionsEnh.length; i++) {
              final txn = pendingTransactionsEnh[i];
              print('\n   📋 PENDING TRANSACTION (Enhanced) $i:');
              print('      transaction_id: "${txn['transaction_id']}"');
              print('      student_id: "${txn['student_id']}"');
              print('      book_id: "${txn['book_id']}"');
              print('      student_name: "${txn['student_name']}"');
              print('      book_name: "${txn['book_name']}"');
              print('      book_code: "${txn['book_code']}"');
              print('      synced: ${txn['synced']}');
              print('      created_at: "${txn['created_at']}"');
            }
          }
        } catch (e) {
          print('   ⚠️ Error checking transactions: $e');
        }
      }

      print('===============================================\n');
    } catch (e) {
      print('⚠️ Error checking offline database: $e');
    }
  }

  void clearStudentSelection() {
    // Add the student back to the filtered list if there was a selection
    if (selectedStudent.value != null) {
      final studentController = Get.find<StudentController>();
      studentController.addStudentBackToFilteredList(selectedStudent.value);
    }

    selectedStudent.value = null;
  }

  void clearBookSelection() {
    selectedBook.value = null;
  }

  void clearSelection() {
    // Add the student back to the filtered list if there was a selection
    if (selectedStudent.value != null) {
      final studentController = Get.find<StudentController>();
      studentController.addStudentBackToFilteredList(selectedStudent.value);
    }

    selectedStudent.value = null;
    selectedBook.value = null;
  }

  bool canCheckout() {
    return selectedStudent.value != null &&
        selectedBook.value != null &&
        selectedClass.value.isNotEmpty;
  }

  Future<Map<String, dynamic>> completeCheckout() async {
    if (!canCheckout()) {
      return {
        'success': false,
        'message': 'Please select student, book and class',
      };
    }

    // Verify all required data is available before checkout
    final dataCheck = await _verifyDataAvailability();
    if (!dataCheck['available']) {
      return {
        'success': false,
        'message': dataCheck['message'] ?? 'Required data is not available',
      };
    }

    try {
      isLoading.value = true;

      final student = selectedStudent.value;
      final book = selectedBook.value;
      final currentUser = _authService.currentUser.value;

      if (currentUser == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      // Use same structure as checkin for consistency
      final teacherId = currentUser.code;
      final bookId = book
          .bookId; // ✅ CORRECTED: Use bookId (M1_NO - actual database ID like "3893"), NOT bookCode
      final bookCode = book.bookCode; // Store code separately for reference
      // Try to use numeric student code instead of alphanumeric ID
      final studentId = student.code.isNotEmpty
          ? student.code
          : student
                .id; // Use student.code first (likely numeric), fallback to student.id
      final className = selectedClass.value;
      final programId = currentUser.group; // ✅ M1_GROUP1 = program_id
      final schoolId = currentUser.group1; // ✅ M1_GROUP = school_id

      print('\n📚 ========== CHECKOUT: PREPARING SUBMISSION ==========');
      print('🎯 CHECKOUT PARAMETERS:');
      print('   📖 Book Title: "${book.title}"');
      print('   🏷️  BookId (M1_CODE): $bookId');
      print('   🏷️  BookCode (M1_NO): $bookCode');
      print('   📝 Book Name (EN): "${book.bookRomanName}"');
      print('   📝 Book Name (Local): "${book.bookLocalName}"');
      print('   👤 Author: "${book.author}"');
      print('   📊 Available: ${book.availableCopies}/${book.totalCopies}');
      print('   teacherId: $teacherId');
      print('   studentId: $studentId (from student.code: ${student.code})');
      print('   student.id: ${student.id}');
      print('   student.name: "${student.name}"');
      print('   className: $className');
      print('   programId: $programId');
      print('   schoolId: $schoolId');
      print('===================================================\n');
      print(
        '   STUDENT DATA: id="${student.id}", code="${student.code}", name="${student.name}"',
      ); // Complete student data
      print('   className: $className');
      print('   programId: $programId');
      print('   schoolId: $schoolId');

      // Validate required fields using same validation as checkin
      final missingFields = <String>[];
      if (teacherId.isEmpty) missingFields.add('teacher_id');
      if (bookId.isEmpty) missingFields.add('book_id');
      if (studentId.isEmpty) missingFields.add('student_id');
      if (className.isEmpty) missingFields.add('class');
      if (schoolId.isEmpty) missingFields.add('school_id');

      if (missingFields.isNotEmpty) {
        return {
          'success': false,
          'message': 'आवश्यक फील्ड गुम हैं: ${missingFields.join(', ')}',
        };
      }

      // Check book availability before checkout
      // Note: We'll do a fresh check from database to ensure accuracy
      final freshBookAvailability = await _checkBookAvailabilityFromDatabase(
        bookId,
      );

      if (freshBookAvailability <= 0) {
        return {
          'success': false,
          'message':
              'यह किताब उपलब्ध नहीं है। उपलब्ध प्रतियां: $freshBookAvailability',
        };
      }

      print(
        '📚 Book availability check passed: $freshBookAvailability copies available',
      );

      // COMPREHENSIVE DUPLICATE CHECK: Debug what the API actually returns
      print('🔍 COMPREHENSIVE duplicate check before API call...');
      print(
        '🎯 TARGET VALUES: bookId=$bookId, book.bookCode=${book.bookCode}, studentId=$studentId, student.name="${student.name}"',
      );

      try {
        final checkedOutBooks = await apiService.getCheckedOutBooks(
          teacherId: teacherId,
        );

        print(
          '📊 COMPREHENSIVE CHECK: Found ${checkedOutBooks.length} checked out books',
        );

        // Log ALL data from each checked out book to understand the structure
        for (int i = 0; i < checkedOutBooks.length; i++) {
          final checkedOutBook = checkedOutBooks[i];
          print('📖 BOOK $i COMPLETE DATA: ${jsonEncode(checkedOutBook)}');

          // Extract all possible identifiers
          final existingBookCode = checkedOutBook['F4_LCODE']?.toString() ?? '';
          final existingBookId = checkedOutBook['bookId']?.toString() ?? '';
          final existingBookName =
              checkedOutBook['F4_PARTYN']?.toString() ?? '';
          final existingStudentId =
              checkedOutBook['F4_PARTY1']?.toString() ?? '';
          final existingStudentName =
              checkedOutBook['F4_PARTY1N']?.toString() ?? '';

          print('📖 BOOK $i EXTRACTED:');
          print('   BookCode (F4_LCODE): "$existingBookCode"');
          print('   BookId: "$existingBookId"');
          print('   BookName (F4_PARTYN): "$existingBookName"');
          print('   StudentId (F4_PARTY1): "$existingStudentId"');
          print('   StudentName (F4_PARTY1N): "$existingStudentName"');
          print('   ALL AVAILABLE FIELDS: ${checkedOutBook.keys.toList()}');

          // Check for matches with detailed logging
          final bookCodeMatch = existingBookCode == bookId;
          final bookIdMatch = existingBookId == bookId;
          final studentIdMatch = existingStudentId == studentId;
          final studentNameMatch =
              existingStudentName.toLowerCase().trim() ==
              student.name.toLowerCase().trim();

          print('📖 BOOK $i MATCHES:');
          print(
            '   BookCode match ($existingBookCode == $bookId): $bookCodeMatch',
          );
          print('   BookId match ($existingBookId == $bookId): $bookIdMatch');
          print(
            '   StudentId match ($existingStudentId == $studentId): $studentIdMatch',
          );
          print(
            '   StudentName match ("${existingStudentName.toLowerCase().trim()}" == "${student.name.toLowerCase().trim()}"): $studentNameMatch',
          );

          // Check if this is the duplicate the API is detecting
          if ((bookCodeMatch || bookIdMatch) &&
              (studentIdMatch || studentNameMatch)) {
            print('🚫 FOUND THE DUPLICATE THE API DETECTS!');
            print(
              '   This is why the API says "Student Already Issued selected Book!"',
            );

            Get.snackbar(
              'डुप्लिकेट चेकआउट',
              'यह छात्र को यह किताब पहले से जारी है। (Book: $existingBookCode, Student: $existingStudentName)',
              backgroundColor: Colors.red,
              colorText: Colors.white,
              duration: const Duration(seconds: 4),
            );

            return {
              'success': false,
              'message':
                  'Student already has this book - detected before API call',
            };
          }
        }

        // FORCE REFRESH: Get the absolute latest data directly from API before checkout
        print(
          '🔄 FORCE REFRESH: Getting latest checked out books directly from API...',
        );
        try {
          // Force refresh the checked out books data
          if (Get.isRegistered<CheckinController>()) {
            final checkinController = Get.find<CheckinController>();
            await checkinController.refreshCheckedOutBooks();
            print('✅ Forced refresh of checked out books completed');

            // Get the data again after refresh
            final refreshedBooks = await apiService.getCheckedOutBooks(
              teacherId: teacherId,
            );

            print(
              '📊 AFTER REFRESH: Found ${refreshedBooks.length} checked out books',
            );

            // Check again with refreshed data
            for (int i = 0; i < refreshedBooks.length; i++) {
              final checkedOutBook = refreshedBooks[i];
              print('📖 REFRESHED BOOK $i: ${jsonEncode(checkedOutBook)}');

              final existingBookCode =
                  checkedOutBook['F4_LCODE']?.toString() ?? '';
              final existingStudentName =
                  checkedOutBook['F4_PARTY1N']?.toString() ?? '';
              final existingStudentId =
                  checkedOutBook['F4_PARTY1']?.toString() ?? '';

              // Check all possible matches
              final bookMatch = existingBookCode == bookId;
              final studentNameMatch =
                  existingStudentName.toLowerCase().trim() ==
                  student.name.toLowerCase().trim();
              final studentIdMatch = existingStudentId == studentId;

              print('📖 REFRESHED BOOK $i MATCHES:');
              print(
                '   BookCode match ($existingBookCode == $bookId): $bookMatch',
              );
              print(
                '   StudentName match ("${existingStudentName.toLowerCase().trim()}" == "${student.name.toLowerCase().trim()}"): $studentNameMatch',
              );
              print(
                '   StudentId match ($existingStudentId == $studentId): $studentIdMatch',
              );

              if (bookMatch && (studentNameMatch || studentIdMatch)) {
                print('🚫 FOUND DUPLICATE IN REFRESHED DATA!');

                Get.snackbar(
                  'डुप्लिकेट चेकआउट',
                  'यह छात्र को यह किताब पहले से जारी है। (रिफ्रेश के बाद मिला)',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                  duration: const Duration(seconds: 4),
                );

                return {
                  'success': false,
                  'message':
                      'Student already has this book - found after refresh',
                };
              }
            }

            print(
              '✅ AFTER REFRESH: Still no duplicates found, API might have different data source',
            );
          }
        } catch (e) {
          print('⚠️ Force refresh failed: $e');
        }
      } catch (e) {
        print('⚠️ Comprehensive duplicate check failed: $e');
      }

      // SIMPLIFIED OFFLINE CHECK: Only check for exact matches
      try {
        print(
          '🔍 SIMPLIFIED OFFLINE CHECK: Looking for exact offline duplicates...',
        );
        final offlineDb = Get.find<OfflineDatabaseService>();
        final db = await offlineDb.database;

        // Simple check for exact matches only
        final recentTransactions = await db.query(
          'offline_transactions',
          where:
              'teacherId = ? AND type = ? AND synced = ? AND bookId = ? AND studentId = ?',
          whereArgs: [teacherId, 'checkout', 0, bookId, studentId],
        );

        print(
          '🔍 SIMPLIFIED OFFLINE CHECK: Found ${recentTransactions.length} exact matches',
        );

        if (recentTransactions.isNotEmpty) {
          print('🚫 SIMPLIFIED OFFLINE CHECK: Found exact offline duplicate');

          Get.snackbar(
            'ऑफलाइन डुप्लिकेट',
            'यह चेकआउट पहले से ऑफलाइन सेव है।',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );

          return {
            'success': false,
            'message': 'Duplicate offline transaction found',
          };
        }
      } catch (e) {
        print('⚠️ Simplified offline check failed: $e - proceeding');
      }

      final result = await apiService.checkout(
        teacherId: teacherId,
        bookId: bookId,
        bookCode: bookCode,
        studentId: studentId,
        className: className,
        programId: programId,
        schoolId: schoolId,
        studentName: student.name, // ✅ Pass student name for offline storage
        bookName: book.title, // ✅ Pass book title for offline storage
      );

      if (result['success'] == true) {
        // Log the API response to see what was returned
        print('\n✅ CHECKOUT SUCCESS - API RESPONSE:');
        print('   Full Result: ${jsonEncode(result)}');
        if (result.containsKey('data')) {
          print('   Data from API: ${jsonEncode(result['data'])}');
        }

        // Add to local history
        checkoutHistory.add({
          'student': student,
          'book': book,
          'class': selectedClass.value,
          'date': DateTime.now(),
          'dueDate': DateTime.now().add(const Duration(days: 14)),
        });

        print('✅ Added to local history:');
        print('   Book Title: "${book.title}"');
        print('   Book ID: "${book.bookId}"');
        print('   Book Code: "${book.bookCode}"');
        print('   Student: "${student.name}" (ID: ${student.id})');
        print('   Class: $className\n');

        // Refresh controllers
        try {
          // Add delay to ensure server has processed the checkout
          await Future.delayed(Duration(milliseconds: 800));

          final bookController = Get.find<BookController>();
          print('🔄 CHECKOUT: Refreshing BookController with fresh data...');
          await bookController.loadBooks();
          print(
            '✅ CHECKOUT: BookController refreshed - available books count updated',
          );
        } catch (e) {
          print('⚠️ CHECKOUT: Failed to refresh BookController: $e');
        }

        try {
          final homeController = Get.find<HomeController>();
          await homeController.refreshCounts();
        } catch (e) {
          print('⚠️ CHECKOUT: Failed to refresh HomeController: $e');
        }

        // ✅ CRITICAL: Refresh checkin data after offline checkout
        try {
          // Add a small delay to ensure checkout is fully processed on server
          await Future.delayed(Duration(milliseconds: 500));

          print('🔄 CHECKOUT: Attempting to refresh CheckinController...');

          // Try to find the checkin controller, if it exists, refresh it
          if (Get.isRegistered<CheckinController>()) {
            print('   📋 CheckinController is registered, refreshing...');
            final checkinController = Get.find<CheckinController>();
            print(
              '🔄 CHECKOUT: Refreshing CheckinController after successful checkout...',
            );
            await checkinController.refreshCheckedOutBooks();
            print('✅ CHECKOUT: CheckinController refreshed successfully');
          } else {
            print('   ℹ️ CheckinController not registered yet');
            print(
              '   ⚠️ Checkin page will show data when user navigates to it',
            );
          }
        } catch (e) {
          print('❌ CHECKOUT: Error refreshing CheckinController: $e');
          print('   Stack trace: $e');
        }

        // Clear selections
        clearSelection();
        selectedClass.value = '';

        // Show appropriate success message
        final message = result['offline'] == true
            ? 'किताब ऑफलाइन जारी की गई! 📱\nऑनलाइन होने पर यह स्वचालित रूप से सिंक होगा।'
            : result['message'] ?? 'किताब सफलतापूर्वक जारी की गई!';

        final snackbackColor = result['offline'] == true
            ? Color.fromARGB(255, 255, 152, 0) // Orange for offline
            : Colors.green;

        Get.snackbar(
          result['offline'] == true ? '📱 ऑफलाइन सहेजा गया' : '✅ सफल',
          message,
          backgroundColor: snackbackColor,
          colorText: Colors.white,
          duration: Duration(seconds: result['offline'] == true ? 4 : 3),
        );
      } else {
        // Show error message with specific handling for duplicate book error
        String errorMessage = result['message'] ?? 'चेकआउट असफल';

        // Check for specific duplicate book error
        if (errorMessage.contains('Student Already Issued selected Book!') ||
            errorMessage.contains('Student Already Issued')) {
          errorMessage =
              'यह छात्र को यह किताब पहले से जारी है। कृपया चेक इन सूची में देखें या दूसरी किताब चुनें।';

          // Also refresh the checked out books to get the latest data
          print(
            '🔄 Refreshing checked out books due to duplicate detection...',
          );
          try {
            if (Get.isRegistered<CheckinController>()) {
              final checkinController = Get.find<CheckinController>();
              await checkinController.refreshCheckedOutBooks();
              print('✅ Checked out books refreshed');
            }
          } catch (e) {
            print('⚠️ Error refreshing checked out books: $e');
          }
        }

        Get.snackbar(
          'त्रुटि',
          errorMessage,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: Duration(seconds: 4),
        );
      }

      return result;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    } finally {
      isLoading.value = false;
    }
  }

  // Helper method to check book availability from database
  Future<int> _checkBookAvailabilityFromDatabase(String bookId) async {
    try {
      // Get the offline database service
      final offlineDb = Get.find<OfflineDatabaseService>();
      final db = await offlineDb.database;

      // Query the book from database
      final books = await db.query(
        'books',
        where: 'code = ? OR bookId = ?',
        whereArgs: [bookId, bookId],
        limit: 1,
      );

      if (books.isNotEmpty) {
        final book = books.first;
        final available = int.tryParse(book['txt3']?.toString() ?? '0') ?? 0;

        print('📚 Fresh book availability from database:');
        print('   bookId: $bookId');
        print('   available copies (txt3): $available');

        return available;
      } else {
        print('! Book not found in database: $bookId');

        // Try to fetch the book from API and save it locally
        if (_connectivityService.isOnline.value) {
          print('🌐 Attempting to fetch book from API...');
          try {
            final currentUser = _authService.currentUser.value;
            if (currentUser != null) {
              // Fetch all books to find this one
              final allBooks = await apiService.getBooks(
                userId: currentUser.code,
              );
              final targetBook = allBooks
                  .where((b) => b.bookId == bookId || b.bookCode == bookId)
                  .firstOrNull;

              if (targetBook != null) {
                print('✅ Found book in API: ${targetBook.bookName}');
                print('   Available: ${targetBook.availableCopy}');

                // Save this book to local database
                await offlineDb.saveBooksOffline([
                  {
                    'book_id': targetBook.bookId.isNotEmpty
                        ? targetBook.bookId
                        : targetBook.bookCode,
                    'book_code': targetBook.bookCode,
                    'book_name': targetBook.bookName,
                    'available_copy': targetBook.availableCopy,
                    'issued_copy': targetBook.issuedCopy,
                    'total_copy': targetBook.totalCopy,
                    'damaged_copy': targetBook.damagedCopy,
                    'lost_copy': targetBook.lostCopy,
                    'reading_level': targetBook.readingLevel,
                    'program_code': targetBook.programCode,
                    'code': targetBook.bookCode,
                    'no': targetBook.bookId.isNotEmpty
                        ? targetBook.bookId
                        : targetBook.bookCode,
                    'name': targetBook.bookName,
                    'txt1': targetBook.readingLevel.toString(),
                    'txt2': targetBook.totalCopy.toString(),
                    'txt3': targetBook.availableCopy.toString(),
                    'txt4': targetBook.issuedCopy.toString(),
                    'txt5': targetBook.damagedCopy.toString(),
                    'bookId': targetBook.bookId.isNotEmpty
                        ? targetBook.bookId
                        : targetBook.bookCode,
                  },
                ]);

                print('✅ Book saved to local database');
                return targetBook.availableCopy;
              } else {
                print('❌ Book not found in API either');
              }
            }
          } catch (e) {
            print('❌ Error fetching book from API: $e');
          }
        } else {
          print('📵 Offline - cannot fetch book from API');
        }

        return 0;
      }
    } catch (e) {
      print('❌ Error checking book availability from database: $e');
      return 0;
    }
  }

  // Verify that all required data is available for checkout
  Future<Map<String, dynamic>> _verifyDataAvailability() async {
    try {
      print('🔍 Verifying data availability for checkout...');

      // Check classes
      if (classes.isEmpty) {
        print('❌ No classes available');
        return {
          'available': false,
          'message':
              'कक्षाओं का डेटा उपलब्ध नहीं है। कृपया ऑनलाइन होकर डेटा डाउनलोड करें।',
        };
      }
      print('✅ Classes available: ${classes.length}');

      // Check students
      try {
        final studentController = Get.find<StudentController>();
        if (studentController.students.isEmpty) {
          print('❌ No students available');
          return {
            'available': false,
            'message':
                'छात्रों का डेटा उपलब्ध नहीं है। कृपया ऑनलाइन होकर डेटा डाउनलोड करें।',
          };
        }
        print('✅ Students available: ${studentController.students.length}');
      } catch (e) {
        print('⚠️ Could not check students: $e');
      }

      // Check books
      try {
        final bookController = Get.find<BookController>();
        if (bookController.books.isEmpty) {
          print('❌ No books available');

          // Try to load from offline database
          final offlineDb = Get.find<OfflineDatabaseService>();
          final offlineBooks = await offlineDb.getBooksOffline();

          if (offlineBooks.isEmpty) {
            return {
              'available': false,
              'message':
                  'किताबों का डेटा उपलब्ध नहीं है। कृपया ऑनलाइन होकर "डेटा डाउनलोड करें" दबाएं।',
            };
          }
          print('✅ Books available in offline cache: ${offlineBooks.length}');
        } else {
          print('✅ Books available: ${bookController.books.length}');
        }
      } catch (e) {
        print('⚠️ Could not check books: $e');
      }

      print('✅ All data verification passed');
      return {'available': true};
    } catch (e) {
      print('⚠️ Error verifying data availability: $e');
      return {'available': false, 'message': 'डेटा सत्यापन में त्रुटि: $e'};
    }
  }
}
