import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:room_to_read/services/hybrid_api_service.dart';
import 'package:room_to_read/services/auth_service.dart';

class AnalyticsFilterController extends GetxController {
  final HybridApiService _apiService = Get.find<HybridApiService>();
  final AuthService _authService = Get.find<AuthService>();

  var selectedClass = ''.obs;
  var fromDate = ''.obs;
  var toDate = ''.obs;
  var selectedAggregation = 'monthly'.obs;
  var classes = <String>[].obs;
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
    fetchClasses();
  }

  void _updateFilterValidity() {
    final hasFilter =
        selectedClass.value.isNotEmpty ||
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

  Future<void> fetchClasses() async {
    try {
      isLoading.value = true;
      print('🏫 Analytics: Fetching classes from API...');

      final classList = await _apiService.getClasses();

      if (classList.isNotEmpty) {
        classes.value = ['सभी कक्षाएं', ...classList];
        print('✅ Analytics: Classes loaded successfully: $classList');
      } else {
        print(
          '⚠️ Analytics: API returned empty class list, using fallback classes',
        );
        _setFallbackClasses();
      }
    } catch (e) {
      print('❌ Analytics: Error loading classes: $e');
      _setFallbackClasses();

      Get.snackbar(
        'कक्षा लोड त्रुटि',
        'कक्षाओं की सूची लोड नहीं हो सकी। डिफ़ॉल्ट कक्षाएं दिखाई जा रही हैं।',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
        icon: const Icon(Icons.warning, color: Colors.white),
      );
    } finally {
      isLoading.value = false;
    }
  }

  void _setFallbackClasses() {
    classes.value = [
      'सभी कक्षाएं',
      'कक्षा 1',
      'कक्षा 2',
      'कक्षा 3',
      'कक्षा 4',
      'कक्षा 5',
      'कक्षा 6',
      'कक्षा 7',
      'कक्षा 8',
      'कक्षा 9',
      'कक्षा 10',
    ];
    print(
      '📚 Analytics: Using fallback classes: ${classes.length - 1} classes available',
    );
  }

  Future<void> refreshClasses() async {
    print('🔄 Analytics: Manually refreshing classes...');
    await fetchClasses();
  }

  bool isUsingFallbackClasses() {
    return classes.length <= 1 ||
        (classes.length == 11 &&
            classes.contains('कक्षा 1') &&
            classes.contains('कक्षा 10'));
  }

  void setClass(String className) {
    selectedClass.value = className == 'सभी कक्षाएं' ? '' : className;
    print('Selected class: ${selectedClass.value}');
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
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      fromDate.value = DateFormat('yyyy-MM-dd').format(picked);
      print('Selected from date: ${fromDate.value}');

      if (toDate.value.isNotEmpty) {
        final toDateTime = DateTime.parse(toDate.value);
        if (toDateTime.isBefore(picked)) {
          toDate.value = '';
          Get.snackbar(
            'तारीख त्रुटि',
            'समाप्ति तारीख प्रारंभ तारीख के बाद होनी चाहिए',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );
        }
      }
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
    selectedClass.value = '';
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
        'कृपया कम से कम एक फ़िल्टर लगाएं (कक्षा या तारीख)',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
        icon: const Icon(Icons.warning, color: Colors.white),
      );
      return;
    }

    if (fromDate.value.isNotEmpty && toDate.value.isNotEmpty) {
      final fromDateTime = DateTime.parse(fromDate.value);
      final toDateTime = DateTime.parse(toDate.value);

      if (toDateTime.isBefore(fromDateTime)) {
        Get.snackbar(
          'तारीख त्रुटि',
          'समाप्ति तारीख प्रारंभ तारीख के बाद होनी चाहिए',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          icon: const Icon(Icons.error, color: Colors.white),
        );
        return;
      }
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
      'className': selectedClass.value.isEmpty ? null : selectedClass.value,
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

    if (selectedClass.value.isNotEmpty) {
      filters.add('कक्षा: ${selectedClass.value}');
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
