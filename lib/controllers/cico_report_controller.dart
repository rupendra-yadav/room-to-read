import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:room_to_read/services/hybrid_api_service.dart';
import 'package:room_to_read/services/auth_service.dart';

class CicoReportController extends GetxController {
  late HybridApiService apiService;
  final AuthService _authService = Get.find<AuthService>();

  var selectedClass = Rxn<String>();
  var dateFromFilter = ''.obs;
  var dateToFilter = ''.obs;
  var searchQuery = ''.obs;
  var bookIssues = <Map<String, dynamic>>[].obs;
  var filteredBookIssues = <Map<String, dynamic>>[].obs;
  var classes = <String>[].obs;
  var isLoading = false.obs;

  final TextEditingController searchController = TextEditingController();

  // AFTER
  @override
  void onInit() {
    super.onInit();
    apiService = Get.find<HybridApiService>();
    fetchClassesOnly(); // ← only fetch classes
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  Future<void> fetchClassesOnly() async {
    try {
      isLoading.value = true;
      final classList = await apiService.getClasses();
      classes.value = classList;
    } catch (e) {
      Get.snackbar('Error', 'Failed to load classes: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchClassesAndBookIssues() async {
    try {
      print('🔄 CicoReportController: Starting fetchClassesAndBookIssues');
      isLoading.value = true;

      // Fetch classes
      print('📚 Fetching classes...');
      final classList = await apiService.getClasses();
      classes.value = classList;
      print('✅ Classes fetched: ${classList.length}');

      // Fetch CICO report initially
      print('📊 Fetching initial CICO report...');
      await fetchBookIssues();
      print('✅ Initial CICO report fetch completed');
    } catch (e) {
      print('❌ Error in fetchClassesAndBookIssues: $e');
      Get.snackbar('Error', 'Failed to load data: $e');
    } finally {
      isLoading.value = false;
      print('🏁 CicoReportController: fetchClassesAndBookIssues completed');
    }
  }

  Future<void> fetchBookIssues({String? className}) async {
    try {
      isLoading.value = true;

      // Force UI update for loading state
      isLoading.refresh();

      final currentUser = _authService.currentUser.value;
      if (currentUser == null) {
        print('❌ No user logged in');
        Get.snackbar('Error', 'Please login first');
        return;
      }

      log('🔄 Fetching CICO report with filters:');

      print('🔄 Fetching CICO report with filters:');
      log('   Teacher ID (M1_CODE): ${currentUser.code}');
      print('   Class: ${className ?? selectedClass.value}');
      print('   From Date (from_date): ${dateFromFilter.value}');
      print('   To Date (to_date): ${dateToFilter.value}');
      print(
        '   API will receive: from_date=${dateFromFilter.value.isNotEmpty ? dateFromFilter.value : 'null'}, to_date=${dateToFilter.value.isNotEmpty ? dateToFilter.value : 'null'}',
      );

      // Use the new CICO report API with date filtering
      final reportList = await apiService.getCicoReport(
        teacherId: currentUser.code, // Use M1_CODE instead of group1
        className: className ?? selectedClass.value,
        fromDate: dateFromFilter.value.isNotEmpty ? dateFromFilter.value : null,
        toDate: dateToFilter.value.isNotEmpty ? dateToFilter.value : null,
      );

      print('✅ Fetched ${reportList.length} CICO report records');

      // If CICO report is empty, try fallback to checked out books
      if (reportList.isEmpty) {
        print('⚠️ CICO report empty, trying fallback to checked out books...');
        final fallbackList = await apiService.getCheckedOutBooks(
          teacherId: currentUser.code, // Use M1_CODE instead of group1
          className: className ?? selectedClass.value,
          fromDate: dateFromFilter.value.isNotEmpty
              ? dateFromFilter.value
              : null,
          toDate: dateToFilter.value.isNotEmpty ? dateToFilter.value : null,
        );
        print('📋 Fallback returned ${fallbackList.length} records');

        if (fallbackList.isNotEmpty) {
          // Use fallback data
          _processReportData(fallbackList, 'fallback checked out books');
          return;
        } else {
          print('❌ Both CICO report and fallback returned empty results');
          Get.snackbar(
            'सूचना',
            'कोई डेटा नहीं मिला। कृपया फिल्टर बदलकर देखें।',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );
          bookIssues.clear();
          filteredBookIssues.clear();
          searchQuery.value = '';

          // Force UI updates
          bookIssues.refresh();
          filteredBookIssues.refresh();
          searchQuery.refresh();
          return;
        }
      }

      // Process the CICO report data
      _processReportData(reportList, 'CICO report API');
    } catch (e) {
      print('❌ Error in fetchBookIssues: $e');
      print('📍 Stack trace: ${StackTrace.current}');
      Get.snackbar('Error', 'Failed to load CICO report: $e');
    } finally {
      isLoading.value = false;
      // Force UI update for loading state
      isLoading.refresh();
    }
  }

  // Helper method to process report data (deduplication and sorting)
  void _processReportData(List<dynamic> reportList, String source) {
    print('📊 Processing ${reportList.length} records from $source');
    print('📋 Sample raw data: ${reportList.take(2).toList()}');

    // Remove duplicates based on F4_BT (transaction code) or create composite key
    final uniqueRecords = <String, Map<String, dynamic>>{};
    for (var record in reportList) {
      final recordMap = Map<String, dynamic>.from(record as Map);
      final transactionCode = recordMap['F4_BT']?.toString() ?? '';

      // Create a unique key - if transaction code is not unique, use composite key
      String uniqueKey = transactionCode;
      if (transactionCode.isNotEmpty) {
        // Check if this transaction code already exists
        if (uniqueRecords.containsKey(transactionCode)) {
          // Create composite key using transaction code + book code + student name + date
          final bookCode = recordMap['F4_LCODE']?.toString() ?? '';
          final studentName = recordMap['F4_PARTY1N']?.toString() ?? '';
          final date =
              recordMap['F4_DATE']?.toString() ??
              recordMap['F4_DATE1']?.toString() ??
              '';
          uniqueKey = '${transactionCode}_${bookCode}_${studentName}_${date}';

          // Also update the record map to include this composite key for later reference
          recordMap['_composite_key'] = uniqueKey;

          print(
            '⚠️ Duplicate transaction code detected: $transactionCode, using composite key: $uniqueKey',
          );
        }
        uniqueRecords[uniqueKey] = recordMap;
      } else {
        // If no transaction code, create a unique key based on available data
        final bookCode = recordMap['F4_LCODE']?.toString() ?? '';
        final studentName = recordMap['F4_PARTY1N']?.toString() ?? '';
        final date =
            recordMap['F4_DATE']?.toString() ??
            recordMap['F4_DATE1']?.toString() ??
            '';
        uniqueKey = 'no_tx_${bookCode}_${studentName}_${date}';
        recordMap['_composite_key'] = uniqueKey;
        uniqueRecords[uniqueKey] = recordMap;

        print('⚠️ No transaction code found, using composite key: $uniqueKey');
      }
    }

    bookIssues.value = uniqueRecords.values.toList();

    // Sort by date (F4_DATE field) in descending order (newest first)
    bookIssues.sort((a, b) {
      final dateA = a['F4_DATE']?.toString() ?? a['F4_DATE1']?.toString() ?? '';
      final dateB = b['F4_DATE']?.toString() ?? b['F4_DATE1']?.toString() ?? '';
      return dateB.compareTo(dateA); // Descending order
    });

    print(
      '📚 Report after deduplication and sorting: ${bookIssues.length} items',
    );
    print('📊 Sample processed data: ${bookIssues.take(2).toList()}');

    // Clear filtered records when fetching new data
    filteredBookIssues.clear();
    searchQuery.value = '';

    // Force UI updates
    bookIssues.refresh();
    filteredBookIssues.refresh();
    searchQuery.refresh();

    print('🎉 Report processing completed successfully from $source');
  }

  void selectClass(String className) {
    selectedClass.value = className;
    // Fetch books for the selected class
    fetchBookIssues(className: className);
  }

  void searchRecords(String query) {
    searchQuery.value = query;

    if (query.isEmpty) {
      filteredBookIssues.clear();
    } else {
      final lowerQuery = query.toLowerCase();
      filteredBookIssues.value = bookIssues
          .where(
            (record) =>
                // Search by student name
                ((record['studentName'] ??
                            record['F4_PARTY1N'] ??
                            record['student_name'] ??
                            '')
                        as String)
                    .toLowerCase()
                    .contains(lowerQuery) ||
                // Search by book name
                ((record['bookName'] ??
                            record['F4_PARTYN'] ??
                            record['book_name'] ??
                            '')
                        as String)
                    .toLowerCase()
                    .contains(lowerQuery) ||
                // Search by student ID/code
                ((record['studentId'] ??
                            record['F4_PARTY1'] ??
                            record['student_id'] ??
                            '')
                        as String)
                    .toLowerCase()
                    .contains(lowerQuery) ||
                // Search by book code
                ((record['bookCode'] ??
                            record['F4_LCODE'] ??
                            record['book_code'] ??
                            '')
                        as String)
                    .toLowerCase()
                    .contains(lowerQuery) ||
                // Search by class
                ((record['className'] ??
                            record['F4_TXT1'] ??
                            record['class'] ??
                            '')
                        as String)
                    .toLowerCase()
                    .contains(lowerQuery) ||
                // Search by publisher (F4_PARTY_PUB)
                ((record['F4_PARTY_PUB'] ?? record['publisher'] ?? '')
                        as String)
                    .toLowerCase()
                    .contains(lowerQuery) ||
                // Search by transaction code (F4_BT)
                ((record['F4_BT'] ?? record['transaction_code'] ?? '')
                        as String)
                    .toLowerCase()
                    .contains(lowerQuery),
          )
          .toList();

      // Sort filtered results by date as well
      filteredBookIssues.sort((a, b) {
        final dateA =
            a['F4_DATE']?.toString() ?? a['F4_DATE1']?.toString() ?? '';
        final dateB =
            b['F4_DATE']?.toString() ?? b['F4_DATE1']?.toString() ?? '';
        return dateB.compareTo(dateA); // Descending order
      });
    }

    // Force UI updates
    searchQuery.refresh();
    filteredBookIssues.refresh();
  }

  // Force refresh method for debugging
  Future<void> forceRefresh() async {
    print('🔄 Force refreshing CICO report...');
    print('🔄 Current state before refresh:');
    print('   bookIssues: ${bookIssues.length}');
    print('   filteredBookIssues: ${filteredBookIssues.length}');
    print('   isLoading: ${isLoading.value}');

    bookIssues.clear();
    filteredBookIssues.clear();
    searchQuery.value = '';

    print('🔄 State after clearing:');
    print('   bookIssues: ${bookIssues.length}');
    print('   filteredBookIssues: ${filteredBookIssues.length}');

    await fetchBookIssues();

    print('🔄 State after fetchBookIssues:');
    print('   bookIssues: ${bookIssues.length}');
    print('   filteredBookIssues: ${filteredBookIssues.length}');
    print('   isLoading: ${isLoading.value}');
  }

  // Debug method to check controller state
  void debugControllerState() {
    print('🐛 ===== CONTROLLER DEBUG STATE =====');
    print('🐛 Controller instance: ${this.hashCode}');
    print('🐛 bookIssues length: ${bookIssues.length}');
    print('🐛 filteredBookIssues length: ${filteredBookIssues.length}');
    print('🐛 classes length: ${classes.length}');
    print('🐛 selectedClass: ${selectedClass.value}');
    print('🐛 dateFromFilter: "${dateFromFilter.value}"');
    print('🐛 dateToFilter: "${dateToFilter.value}"');
    print('🐛 searchQuery: "${searchQuery.value}"');
    print('🐛 isLoading: ${isLoading.value}');
    print('🐛 Sample bookIssues: ${bookIssues.take(2).toList()}');
    print('🐛 ===== END DEBUG STATE =====');

    // Force UI update
    bookIssues.refresh();
    filteredBookIssues.refresh();

    Get.snackbar(
      'Debug Info',
      'Records: ${bookIssues.length}, Filtered: ${filteredBookIssues.length}, Loading: ${isLoading.value}',
      backgroundColor: Colors.blue,
      colorText: Colors.white,
      duration: Duration(seconds: 3),
    );

    // Test API call
    testCicoReportApi();
  }

  // Date filter methods
  void setDateFilter(String from, String to) {
    print('🗓️ Setting date filter - From: $from, To: $to');
    dateFromFilter.value = from;
    dateToFilter.value = to;

    // Force observable updates
    dateFromFilter.refresh();
    dateToFilter.refresh();

    // Clear existing data before fetching new
    bookIssues.clear();
    filteredBookIssues.clear();
    searchQuery.value = '';

    // Fetch with new date filter
    print('🔄 Fetching book issues with date filter');
    fetchBookIssues();
  }

  void clearDateFilter() {
    print('🧹 Clearing date filter');
    dateFromFilter.value = '';
    dateToFilter.value = '';

    // Force observable updates
    dateFromFilter.refresh();
    dateToFilter.refresh();

    // Clear existing data before fetching new
    bookIssues.clear();
    filteredBookIssues.clear();
    searchQuery.value = '';

    fetchBookIssues();
  }

  // Test method to verify API connectivity
  Future<void> testCicoReportApi() async {
    try {
      print('🧪 Testing CICO Report API directly...');

      final currentUser = _authService.currentUser.value;
      if (currentUser == null) {
        print('❌ No user logged in for API test');
        return;
      }

      print('👤 Testing with teacher ID (M1_CODE): ${currentUser.code}');
      print(
        '📅 Testing with date filter: ${dateFromFilter.value} to ${dateToFilter.value}',
      );

      // Test the API directly with current filters
      final testResult = await apiService.getCicoReport(
        teacherId: currentUser.code, // Use M1_CODE instead of group1
        className: selectedClass.value,
        fromDate: dateFromFilter.value.isNotEmpty ? dateFromFilter.value : null,
        toDate: dateToFilter.value.isNotEmpty ? dateToFilter.value : null,
      );

      print('🧪 API Test Result: ${testResult.length} records');
      print('📋 Sample data: ${testResult.take(2).toList()}');

      Get.snackbar(
        'API Test',
        'CICO Report API returned ${testResult.length} records',
        backgroundColor: testResult.isNotEmpty ? Colors.green : Colors.orange,
        colorText: Colors.white,
      );
    } catch (e) {
      print('❌ API Test Error: $e');
      Get.snackbar(
        'API Test Error',
        'Failed to test CICO Report API: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Comprehensive test method for debugging
  Future<void> runComprehensiveTest() async {
    print('🔬 ===== COMPREHENSIVE CICO REPORT TEST =====');

    // Test 1: Check controller state
    debugControllerState();

    // Test 2: Test API directly
    await testCicoReportApi();

    // Test 3: Force refresh
    await forceRefresh();

    // Test 4: Test date filtering
    print('🧪 Testing date filtering...');
    final today = DateTime.now();
    final yesterday = today.subtract(Duration(days: 1));
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final yesterdayStr =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    setDateFilter(yesterdayStr, todayStr);

    print('🏁 ===== COMPREHENSIVE TEST COMPLETED =====');
  }
}
