import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:room_to_read/controllers/checkin_controller.dart';
import 'package:room_to_read/controllers/student_controller.dart';
import 'package:room_to_read/models/grade_model.dart';
import 'package:room_to_read/models/student_model.dart';
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

  // ✅ MULTI-SELECT: selectedBooks is the source of truth (list)
  final selectedBooks = <dynamic>[].obs;

  var hasPotentialDuplicate = false.obs;
  var studentSearchQuery = ''.obs;
  var bookSearchQuery = ''.obs;
  var checkoutHistory = <Map<String, dynamic>>[].obs;
  var classes = <Grade>[].obs;
  var isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    apiService = Get.find<HybridApiService>();
    _initializeCheckoutData();
  }

  Future<void> _initializeCheckoutData() async {
    try {
      print('🔄 CheckoutController: Initializing all required data...');
      isLoading.value = true;

      final isOnline = _connectivityService.isOnline.value;
      print('   Online: $isOnline');

      await Future.wait([
        _ensureClassesLoaded(),
        _ensureStudentsLoaded(),
        _ensureBooksLoaded(),
      ]);

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

      if (cachedBooks.isEmpty || cachedStudents.isEmpty) {
        print('⚠️ Offline cache is incomplete');
      } else {
        print('✅ Offline cache is complete');
      }
    } catch (e) {
      print('⚠️ Error checking cache status: $e');
    }
  }

  Future<void> _ensureClassesLoaded() async {
    try {
      if (classes.isEmpty) {
        await fetchClasses();
      }
    } catch (e) {
      print('⚠️ Error loading classes: $e');
    }
  }

  Future<void> _ensureStudentsLoaded() async {
    try {
      final studentController = Get.find<StudentController>();

      if (studentController.students.isNotEmpty) return;

      if (!_connectivityService.isOnline.value) {
        // ✅ Offline: load directly from offline DB, skip API
        print('📱 Offline mode: Loading students from offline DB...');
        final offlineDb = Get.find<OfflineDatabaseService>();
        final currentUser = _authService.currentUser.value;
        final offlineStudents = await offlineDb.getStudentsOffline(
          teacherId: currentUser?.code,
        );

        if (offlineStudents.isNotEmpty) {
          studentController.students.value = offlineStudents.map((data) {
            return Student(
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
            );
          }).toList();
          studentController.filteredStudents.value = studentController.students
              .toList();
          print('✅ Loaded ${offlineStudents.length} students from offline DB');
        } else {
          print('⚠️ No students found in offline DB');
        }
      } else {
        await studentController.loadStudents();
      }
    } catch (e) {
      print('⚠️ Error loading students: $e');
    }
  }

  Future<void> _ensureBooksLoaded() async {
    try {
      final bookController = Get.find<BookController>();
      await bookController.loadBooks();
      print('✅ ${bookController.books.length} books successfully loaded');
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
      final gradeList = await apiService.getGrades();

      if (gradeList.isEmpty) {
        classes.value = [];
        if (_connectivityService.isOnline.value) {
          Get.snackbar(
            'जानकारी',
            'कोई ग्रेड सूचना उपलब्ध नहीं है।',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
        }
      } else {
        classes.value = gradeList;
      }
    } catch (e) {
      print('⚠️ Error fetching grades: $e');
      classes.value = [];
      Get.snackbar(
        'त्रुटि',
        'ग्रेड लोड करने में विफल: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } finally {
      isLoading.value = false;
    }
  }

  void selectClass(Grade grade) {
    selectedClass.value = grade.name;
  }

  void selectStudent(dynamic student) {
    selectedStudent.value = student;

    final studentController = Get.find<StudentController>();
    studentController.removeStudentFromFilteredList(student);

    studentSearchController.clear();
  }

  // ✅ FIXED: selectBook now adds to the list and checks for duplicates properly
  void selectBook(dynamic book) async {
    print('🔍 selectBook called: ${book.bookCode} / ${book.bookId}');

    // Check if this book is already in the selected list
    final alreadySelected = selectedBooks.any(
      (b) =>
          (b.bookCode.isNotEmpty &&
              book.bookCode.isNotEmpty &&
              b.bookCode == book.bookCode) ||
          (b.bookId.isNotEmpty &&
              book.bookId.isNotEmpty &&
              b.bookId == book.bookId),
    );

    if (alreadySelected) {
      print('⚠️ Duplicate book selection prevented: ${book.bookCode}');
      Get.snackbar(
        'पहले से चयनित',
        'यह किताब पहले से चयनित है।',
        backgroundColor: Colors.blue,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    // Check if the selected student already has this book checked out
    if (selectedStudent.value != null) {
      final student = selectedStudent.value;
      final currentUser = _authService.currentUser.value;

      if (currentUser != null) {
        try {
          final checkedOutBooks = await apiService.getCheckedOutBooks(
            teacherId: currentUser.code,
          );

          bool hasBookAlready = false;
          String matchDetails = '';

          for (final checkedOutBook in checkedOutBooks) {
            final existingBookCode =
                checkedOutBook['F4_LCODE']?.toString() ?? '';
            final existingBookId = checkedOutBook['bookId']?.toString() ?? '';
            final existingBookName =
                checkedOutBook['F4_PARTYN']?.toString() ?? '';
            final existingStudentId =
                checkedOutBook['F4_PARTY1']?.toString() ?? '';
            final existingStudentName =
                checkedOutBook['F4_PARTY1N']?.toString() ?? '';

            final bookMatches =
                (existingBookCode.isNotEmpty &&
                    (existingBookCode == book.bookCode ||
                        existingBookCode == book.bookId)) ||
                (existingBookId.isNotEmpty &&
                    (existingBookId == book.bookCode ||
                        existingBookId == book.bookId)) ||
                (existingBookName.isNotEmpty &&
                    book.title.isNotEmpty &&
                    existingBookName.toLowerCase().trim() ==
                        book.title.toLowerCase().trim());

            final studentMatches =
                (existingStudentId.isNotEmpty &&
                    (existingStudentId == student.code ||
                        existingStudentId == student.id)) ||
                (existingStudentName.isNotEmpty &&
                    student.name.isNotEmpty &&
                    existingStudentName.toLowerCase().trim() ==
                        student.name.toLowerCase().trim());

            if (bookMatches && studentMatches) {
              hasBookAlready = true;
              matchDetails =
                  'Book: $existingBookCode/"$existingBookName", Student: $existingStudentId/$existingStudentName';
              break;
            }
          }

          if (hasBookAlready) {
            Get.snackbar(
              'चेतावनी',
              'यह छात्र को "${book.title}" पहले से जारी है। ($matchDetails)',
              backgroundColor: Colors.orange,
              colorText: Colors.white,
              duration: const Duration(seconds: 3),
            );
            // Show warning but allow selection — final block happens at checkout
          }
        } catch (e) {
          print('⚠️ Error checking duplicate books: $e');
          Get.snackbar(
            'चेतावनी',
            'डुप्लिकेट चेक नहीं हो सका।',
            backgroundColor: Colors.amber,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
        }
      }
    }

    print('✅ Adding book to selection: ${book.bookCode}');
    selectedBooks.add(book);
    _logSelectedBookInOfflineDB(book);
  }

  // ✅ FIXED: Remove a specific book from the selected list
  void removeBook(dynamic book) {
    selectedBooks.removeWhere(
      (b) =>
          (b.bookCode.isNotEmpty &&
              book.bookCode.isNotEmpty &&
              b.bookCode == book.bookCode) ||
          (b.bookId.isNotEmpty &&
              book.bookId.isNotEmpty &&
              b.bookId == book.bookId),
    );
    print('🗑️ Book removed from selection: ${book.bookCode}');
  }

  Future<void> _logSelectedBookInOfflineDB(dynamic book) async {
    try {
      final offlineDb = Get.find<OfflineDatabaseService>();
      final db = await offlineDb.database;

      final dbBooks = await db.query(
        'books',
        where: 'bookId = ? OR code = ? OR no = ?',
        whereArgs: [book.bookId, book.bookCode, book.bookId],
      );

      print('💾 Offline DB match for "${book.title}": ${dbBooks.length} found');
    } catch (e) {
      print('⚠️ Error checking offline database: $e');
    }
  }

  void clearStudentSelection() {
    if (selectedStudent.value != null) {
      final studentController = Get.find<StudentController>();
      studentController.addStudentBackToFilteredList(selectedStudent.value);
    }
    selectedStudent.value = null;
  }

  void clearBookSelection() {
    selectedBooks.clear();
  }

  void clearSelection() {
    if (selectedStudent.value != null) {
      final studentController = Get.find<StudentController>();
      studentController.addStudentBackToFilteredList(selectedStudent.value);
    }
    selectedStudent.value = null;
    selectedBooks.clear();
  }

  bool canCheckout() {
    return selectedStudent.value != null &&
        selectedBooks.isNotEmpty &&
        selectedClass.value.isNotEmpty;
  }

  Future<Map<String, dynamic>> completeCheckout() async {
    if (!canCheckout()) {
      return {'success': false, 'message': 'कृपया छात्र, किताब और ग्रेड चुनें'};
    }

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
      final currentUser = _authService.currentUser.value;

      if (currentUser == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      final teacherId = currentUser.code;
      final studentId = student.code.isNotEmpty ? student.code : student.id;
      final className = selectedClass.value;
      final programId = currentUser.group;
      final schoolId = currentUser.group1;

      // Validate required fields
      final missingFields = <String>[];
      if (teacherId.isEmpty) missingFields.add('teacher_id');
      if (studentId.isEmpty) missingFields.add('student_id');
      if (className.isEmpty) missingFields.add('class');
      if (schoolId.isEmpty) missingFields.add('school_id');
      if (selectedBooks.isEmpty) missingFields.add('books');

      if (missingFields.isNotEmpty) {
        return {
          'success': false,
          'message': 'आवश्यक फील्ड गुम हैं: ${missingFields.join(', ')}',
        };
      }

      // ✅ Skip availability check in offline mode — cached counts may be stale
      if (_connectivityService.isOnline.value) {
        for (final book in selectedBooks) {
          final available = await _checkBookAvailabilityFromDatabase(
            book.bookId,
          );
          if (available <= 0) {
            return {
              'success': false,
              'message':
                  '"${book.title}" उपलब्ध नहीं है। उपलब्ध प्रतियां: $available',
            };
          }
          print(
            '📚 Book "${book.title}" availability check passed: $available copies',
          );
        }
      } else {
        print('📱 Offline: skipping strict availability check');
      }

      // ✅ Skip online duplicate check in offline mode
      if (_connectivityService.isOnline.value) {
        print('🔍 Comprehensive duplicate check before API call...');
        try {
          final checkedOutBooks = await apiService.getCheckedOutBooks(
            teacherId: teacherId,
          );

          for (final book in selectedBooks) {
            for (final checkedOutBook in checkedOutBooks) {
              final existingBookCode =
                  checkedOutBook['F4_LCODE']?.toString() ?? '';
              final existingBookId = checkedOutBook['bookId']?.toString() ?? '';
              final existingStudentId =
                  checkedOutBook['F4_PARTY1']?.toString() ?? '';
              final existingStudentName =
                  checkedOutBook['F4_PARTY1N']?.toString() ?? '';

              final bookMatch =
                  (existingBookCode == book.bookCode ||
                  existingBookCode == book.bookId ||
                  existingBookId == book.bookCode ||
                  existingBookId == book.bookId);

              final studentMatch =
                  existingStudentId == studentId ||
                  existingStudentName.toLowerCase().trim() ==
                      student.name.toLowerCase().trim();

              if (bookMatch && studentMatch) {
                print(
                  '🚫 Duplicate found: "${book.title}" already issued to "${student.name}"',
                );
                Get.snackbar(
                  'डुप्लिकेट चेकआउट',
                  '"${book.title}" यह छात्र को पहले से जारी है।',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                  duration: const Duration(seconds: 4),
                );
                return {
                  'success': false,
                  'message':
                      'Student already has book "${book.title}" - detected before API call',
                };
              }
            }
          }
        } catch (e) {
          print('⚠️ Duplicate check failed: $e');
        }
      } else {
        print('📱 Offline: skipping online duplicate check');
      }

      // ✅ Offline duplicate check for EACH book (always runs)
      try {
        final offlineDb = Get.find<OfflineDatabaseService>();
        final db = await offlineDb.database;

        for (final book in selectedBooks) {
          final recentTransactions = await db.query(
            'offline_transactions_enhanced',
            where:
                'teacher_id = ? AND transaction_type = ? AND sync_status = ? AND book_id = ? AND student_id = ?',
            whereArgs: [teacherId, 'checkout', 0, book.bookId, studentId],
          );

          if (recentTransactions.isNotEmpty) {
            print(
              '🚫 Offline duplicate: "${book.title}" already pending for "${student.name}"',
            );
            Get.snackbar(
              'ऑफलाइन डुप्लिकेट',
              '"${book.title}" यह चेकआउट पहले से ऑफलाइन सेव है।',
              backgroundColor: Colors.orange,
              colorText: Colors.white,
              duration: const Duration(seconds: 3),
            );
            return {
              'success': false,
              'message':
                  'Duplicate offline transaction found for "${book.title}"',
            };
          }
        }
      } catch (e) {
        print('⚠️ Offline duplicate check failed: $e - proceeding');
      }

      // Build booksArray from selectedBooks list
      final List<Map<String, dynamic>> booksArray = selectedBooks.map((book) {
        return {
          'bookId': book.bookId,
          'bookCode': book.bookCode,
          'bookName': book.title,
          'author': book.author,
          'availableCopies': book.availableCopies,
        };
      }).toList();

      print('\n📚 ========== CHECKOUT: PREPARING SUBMISSION ==========');
      print('   teacherId: $teacherId');
      print('   studentId: $studentId (${student.name})');
      print('   className: $className');
      print('   programId: $programId / schoolId: $schoolId');
      print('   Books count: ${booksArray.length}');
      for (int i = 0; i < booksArray.length; i++) {
        print('   Book $i: ${booksArray[i]}');
      }
      print('======================================================\n');

      Map<String, dynamic> result;

      if (!_connectivityService.isOnline.value) {
        // ✅ Offline: save each book as individual offline transaction
        print(
          '📱 Offline mode: Saving ${selectedBooks.length} books offline...',
        );
        final offlineDb = Get.find<OfflineDatabaseService>();
        int savedCount = 0;

        for (final book in selectedBooks) {
          try {
            final resolvedBookId = book.bookId.isNotEmpty
                ? book.bookId
                : book.bookCode;

            await offlineDb.saveOfflineCheckout(
              teacherId: teacherId,
              bookId: resolvedBookId,
              bookCode: book.bookCode,
              studentId: studentId,
              className: className,
              studentName: student.name,
              bookName: book.title,
            );
            savedCount++;
            print('✅ Saved offline checkout: ${book.title}');
          } catch (e) {
            print('❌ Failed to save offline checkout for ${book.title}: $e');
          }
        }

        if (savedCount == selectedBooks.length) {
          result = {
            'success': true,
            'message':
                '$savedCount किताबें ऑफलाइन सेव हो गईं। ऑनलाइन होने पर सिंक होंगी।',
            'offline': true,
          };
        } else {
          result = {
            'success': savedCount > 0,
            'message':
                '$savedCount/${selectedBooks.length} किताबें ऑफलाइन सेव हो सकीं।',
            'offline': true,
          };
        }
      } else {
        // ✅ Online: API call
        result = await apiService.checkout(
          teacherId: teacherId,
          books: booksArray,
          studentId: studentId,
          className: className,
          programId: programId,
          schoolId: schoolId,
          studentName: student.name,
        );
      }

      if (result['success'] == true) {
        print('\n✅ CHECKOUT SUCCESS');
        print('   Full Result: ${jsonEncode(result)}');

        for (final book in selectedBooks) {
          checkoutHistory.add({
            'student': student,
            'book': book,
            'class': selectedClass.value,
            'date': DateTime.now(),
            'dueDate': DateTime.now().add(const Duration(days: 14)),
          });
          print('✅ Added to history: "${book.title}" for "${student.name}"');
        }

        // Refresh controllers only when online
        if (_connectivityService.isOnline.value) {
          try {
            await Future.delayed(const Duration(milliseconds: 800));
            final bookController = Get.find<BookController>();
            await bookController.loadBooks();
            print('✅ BookController refreshed');
          } catch (e) {
            print('⚠️ Failed to refresh BookController: $e');
          }

          try {
            final homeController = Get.find<HomeController>();
            await homeController.refreshCounts();
          } catch (e) {
            print('⚠️ Failed to refresh HomeController: $e');
          }

          try {
            await Future.delayed(const Duration(milliseconds: 500));
            if (Get.isRegistered<CheckinController>()) {
              final checkinController = Get.find<CheckinController>();
              await checkinController.refreshCheckedOutBooks();
              print('✅ CheckinController refreshed');
            }
          } catch (e) {
            print('❌ Error refreshing CheckinController: $e');
          }
        }

        clearSelection();
        selectedClass.value = '';
      } else {
        String errorMessage = result['message'] ?? 'चेकआउट असफल';

        if (errorMessage.contains('Student Already Issued selected Book!') ||
            errorMessage.contains('Student Already Issued')) {
          errorMessage =
              'यह छात्र को यह किताब पहले से जारी है। कृपया चेक इन सूची में देखें या दूसरी किताब चुनें।';

          try {
            if (Get.isRegistered<CheckinController>()) {
              final checkinController = Get.find<CheckinController>();
              await checkinController.refreshCheckedOutBooks();
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
          duration: const Duration(seconds: 4),
        );
      }

      return result;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    } finally {
      isLoading.value = false;
    }
  }

  Future<int> _checkBookAvailabilityFromDatabase(String bookId) async {
    try {
      final offlineDb = Get.find<OfflineDatabaseService>();
      final db = await offlineDb.database;

      final books = await db.query(
        'books',
        where: 'code = ? OR bookId = ?',
        whereArgs: [bookId, bookId],
        limit: 1,
      );

      if (books.isNotEmpty) {
        final book = books.first;
        final available = int.tryParse(book['txt3']?.toString() ?? '0') ?? 0;
        print('📚 DB availability for $bookId: $available copies');
        return available;
      } else {
        print('⚠️ Book not found in database: $bookId');

        if (_connectivityService.isOnline.value) {
          try {
            final currentUser = _authService.currentUser.value;
            if (currentUser != null) {
              final allBooks = await apiService.getBooks(
                userId: currentUser.code,
              );
              final targetBook = allBooks
                  .where((b) => b.bookId == bookId || b.bookCode == bookId)
                  .firstOrNull;

              if (targetBook != null) {
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
                return targetBook.availableCopy;
              }
            }
          } catch (e) {
            print('❌ Error fetching book from API: $e');
          }
        }
        return 0;
      }
    } catch (e) {
      print('❌ Error checking book availability: $e');
      return 0;
    }
  }

  Future<Map<String, dynamic>> _verifyDataAvailability() async {
    try {
      if (classes.isEmpty) {
        return {
          'available': false,
          'message':
              'कक्षाओं का डेटा उपलब्ध नहीं है। कृपया ऑनलाइन होकर डेटा डाउनलोड करें।',
        };
      }

      try {
        final studentController = Get.find<StudentController>();
        if (studentController.students.isEmpty) {
          return {
            'available': false,
            'message':
                'छात्रों का डेटा उपलब्ध नहीं है। कृपया ऑनलाइन होकर डेटा डाउनलोड करें।',
          };
        }
      } catch (e) {
        print('⚠️ Could not check students: $e');
      }

      try {
        final bookController = Get.find<BookController>();
        if (bookController.books.isEmpty) {
          final offlineDb = Get.find<OfflineDatabaseService>();
          final offlineBooks = await offlineDb.getBooksOffline();
          if (offlineBooks.isEmpty) {
            return {
              'available': false,
              'message':
                  'किताबों का डेटा उपलब्ध नहीं है। कृपया ऑनलाइन होकर "डेटा डाउनलोड करें" दबाएं।',
            };
          }
        }
      } catch (e) {
        print('⚠️ Could not check books: $e');
      }

      return {'available': true};
    } catch (e) {
      return {'available': false, 'message': 'डेटा सत्यापन में त्रुटि: $e'};
    }
  }
}
