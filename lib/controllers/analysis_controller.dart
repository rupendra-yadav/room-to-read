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
  var totalRecords = 0.obs;
  var avgPerMonth = 0.obs;
  var reportList = <Map<String, dynamic>>[].obs;

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
    print('🐛 totalRecords: ${totalRecords.value}');
    print('🐛 avgPerMonth: ${avgPerMonth.value}');
    print('🐛 reportList: ${reportList.length}');
    print('🐛 ===== END DEBUG STATE =====');

    Get.snackbar(
      'Analytics Debug',
      'Records: ${totalRecords.value}, Chart: ${chartValues.length} points, Loading: ${isLoading.value}',
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

      final result = await apiService.getAnalytics(
        teacherId: currentUser.code, // Use M1_CODE instead of group1
        className: className,
        dateFrom: dateFromFilter.value.isNotEmpty
            ? dateFromFilter.value
            : null, // Use dateFrom parameter
        dateTo: dateToFilter.value.isNotEmpty
            ? dateToFilter.value
            : null, // Use dateTo parameter
        aggregation: apiAggregation,
      );

      print('📊 Analytics API result: ${result['success']}');
      print('📊 Full API response: $result');

      if (result['success'] == true) {
        // Parse chart data
        final chart = result['chart'] as Map<String, dynamic>? ?? {};
        chartLabels.value = List<String>.from(chart['labels'] ?? []);
        chartValues.value = List<int>.from(chart['values'] ?? []);

        // If no data from API, show empty state
        if (chartLabels.isEmpty || chartValues.isEmpty) {
          print('⚠️ No analytics data available from API');
          chartLabels.value = [];
          chartValues.value = [];
          totalRecords.value = 0;
          avgPerMonth.value = 0;
        }

        // Parse summary data
        final summary = result['summary'] as Map<String, dynamic>? ?? {};
        totalRecords.value =
            summary['total_records'] ?? chartValues.fold(0, (a, b) => a + b);
        avgPerMonth.value =
            summary['avg_per_month'] ??
            (chartValues.isNotEmpty
                ? (chartValues.fold(0, (a, b) => a + b) / chartValues.length)
                      .round()
                : 0);

        // Parse list data
        reportList.value = List<Map<String, dynamic>>.from(
          result['list'] ?? [],
        );

        print('✅ Analytics loaded successfully:');
        print('   Total Records: ${totalRecords.value}');
        print('   Avg Per Month: ${avgPerMonth.value}');
        print('   Chart Labels: ${chartLabels.length} - $chartLabels');
        print('   Chart Values: ${chartValues.length} - $chartValues');
        print('   Report List: ${reportList.length}');

        // Force UI updates
        chartLabels.refresh();
        chartValues.refresh();
        totalRecords.refresh();
        avgPerMonth.refresh();
        reportList.refresh();
      } else {
        print('❌ Analytics API failed: ${result['message']}');

        // Show empty state when API fails
        chartLabels.value = [];
        chartValues.value = [];
        totalRecords.value = 0;
        avgPerMonth.value = 0;
        reportList.value = [];

        Get.snackbar(
          'Analytics Error',
          result['message'] ?? 'Failed to load analytics data',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: Duration(seconds: 4),
        );
      }
    } catch (e) {
      print('❌ Error fetching analytics: $e');

      // Show empty state on error
      chartLabels.value = [];
      chartValues.value = [];
      totalRecords.value = 0;
      avgPerMonth.value = 0;
      reportList.value = [];

      Get.snackbar('Error', 'Failed to load analytics: $e');
    } finally {
      isLoading.value = false;
    }
  }
}
