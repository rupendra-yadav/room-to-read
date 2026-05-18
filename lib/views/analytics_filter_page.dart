import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:room_to_read/controllers/analytics_filter_controller.dart';
import 'package:room_to_read/widgets/custom_app_bar.dart';

class AnalyticsFilterPage extends GetView<AnalyticsFilterController> {
  const AnalyticsFilterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final horizontalPadding = isMobile ? 16.0 : 24.0;
    final verticalPadding = isMobile ? 16.0 : 20.0;

    return SafeArea(
      child: Scaffold(
        appBar: CustomAppBar(title: 'Room To Read'),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                color: Colors.indigo,
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Get.back(),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'विश्लेषण',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 18 : 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'डेटा फ़िल्टर सेट करें',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: isMobile ? 13 : 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Info Card
              Padding(
                padding: EdgeInsets.all(horizontalPadding),
                child: Container(
                  padding: EdgeInsets.all(isMobile ? 14 : 16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        color: Colors.blue[700],
                        size: isMobile ? 24 : 28,
                      ),
                      SizedBox(width: isMobile ? 12 : 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'विश्लेषण रिपोर्ट देखने के लिए फ़िल्टर आवश्यक',
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontSize: isMobile ? 13 : 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'कम से कम एक फ़िल्टर (कक्षा या तारीख) लगाना आवश्यक है',
                              style: TextStyle(
                                color: Colors.blue[600],
                                fontSize: isMobile ? 12 : 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Filters Section
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'फ़िल्टर',
                      style: TextStyle(
                        fontSize: isMobile ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: isMobile ? 16 : 20),

                    // Class Filter
                    _buildFilterSection(
                      title: 'कक्षा चुनें',
                      isMobile: isMobile,
                      child: Column(
                        children: [
                          // Fallback warning
                          Obx(
                            () => controller.isUsingFallbackClasses()
                                ? Container(
                                    padding: EdgeInsets.all(isMobile ? 8 : 10),
                                    margin: EdgeInsets.only(
                                      bottom: isMobile ? 8 : 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[50],
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.orange[300]!,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.warning_outlined,
                                          color: Colors.orange[700],
                                          size: isMobile ? 16 : 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'डिफ़ॉल्ट कक्षाएं दिखाई जा रही हैं',
                                            style: TextStyle(
                                              color: Colors.orange[700],
                                              fontSize: isMobile ? 11 : 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () =>
                                              controller.refreshClasses(),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.orange[100],
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.refresh,
                                                  color: Colors.orange[700],
                                                  size: 14,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'रिफ्रेश',
                                                  style: TextStyle(
                                                    color: Colors.orange[700],
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),

                          // Class dropdown
                          Obx(
                            () => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: controller.isLoading.value
                                  ? Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: isMobile ? 16 : 18,
                                      ),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  const AlwaysStoppedAnimation<
                                                    Color
                                                  >(Colors.blue),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'कक्षाएं लोड हो रही हैं...',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: isMobile ? 14 : 15,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : DropdownButton<String>(
                                      value:
                                          controller.selectedClass.value.isEmpty
                                          ? null
                                          : controller.selectedClass.value,
                                      hint: Text(
                                        'सभी कक्षाएं',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: isMobile ? 14 : 15,
                                        ),
                                      ),
                                      isExpanded: true,
                                      underline: const SizedBox(),
                                      items: controller.classes.map((
                                        String value,
                                      ) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(
                                            value == 'सभी कक्षाएं'
                                                ? value
                                                : 'कक्षा: $value',
                                            style: TextStyle(
                                              fontSize: isMobile ? 14 : 15,
                                              color: Colors.black,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (String? newValue) {
                                        controller.setClass(newValue ?? '');
                                      },
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: isMobile ? 20 : 24),

                    // Date Range Filter
                    _buildFilterSection(
                      title: 'तिथि सीमा',
                      isMobile: isMobile,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'से (From)',
                                  style: TextStyle(
                                    fontSize: isMobile ? 13 : 14,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Obx(
                                  () => GestureDetector(
                                    onTap: () =>
                                        controller.selectFromDate(context),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: isMobile ? 14 : 16,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey[300]!,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            color: Colors.grey[600],
                                            size: isMobile ? 18 : 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            controller.fromDate.value.isEmpty
                                                ? 'तारीख चुनें'
                                                : controller.fromDate.value,
                                            style: TextStyle(
                                              fontSize: isMobile ? 14 : 15,
                                              color:
                                                  controller
                                                      .fromDate
                                                      .value
                                                      .isEmpty
                                                  ? Colors.grey[600]
                                                  : Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: isMobile ? 12 : 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'तक (To)',
                                  style: TextStyle(
                                    fontSize: isMobile ? 13 : 14,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Obx(
                                  () => GestureDetector(
                                    onTap: () =>
                                        controller.selectToDate(context),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: isMobile ? 14 : 16,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey[300]!,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            color: Colors.grey[600],
                                            size: isMobile ? 18 : 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            controller.toDate.value.isEmpty
                                                ? 'तारीख चुनें'
                                                : controller.toDate.value,
                                            style: TextStyle(
                                              fontSize: isMobile ? 14 : 15,
                                              color:
                                                  controller
                                                      .toDate
                                                      .value
                                                      .isEmpty
                                                  ? Colors.grey[600]
                                                  : Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: isMobile ? 20 : 24),

                    // Aggregation Filter
                    _buildFilterSection(
                      title: 'समूहन (Aggregation)',
                      isMobile: isMobile,
                      child: Obx(
                        () => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<String>(
                            value: controller.selectedAggregation.value,
                            isExpanded: true,
                            underline: const SizedBox(),
                            items: controller.aggregationOptions.map((
                              String value,
                            ) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  controller.getAggregationDisplayName(value),
                                  style: TextStyle(
                                    fontSize: isMobile ? 14 : 15,
                                    color: Colors.black,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              controller.setAggregation(newValue ?? 'monthly');
                            },
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: isMobile ? 32 : 40),

                    // Action Buttons
                    Column(
                      children: [
                        // Filter Status Indicator
                        Obx(
                          () => Container(
                            padding: EdgeInsets.all(isMobile ? 12 : 14),
                            margin: EdgeInsets.only(bottom: isMobile ? 16 : 20),
                            decoration: BoxDecoration(
                              color: controller.filtersValid.value
                                  ? Colors.green[50]
                                  : Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: controller.filtersValid.value
                                    ? Colors.green[300]!
                                    : Colors.orange[300]!,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  controller.filtersValid.value
                                      ? Icons.check_circle_outline
                                      : Icons.warning_outlined,
                                  color: controller.filtersValid.value
                                      ? Colors.green[700]
                                      : Colors.orange[700],
                                  size: isMobile ? 20 : 22,
                                ),
                                SizedBox(width: isMobile ? 10 : 12),
                                Expanded(
                                  child: Text(
                                    controller.filtersValid.value
                                        ? 'फ़िल्टर लगाए गए: ${controller.getFilterSummary()}'
                                        : 'कृपया कम से कम एक फ़िल्टर लगाएं (कक्षा या तारीख)',
                                    style: TextStyle(
                                      color: controller.filtersValid.value
                                          ? Colors.green[700]
                                          : Colors.orange[700],
                                      fontSize: isMobile ? 12 : 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Generate Report Button
                        Obx(
                          () => SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: controller.filtersValid.value
                                  ? () => controller.generateReport()
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: controller.filtersValid.value
                                    ? Colors.blue
                                    : Colors.grey[400],
                                padding: EdgeInsets.symmetric(
                                  vertical: isMobile ? 14 : 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    controller.filtersValid.value
                                        ? Icons.analytics
                                        : Icons.block,
                                    color: Colors.white,
                                    size: isMobile ? 18 : 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    controller.filtersValid.value
                                        ? 'रिपोर्ट देखें'
                                        : 'फ़िल्टर आवश्यक',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isMobile ? 16 : 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: isMobile ? 12 : 16),

                        // Reset Button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => controller.resetFilters(),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                vertical: isMobile ? 14 : 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              side: BorderSide(color: Colors.grey[400]!),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.refresh,
                                  color: Colors.grey[700],
                                  size: isMobile ? 18 : 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'रीसेट करें',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: isMobile ? 16 : 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: isMobile ? 20 : 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection({
    required String title,
    required Widget child,
    required bool isMobile,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: isMobile ? 15 : 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: isMobile ? 8 : 10),
        child,
      ],
    );
  }
}
