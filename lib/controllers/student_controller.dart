import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:room_to_read/models/student_model.dart';
import 'package:room_to_read/services/api_service.dart';
import 'package:room_to_read/services/connectivity_service.dart';
import 'package:room_to_read/services/hybrid_api_service.dart';
import 'package:room_to_read/services/auth_service.dart';
import 'package:room_to_read/services/offline_database_service.dart';
import 'package:room_to_read/models/grade_model.dart';

class StudentController extends GetxController {
  late HybridApiService apiService;
  final AuthService _authService = Get.find<AuthService>();

  var students = <Student>[].obs;
  var filteredStudents = <Student>[].obs;
  var searchQuery = ''.obs;
  var selectedStudent = Rxn<Student>();
  var filterType = 'सभी'.obs;
  var grades = <Grade>[].obs;
  var isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    apiService = Get.find<HybridApiService>();
    loadStudents();
  }

  Future<void> loadStudents() async {
    // Get current user's M1_CODE (teacher ID) - defined at method scope for catch block access
    final currentUser = _authService.currentUser.value;
    final teacherId = currentUser?.code; // Use M1_CODE as teacher ID

    try {
      isLoading.value = true;

      print('Loading students for teacher ID: $teacherId');

      // Fetch classes
      final gradeList = await apiService.getGrades();
      grades.value = gradeList;

      // Fetch all students using hybrid service
      final allStudents = await apiService.getStudents(group1: teacherId);
      print('Student list received: ${allStudents.length} items');

      // Filter students by M1_GROUP2 matching teacher ID
      students.value = allStudents.where((student) {
        final matches = student.teacherId == teacherId;
        print(
          'Student ${student.name}: teacherId=${student.teacherId}, matches=$matches',
        );
        return matches;
      }).toList();

      print('Students after filtering by teacher: ${students.length} items');

      // Show all students initially (no pagination limit)
      if (students.isNotEmpty) {
        filteredStudents.value = students;
        print('Showing all ${filteredStudents.length} students');
      } else {
        print(
          '⚠️ No students found from hybrid API, trying offline database...',
        );

        // Try to load from offline database directly as fallback
        final offlineDb = Get.find<OfflineDatabaseService>();
        final offlineStudents = await offlineDb.getStudentsOffline(
          teacherId: teacherId,
        );
        print(
          '📱 Found ${offlineStudents.length} students in offline database',
        );

        if (offlineStudents.isNotEmpty) {
          // Convert offline data to Student objects
          final offlineStudentList = offlineStudents.map((data) {
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

          students.value = offlineStudentList;
          filteredStudents.value = offlineStudentList;
          print(
            '✅ Loaded ${offlineStudentList.length} students from offline database',
          );
        } else {
          filteredStudents.value = [];
          print('No students found in offline database');
        }
      }
    } catch (e) {
      print('Error in loadStudents: $e');

      // Final fallback to offline database
      try {
        print('🆘 Final fallback to offline database...');
        final offlineDb = Get.find<OfflineDatabaseService>();
        final offlineStudents = await offlineDb.getStudentsOffline(
          teacherId: teacherId,
        );
        print(
          '📱 Fallback found ${offlineStudents.length} students in offline database',
        );

        if (offlineStudents.isNotEmpty) {
          final offlineStudentList = offlineStudents.map((data) {
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

          students.value = offlineStudentList;
          filteredStudents.value = offlineStudentList;
          print(
            '✅ Fallback loaded ${offlineStudentList.length} students from offline database',
          );
        }
      } catch (fallbackError) {
        print('❌ Even fallback failed: $fallbackError');
      }

      Get.snackbar('Error', 'Failed to load students: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void searchStudents(String query) {
    searchQuery.value = query;
    applyFilters();
  }

  // Remove student from filtered list (used after selection in checkout)
  void removeStudentFromFilteredList(Student student) {
    try {
      filteredStudents.removeWhere(
        (s) => s.id == student.id || s.code == student.code,
      );
      print('✅ Removed student ${student.name} from filtered list');
      print(
        '📊 Remaining students in filtered list: ${filteredStudents.length}',
      );
    } catch (e) {
      print('❌ Error removing student from filtered list: $e');
    }
  }

  // Add student back to filtered list (used when selection is cleared)
  void addStudentBackToFilteredList(Student student) {
    try {
      // Check if student is not already in the list
      final exists = filteredStudents.any(
        (s) => s.id == student.id || s.code == student.code,
      );
      if (!exists) {
        // Add student back and re-apply current filters
        applyFilters();
        print('✅ Added student ${student.name} back to filtered list');
      }
    } catch (e) {
      print('❌ Error adding student back to filtered list: $e');
    }
  }

  void applyFilters() {
    print('🔍 applyFilters called:');
    print('   filterType: "${filterType.value}"');
    print('   searchQuery: "${searchQuery.value}"');
    print('   total students: ${students.length}');

    var result = students.toList();

    if (filterType.value != 'सभी' && filterType.value.isNotEmpty) {
      result = result.where((student) {
        final grades = student.className
            .split(',')
            .map((g) => g.trim())
            .toList();
        return grades.contains(filterType.value);
      }).toList();
      print('   after grade filter: ${result.length}');
    }

    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase().trim();
      print('   🔎 All 57 grade-filtered names:');
      for (final s in result) {
        print(
          '     "${s.name}" | trimmed: "${s.name.trim()}" | lower: "${s.name.toLowerCase().trim()}" | contains aa: ${s.name.toLowerCase().trim().contains("aa")}',
        );
      }
      result = result
          .where(
            (student) =>
                student.name.toLowerCase().trim().contains(query) ||
                student.id.trim().contains(query) ||
                student.code.trim().contains(query),
          )
          .toList();
      print('   after search filter: ${result.length}');
    }

    filteredStudents.value = result;
  }

  void setClassFilter(String className) {
    filterType.value = className;
    // Clear search query when class changes
    searchQuery.value = '';
    // Apply filters to show students from selected class
    applyFilters();
  }

  void setFilterType(String type) {
    filterType.value = type;
    applyFilters();
  }

  void selectStudent(Student student) {
    selectedStudent.value = student;
  }

  // Method to manually download and cache student data
  Future<void> downloadAndCacheData() async {
    try {
      isLoading.value = true;
      print('🔄 Manually downloading and caching student data...');

      final currentUser = _authService.currentUser.value;
      final teacherId = currentUser?.code;

      if (currentUser == null) {
        Get.snackbar('Error', 'कृपया पहले लॉगिन करें');
        return;
      }

      // Force download from API and save to offline storage
      final connectivityService = Get.find<ConnectivityService>();
      if (!connectivityService.isOnline.value) {
        Get.snackbar('ऑफलाइन', 'डेटा डाउनलोड के लिए इंटरनेट कनेक्शन चाहिए');
        return;
      }

      print('📡 Downloading fresh student data from API...');
      // Go through HybridApiService.getStudents() rather than the raw API
      // call so the M1_TXT2/M1_TXT1 fields get mapped to readingLevel/
      // previousLevel (and merged with any pending local edits) before
      // being cached — saving the raw API rows directly used to silently
      // zero out every student's reading level.
      final hybridApiService = Get.find<HybridApiService>();
      final freshStudents = await hybridApiService.getStudents(
        group1: teacherId,
      );

      if (freshStudents.isNotEmpty) {
        print(
          '✅ Successfully saved ${freshStudents.length} students to offline storage',
        );

        // Reload students from offline storage to verify
        await loadStudents();

        Get.snackbar(
          'सफल',
          '${freshStudents.length} छात्र डाउनलोड और सेव हो गए',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar('जानकारी', 'कोई छात्र नहीं मिला');
      }
    } catch (e) {
      print('❌ Error in downloadAndCacheData: $e');
      Get.snackbar('त्रुटि', 'डेटा डाउनलोड में समस्या: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateReadingLevel(
    String studentCode,
    int oldLevel,
    int newLevel,
  ) async {
    try {
      final connectivityService = Get.find<ConnectivityService>();
      final offlineDb = Get.find<OfflineDatabaseService>();

      print(
        '🔧 updateReadingLevel CALLED: studentCode=$studentCode, oldLevel=$oldLevel, newLevel=$newLevel, isOnline=${connectivityService.isOnline.value}',
      );

      // Update UI immediately regardless of online/offline
      final index = students.indexWhere((s) => s.code == studentCode);
      print(
        '🔧 updateReadingLevel: found student at index=$index (students.length=${students.length})',
      );
      if (index != -1) {
        students[index] = students[index].copyWith(readingLevel: newLevel);
        applyFilters();
      }

      final localUpdateCount = await offlineDb.database.then(
        (db) => db.update(
          'students',
          {
            'readingLevel': newLevel,
            'previousLevel': oldLevel,
            'currentLevel': newLevel,
          },
          where: 'code = ?',
          whereArgs: [studentCode],
        ),
      );
      print(
        '🔧 updateReadingLevel: local SQLite rows updated=$localUpdateCount for code=$studentCode',
      );

      if (connectivityService.isOnline.value) {
        print('🔧 updateReadingLevel: taking ONLINE path, calling API...');
        await _sendReadingLevelToApi(studentCode, newLevel);
        print('✅ Reading level updated online for: $studentCode');
      } else {
        print(
          '🔧 updateReadingLevel: taking OFFLINE path, queuing for later sync...',
        );
        await offlineDb.saveOfflineReadingLevelUpdate(
          studentCode: studentCode,
          oldLevel: oldLevel,
          newLevel: newLevel,
        );
        Get.snackbar(
          'ऑफलाइन सेव',
          'रीडिंग लेवल सेव हो गया। ऑनलाइन होने पर स्वचालित सिंक होगा।',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      print('❌ Error updating reading level: $e');
      Get.snackbar('त्रुटि', 'लेवल अपडेट में समस्या: $e');
    }
  }

  Future<void> _sendReadingLevelToApi(String studentCode, int newLevel) async {
    final result = await Get.find<ApiService>().updateReadingLevel(
      studentCode,
      newLevel,
    );
    print('🔧 _sendReadingLevelToApi: result=$result');
    if (result['success'] != true) throw Exception(result['message']);
  }

  void updateStudentLevelLocally(String code, int newLevel, int oldLevel) {
    final i = students.indexWhere((s) => s.code == code);
    if (i != -1) {
      students[i] = students[i].copyWith(
        readingLevel: newLevel,
        previousLevel: oldLevel,
      );
      applyFilters();
    }
  }

  Future<void> syncPendingReadingLevelUpdates() async {
    try {
      final offlineDb = Get.find<OfflineDatabaseService>();
      final pending = await offlineDb.getPendingReadingLevelUpdates();

      if (pending.isEmpty) return;

      print('🔄 Syncing ${pending.length} pending reading level updates...');
      int successCount = 0;

      for (final update in pending) {
        try {
          await _sendReadingLevelToApi(
            update['student_code'],
            update['new_level'],
          );
          await offlineDb.markReadingLevelUpdateSynced(update['id']);
          successCount++;
          print(
            '✅ Synced: ${update['student_code']} → Level ${update['new_level']}',
          );
        } catch (e) {
          print('❌ Failed to sync ${update['student_code']}: $e');
          // Keeps sync_status = 0, retries next time online
        }
      }

      if (successCount > 0) {
        Get.snackbar(
          'सिंक सफल',
          '$successCount रीडिंग लेवल अपडेट सिंक हो गए',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print('❌ Error syncing reading level updates: $e');
    }
  }
}
