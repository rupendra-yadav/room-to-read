import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:room_to_read/services/hybrid_api_service.dart';
import 'package:room_to_read/services/auth_service.dart';

class AnalysisController extends GetxController {
  late HybridApiService apiService;
  final AuthService _authService = Get.find<AuthService>();

  var selectedClass = 'सभी कक्षाएं'.obs;
  var selectedAggregation = 'मासिक'.obs;
  var dateFromFilter = ''.obs;
  var dateToFilter = ''.obs;
  var classes = <String>[].obs;
  var isLoading = false.obs;

  // Analytics data
  var chartLabels = <String>[].obs;
  var chartValues = <int>[].obs;
  var reportList = <Map<String, dynamic>>[].obs;

  // पाठकों की कुल संख्या — distinct readers in the selected filters, each
  // counted once no matter how many books they issued/returned.
  var totalReaders = 0.obs;
  // कुल रिकॉर्ड (Total CICO) — completed returns only (good or damaged);
  // excludes books still checked out and books marked lost.
  var totalCico = 0.obs;
  // खोई हुई पुस्तकें — books marked lost, within the selected filters.
  var totalLostBooks = 0.obs;

  var isOfflineData = false.obs;

  final aggregations = ['दैनिक', 'साप्ताहिक', 'मासिक', 'वार्षिक'];

  @override
  void onInit() {
    super.onInit();
    apiService = Get.find<HybridApiService>();

    // Check if filter parameters were passed from analytics filter page
    final filterParams = Get.arguments as Map<String, dynamic>?;
    if (filterParams != null) {
      _applyFilterParams(filterParams);
    }

    fetchClasses();
    fetchAnalytics();
  }

  void _applyFilterParams(Map<String, dynamic> params) {
    print('🔧 Applying filter parameters: $params');

    if (params['className'] != null &&
        params['className'].toString().isNotEmpty) {
      selectedClass.value = params['className'];
      print('✅ Applied className: "${selectedClass.value}"');
    } else {
      selectedClass.value = 'सभी कक्षाएं';
      print('✅ No className provided, using default: "${selectedClass.value}"');
    }

    if (params['fromDate'] != null &&
        params['fromDate'].toString().isNotEmpty) {
      dateFromFilter.value = params['fromDate'];
      print('✅ Applied fromDate: "${dateFromFilter.value}"');
    }

    if (params['toDate'] != null && params['toDate'].toString().isNotEmpty) {
      dateToFilter.value = params['toDate'];
      print('✅ Applied toDate: "${dateToFilter.value}"');
    }

    if (params['aggregation'] != null) {
      // Convert English aggregation to Hindi
      final aggregation = params['aggregation'];
      switch (aggregation) {
        case 'daily':
          selectedAggregation.value = 'दैनिक';
          break;
        case 'weekly':
          selectedAggregation.value = 'साप्ताहिक';
          break;
        case 'monthly':
          selectedAggregation.value = 'मासिक';
          break;
        case 'yearly':
          selectedAggregation.value = 'वार्षिक';
          break;
        default:
          selectedAggregation.value = 'मासिक';
      }
      print(
        '✅ Applied aggregation: "${selectedAggregation.value}" (from ${aggregation})',
      );
    }

    print('🔧 Final applied parameters:');
    print('   selectedClass: "${selectedClass.value}"');
    print('   dateFromFilter: "${dateFromFilter.value}"');
    print('   dateToFilter: "${dateToFilter.value}"');
    print('   selectedAggregation: "${selectedAggregation.value}"');
  }

  Future<void> fetchClasses() async {
    try {
      isLoading.value = true;

      final classList = await apiService.getClasses();

      classes.value = ['सभी कक्षाएं', ...classList];

      // REMOVE THIS LINE:
      // selectedClass.value = 'सभी कक्षाएं';

      print('Classes loaded for analysis: $classList');
    } catch (e) {
      print('Error loading classes: $e');
      classes.value = ['सभी कक्षाएं'];
      Get.snackbar('Error', 'Failed to load classes: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void selectClass(String className) {
    selectedClass.value = className;
    print('📝 Class manually selected: "${className}"');
    // Automatically refresh analytics when class changes
    fetchAnalytics();
  }

  void selectAggregation(String aggregation) {
    selectedAggregation.value = aggregation;
    print('📝 Aggregation manually selected: "${aggregation}"');
    // Automatically refresh analytics when aggregation changes
    fetchAnalytics();
  }

  void setDateFilter(String from, String to) {
    dateFromFilter.value = from;
    dateToFilter.value = to;
    // Automatically refresh analytics when date filter changes
    fetchAnalytics();
  }

  // Manual refresh method
  Future<void> refreshAnalytics() async {
    print('🔄 Manually refreshing analytics...');
    await fetchAnalytics();
  }

  // Debug method to check analytics state
  void debugAnalyticsState() {
    print('🐛 ===== ANALYTICS DEBUG STATE =====');
    print('🐛 Controller instance: ${this.hashCode}');
    print('🐛 selectedClass: "${selectedClass.value}"');
    print('🐛 selectedAggregation: "${selectedAggregation.value}"');
    print('🐛 dateFromFilter: "${dateFromFilter.value}"');
    print('🐛 dateToFilter: "${dateToFilter.value}"');
    print('🐛 isLoading: ${isLoading.value}');
    print('🐛 chartLabels: ${chartLabels.length} - $chartLabels');
    print('🐛 chartValues: ${chartValues.length} - $chartValues');
    print('🐛 totalReaders: ${totalReaders.value}');
    print('🐛 totalCico: ${totalCico.value}');
    print('🐛 totalLostBooks: ${totalLostBooks.value}');
    print('🐛 reportList: ${reportList.length}');
    print('🐛 ===== END DEBUG STATE =====');

    Get.snackbar(
      'Analytics Debug',
      'Readers: ${totalReaders.value}, CICO: ${totalCico.value}, Lost: ${totalLostBooks.value}, Loading: ${isLoading.value}',
      backgroundColor: Colors.blue,
      colorText: Colors.white,
      duration: Duration(seconds: 3),
    );

    // Test API call
    refreshAnalytics();
  }

  Future<void> fetchAnalytics() async {
    try {
      isLoading.value = true;

      final currentUser = _authService.currentUser.value;
      if (currentUser == null) {
        print('No user logged in');
        Get.snackbar('Error', 'Please login first');
        return;
      }

      final className = selectedClass.value == 'सभी कक्षाएं'
          ? null
          : selectedClass.value;

      // Convert Hindi aggregation back to English for API
      String? apiAggregation;
      switch (selectedAggregation.value) {
        case 'दैनिक':
          apiAggregation = 'daily';
          break;
        case 'साप्ताहिक':
          apiAggregation = 'weekly';
          break;
        case 'मासिक':
          apiAggregation = 'monthly';
          break;
        case 'वार्षिक':
          apiAggregation = 'yearly';
          break;
        default:
          apiAggregation = 'monthly';
      }

      print('🔄 Fetching analytics with parameters:');
      print('   Teacher ID (M1_CODE): ${currentUser.code}');
      print('   Selected Class Raw: "${selectedClass.value}"');
      print(
        '   Class Parameter (sent to API): ${className ?? "null (all classes)"}',
      );
      print('   From Date (dateFrom): ${dateFromFilter.value}');
      print('   To Date (dateTo): ${dateToFilter.value}');
      print('   Aggregation: $apiAggregation');
      print('   Will send class to API: ${className != null ? "YES" : "NO"}');

      final fromDate = dateFromFilter.value.isNotEmpty
          ? dateFromFilter.value
          : null;
      final toDate = dateToFilter.value.isNotEmpty ? dateToFilter.value : null;

      // पाठकों की कुल संख्या / कुल रिकॉर्ड / खोई हुई पुस्तकें are computed
      // from CICO report rows independently of the chart/trend fetch below
      // — they used to be nested inside `if (analytics succeeded)`, so any
      // failure of that separate, chart-only endpoint (which has its own
      // offline fallback and failure modes) silently zeroed out the reader
      // count even when the CICO-report-based computation would have
      // worked fine on its own.
      final cicoStats = await _computeCicoStats(
        teacherId: currentUser.code,
        className: className,
        fromDate: fromDate,
        toDate: toDate,
      );
      totalReaders.value = cicoStats.readers;
      totalCico.value = cicoStats.completedReturns;
      totalLostBooks.value = cicoStats.lostBooks;
      totalReaders.refresh();
      totalCico.refresh();
      totalLostBooks.refresh();

      print('📊 CICO stats computed independently of analytics chart:');
      print('   Total Readers: ${totalReaders.value}');
      print('   Total CICO: ${totalCico.value}');
      print('   Total Lost: ${totalLostBooks.value}');

      final result = await apiService.getAnalytics(
        teacherId: currentUser.code,
        className: className,
        dateFrom: fromDate,
        dateTo: toDate,
        aggregation: apiAggregation,
      );

      // ✅ Detect whether response came from offline cache
      isOfflineData.value = result['offline'] == true;

      print('📊 Analytics API result: ${result['success']}');
      print('📊 Offline Mode: ${isOfflineData.value}');
      print('📊 Full API response: $result');

      if (result['success'] == true) {
        final chart = result['chart'] as Map<String, dynamic>? ?? {};

        // ------------------------------------------------------------------
        // ONLINE RESPONSE
        // ------------------------------------------------------------------
        if (!isOfflineData.value) {
          chartLabels.value = List<String>.from(chart['labels'] ?? []);
          chartValues.value = List<int>.from(chart['values'] ?? []);
        }
        // ------------------------------------------------------------------
        // OFFLINE RESPONSE
        // Chart format is {day: count}
        // ------------------------------------------------------------------
        else {
          final sortedDays = chart.keys.toList()..sort();

          chartLabels.value = sortedDays;
          chartValues.value = sortedDays
              .map((day) => (chart[day] as num).toInt())
              .toList();

          Get.snackbar(
            'ऑफलाइन एनालिटिक्स',
            'आप ऑफलाइन हैं — यह स्थानीय कैश्ड डेटा से गणना की गई है।',
            backgroundColor: Colors.blue.shade100,
            duration: const Duration(seconds: 3),
          );
        }

        // If no data
        if (chartLabels.isEmpty || chartValues.isEmpty) {
          print('⚠️ No analytics data available');

          chartLabels.value = [];
          chartValues.value = [];
        }

        // Report list
        reportList.value = List<Map<String, dynamic>>.from(
          result['list'] ?? [],
        );

        print('✅ Analytics chart loaded successfully:');
        print('   Offline: ${isOfflineData.value}');
        print('   Chart Labels: ${chartLabels.length} - $chartLabels');
        print('   Chart Values: ${chartValues.length} - $chartValues');
        print('   Report List: ${reportList.length}');

        chartLabels.refresh();
        chartValues.refresh();
        reportList.refresh();
      } else {
        print('❌ Analytics chart API failed: ${result['message']}');

        chartLabels.value = [];
        chartValues.value = [];
        reportList.value = [];

        Get.snackbar(
          'Analytics Error',
          result['message'] ?? 'Failed to load analytics data',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      print('❌ Error fetching analytics: $e');

      chartLabels.value = [];
      chartValues.value = [];
      reportList.value = [];

      Get.snackbar('Error', 'Failed to load analytics: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Computes all three CICO stats from one fetch of CICO report rows:
  /// - readers: distinct student IDs (falling back to name if no ID field
  ///   is present), each counted once regardless of how many books they
  ///   issued/returned.
  /// - completedReturns: rows where the book came back (F4_BT 2=good or
  ///   3=damaged) — excludes still-checked-out (1) and lost (4) rows.
  /// - lostBooks: rows where F4_BT=4 (marked lost).
  Future<({int readers, int completedReturns, int lostBooks})>
  _computeCicoStats({
    required String teacherId,
    String? className,
    String? fromDate,
    String? toDate,
  }) async {
    try {
      final records = await apiService.getCicoReport(
        teacherId: teacherId,
        className: className,
        fromDate: fromDate,
        toDate: toDate,
      );

      final readerIds = <String>{};
      var completedReturns = 0;
      var lostBooks = 0;

      for (final r in records) {
        final record = r as Map;
        final id = (record['studentId'] ??
                record['F4_PARTY1'] ??
                record['student_id'] ??
                record['studentName'] ??
                record['F4_PARTY1N'] ??
                record['student_name'] ??
                '')
            .toString()
            .trim();
        if (id.isNotEmpty) readerIds.add(id);

        final bt = (record['F4_BT'] ?? '').toString().trim();
        if (bt == '2' || bt == '3') {
          completedReturns++;
        } else if (bt == '4') {
          lostBooks++;
        }
      }

      return (
        readers: readerIds.length,
        completedReturns: completedReturns,
        lostBooks: lostBooks,
      );
    } catch (e) {
      print('❌ Error computing CICO stats: $e');
      return (readers: 0, completedReturns: 0, lostBooks: 0);
    }
  }
}
