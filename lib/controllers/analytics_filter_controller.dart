import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:room_to_read/models/grade_model.dart';
import 'package:room_to_read/services/hybrid_api_service.dart';
import 'package:room_to_read/services/auth_service.dart';

class AnalyticsFilterController extends GetxController {
  final HybridApiService _apiService = Get.find<HybridApiService>();
  final AuthService _authService = Get.find<AuthService>();

  var selectedGrade = Rx<Grade?>(null);
  var fromDate = ''.obs;
  var toDate = ''.obs;
  var selectedAggregation = 'monthly'.obs;
  var grades = <Grade>[].obs;
  var isLoading = false.obs;
  final filtersValid = false.obs;

  final List<String> aggregationOptions = [
    'daily',
    'weekly',
    'monthly',
    'yearly',
  ];

  @override
  void onInit() {
    super.onInit();
    fetchGrades();
  }

  void _updateFilterValidity() {
    final hasFilter =
        selectedGrade.value != null ||
        fromDate.value.isNotEmpty ||
        toDate.value.isNotEmpty;

    if (!hasFilter) {
      filtersValid.value = false;
      return;
    }

    if (fromDate.value.isNotEmpty && toDate.value.isNotEmpty) {
      try {
        final from = DateTime.parse(fromDate.value);
        final to = DateTime.parse(toDate.value);
        filtersValid.value = !to.isBefore(from);
      } catch (_) {
        filtersValid.value = false;
      }
      return;
    }

    filtersValid.value = true;
  }

  Future<void> fetchGrades() async {
    try {
      isLoading.value = true;
      print('🏫 Analytics: Fetching grades from API...');

      final gradeList = await _apiService.getGrades();

      if (gradeList.isNotEmpty) {
        grades.value = gradeList;
        print('✅ Analytics: Grades loaded successfully: $gradeList');
      } else {
        print('⚠️ Analytics: API returned empty grade list');
        Get.snackbar(
          'ग्रेड लोड त्रुटि',
          'ग्रेड की सूची लोड नहीं हो सकी।',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
          icon: const Icon(Icons.warning, color: Colors.white),
        );
      }
    } catch (e) {
      print('❌ Analytics: Error loading grades: $e');
      Get.snackbar(
        'ग्रेड लोड त्रुटि',
        'ग्रेड की सूची लोड नहीं हो सकी।',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
        icon: const Icon(Icons.warning, color: Colors.white),
      );
    } finally {
      isLoading.value = false;
    }
  }

  void selectGrade(Grade? grade) {
    selectedGrade.value = grade;
    print('Selected grade: ${grade?.name}');
    _updateFilterValidity();
  }

  void setAggregation(String aggregation) {
    selectedAggregation.value = aggregation;
    print('Selected aggregation: $aggregation');
  }

  String getAggregationDisplayName(String value) {
    switch (value) {
      case 'daily':
        return 'दैनिक (Daily)';
      case 'weekly':
        return 'साप्ताहिक (Weekly)';
      case 'monthly':
        return 'मासिक (Monthly)';
      case 'yearly':
        return 'वार्षिक (Yearly)';
      default:
        return 'मासिक (Monthly)';
    }
  }

  Future<void> selectFromDate(BuildContext context) async {
    DateTime lastDate = DateTime.now();

    if (toDate.value.isNotEmpty) {
      lastDate = DateTime.parse(toDate.value);
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: lastDate.isBefore(DateTime.now())
          ? lastDate
          : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: lastDate,
    );

    if (picked != null) {
      fromDate.value = DateFormat('yyyy-MM-dd').format(picked);
      print('Selected from date: ${fromDate.value}');
      _updateFilterValidity();
    }
  }

  Future<void> selectToDate(BuildContext context) async {
    DateTime initialDate = DateTime.now();
    DateTime firstDate = DateTime(2020);

    if (fromDate.value.isNotEmpty) {
      firstDate = DateTime.parse(fromDate.value);
      if (initialDate.isBefore(firstDate)) {
        initialDate = firstDate;
      }
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      toDate.value = DateFormat('yyyy-MM-dd').format(picked);
      print('Selected to date: ${toDate.value}');
      _updateFilterValidity();
    }
  }

  void resetFilters() {
    selectedGrade.value = null;
    fromDate.value = '';
    toDate.value = '';
    selectedAggregation.value = 'monthly';
    _updateFilterValidity();

    Get.snackbar(
      'फ़िल्टर रीसेट',
      'सभी फ़िल्टर साफ कर दिए गए हैं',
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );

    print('Filters reset');
  }

  void generateReport() {
    if (!filtersValid.value) {
      Get.snackbar(
        'फ़िल्टर आवश्यक',
        'कृपया कम से कम एक फ़िल्टर लगाएं (ग्रेड या तारीख)',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
        icon: const Icon(Icons.warning, color: Colors.white),
      );
      return;
    }

    final currentUser = _authService.currentUser.value;
    if (currentUser == null) {
      Get.snackbar(
        'त्रुटि',
        'उपयोगकर्ता लॉग इन नहीं है',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        icon: const Icon(Icons.error, color: Colors.white),
      );
      return;
    }

    final filterParams = {
      'teacherId': currentUser.code,
      'className': selectedGrade.value?.name,
      'fromDate': fromDate.value.isEmpty ? null : fromDate.value,
      'toDate': toDate.value.isEmpty ? null : toDate.value,
      'aggregation': selectedAggregation.value,
    };

    print('Generating report with filters: $filterParams');

    Get.toNamed('/analysis', arguments: filterParams);

    Get.snackbar(
      'रिपोर्ट तैयार की जा रही है',
      'कृपया प्रतीक्षा करें...',
      backgroundColor: Colors.blue,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
      icon: const Icon(Icons.analytics, color: Colors.white),
    );
  }

  bool areFiltersValid() => filtersValid.value;

  String getFilterSummary() {
    List<String> filters = [];

    if (selectedGrade.value != null) {
      filters.add('ग्रेड: ${selectedGrade.value!.name}');
    }

    if (fromDate.value.isNotEmpty || toDate.value.isNotEmpty) {
      String dateRange = 'तारीख: ';
      if (fromDate.value.isNotEmpty) {
        dateRange += fromDate.value;
      }
      if (toDate.value.isNotEmpty) {
        dateRange += ' से ${toDate.value}';
      }
      filters.add(dateRange);
    }

    filters.add(
      'समूहन: ${getAggregationDisplayName(selectedAggregation.value)}',
    );

    return filters.join(' • ');
  }
}
