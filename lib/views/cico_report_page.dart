import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:room_to_read/controllers/cico_report_controller.dart';
import 'package:room_to_read/widgets/custom_app_bar.dart';
import 'package:room_to_read/widgets/shimmer_loading.dart';

class CicoReportPage extends GetView<CicoReportController> {
  const CicoReportPage({Key? key}) : super(key: key);

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.purple,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final formattedDate =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      if (isFromDate) {
        controller.setDateFilter(formattedDate, controller.dateToFilter.value);
      } else {
        controller.setDateFilter(
          controller.dateFromFilter.value,
          formattedDate,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final horizontalPadding = isMobile ? 16.0 : 24.0;
    final verticalPadding = isMobile ? 16.0 : 20.0;

    return Scaffold(
      appBar: CustomAppBar(title: 'Room To Read'),
      body: Obx(() {
        // Show shimmer loading state
        if (controller.isLoading.value) {
          return ListView.builder(
            itemCount: 5,
            itemBuilder: (context, index) => const StudentCardShimmer(),
          );
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with back button
              Container(
                color: Colors.purple,
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                        Text(
                          'CICO रिपोर्ट',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 20 : 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: verticalPadding),
                    // Class Dropdown
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Obx(
                          () => DropdownButton<String>(
                            value: controller.selectedClass.value,
                            isExpanded: true,
                            underline: const SizedBox(),
                            hint: const Text('कक्षा चुनें'),
                            items: controller.classes.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  value,
                                  style: TextStyle(
                                    fontSize: isMobile ? 14 : 15,
                                    color: Colors.black,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                controller.selectClass(newValue);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Filter Section
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: TextField(
                        controller: controller.searchController,
                        onChanged: (value) {
                          controller.searchRecords(value);
                        },
                        decoration: InputDecoration(
                          hintText: 'छात्र, रोल नंबर, या किताब खोजें',
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: isMobile ? 13 : 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.grey[400],
                            size: isMobile ? 20 : 22,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 12 : 14,
                            vertical: isMobile ? 10 : 12,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: isMobile ? 14 : 16),
                    // Date Filter Section
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: Colors.grey[700],
                          size: isMobile ? 18 : 20,
                        ),
                        SizedBox(width: isMobile ? 8 : 10),
                        Text(
                          'तिथि फिल्टर',
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isMobile ? 10 : 12),
                    // Date Range Pickers
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'से (From)',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: isMobile ? 12 : 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: isMobile ? 6 : 8),
                              Obx(
                                () => GestureDetector(
                                  onTap: () => _selectDate(context, true),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isMobile ? 12 : 14,
                                      vertical: isMobile ? 12 : 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          controller
                                                  .dateFromFilter
                                                  .value
                                                  .isEmpty
                                              ? 'तारीख चुनें'
                                              : controller.dateFromFilter.value,
                                          style: TextStyle(
                                            color:
                                                controller
                                                    .dateFromFilter
                                                    .value
                                                    .isEmpty
                                                ? Colors.grey[400]
                                                : Colors.black,
                                            fontSize: isMobile ? 13 : 14,
                                          ),
                                        ),
                                        Icon(
                                          Icons.calendar_today,
                                          size: isMobile ? 16 : 18,
                                          color: Colors.grey[600],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: isMobile ? 10 : 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'तक (To)',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: isMobile ? 12 : 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: isMobile ? 6 : 8),
                              Obx(
                                () => GestureDetector(
                                  onTap: () => _selectDate(context, false),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isMobile ? 12 : 14,
                                      vertical: isMobile ? 12 : 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          controller.dateToFilter.value.isEmpty
                                              ? 'तारीख चुनें'
                                              : controller.dateToFilter.value,
                                          style: TextStyle(
                                            color:
                                                controller
                                                    .dateToFilter
                                                    .value
                                                    .isEmpty
                                                ? Colors.grey[400]
                                                : Colors.black,
                                            fontSize: isMobile ? 13 : 14,
                                          ),
                                        ),
                                        Icon(
                                          Icons.calendar_today,
                                          size: isMobile ? 16 : 18,
                                          color: Colors.grey[600],
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
                    SizedBox(height: isMobile ? 10 : 12),
                    // Clear Filter Button
                    Obx(() {
                      if (controller.dateFromFilter.value.isNotEmpty ||
                          controller.dateToFilter.value.isNotEmpty) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: isMobile ? 10 : 12),
                          child: GestureDetector(
                            onTap: () {
                              controller.clearDateFilter();
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 12 : 14,
                                vertical: isMobile ? 8 : 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red[200]!),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.clear,
                                    color: Colors.red,
                                    size: isMobile ? 16 : 18,
                                  ),
                                  SizedBox(width: isMobile ? 6 : 8),
                                  Text(
                                    'फिल्टर साफ़ करें',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: isMobile ? 12 : 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }),
                    // Show current date range if filters are applied
                    Obx(() {
                      if (controller.dateFromFilter.value.isNotEmpty ||
                          controller.dateToFilter.value.isNotEmpty) {
                        return Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 12 : 14,
                            vertical: isMobile ? 8 : 10,
                          ),
                          margin: EdgeInsets.only(bottom: isMobile ? 10 : 12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue[700],
                                size: isMobile ? 16 : 18,
                              ),
                              SizedBox(width: isMobile ? 8 : 10),
                              Expanded(
                                child: Text(
                                  'फिल्टर: ${controller.dateFromFilter.value.isNotEmpty ? controller.dateFromFilter.value : 'शुरुआत'} से ${controller.dateToFilter.value.isNotEmpty ? controller.dateToFilter.value : 'अंत'} तक (${controller.bookIssues.length} रिकॉर्ड)',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontSize: isMobile ? 12 : 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }),
                    SizedBox(height: isMobile ? 14 : 16),
                    // Book Issues List
                    Obx(() {
                      final records =
                          controller.filteredBookIssues.isEmpty &&
                              controller.searchQuery.value.isEmpty
                          ? controller.bookIssues
                          : controller.filteredBookIssues;

                      // Calculate statistics
                      final totalRecords = (records as List).length;

                      if (controller.filteredBookIssues.isEmpty &&
                          controller.dateFromFilter.value.isEmpty &&
                          controller.dateToFilter.value.isEmpty &&
                          controller.selectedClass.value == null &&
                          controller.searchQuery.value.isEmpty) {
                        return Container(
                          padding: EdgeInsets.all(isMobile ? 24 : 32),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.filter_alt_outlined,
                                color: Colors.grey[400],
                                size: 40,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'कक्षा, तिथि या नाम से फ़िल्टर करें',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: isMobile ? 13 : 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Statistics Summary
                          if (totalRecords > 0)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'CICO रिकॉर्ड (${totalRecords})',
                                    style: TextStyle(
                                      fontSize: isMobile ? 14 : 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                // Loading indicator for filtering
                                Obx(() {
                                  if (controller.isLoading.value) {
                                    return Container(
                                      padding: EdgeInsets.all(8),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.purple,
                                              ),
                                        ),
                                      ),
                                    );
                                  }
                                  return SizedBox.shrink();
                                }),
                                // Refresh button
                                GestureDetector(
                                  onTap: () {
                                    controller.fetchBookIssues();
                                  },
                                  child: Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.purple[50],
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.purple[200]!,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.refresh,
                                          color: Colors.purple[700],
                                          size: 16,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'रिफ्रेश',
                                          style: TextStyle(
                                            color: Colors.purple[700],
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Debug button
                                // SizedBox(width: 8),
                              ],
                            ),
                          SizedBox(height: isMobile ? 10 : 12),
                          if (records.isEmpty)
                            Container(
                              padding: EdgeInsets.all(isMobile ? 16 : 20),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Center(
                                child: Text(
                                  'कोई रिकॉर्ड नहीं मिला',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: isMobile ? 13 : 14,
                                  ),
                                ),
                              ),
                            )
                          else
                            ...records.map((record) {
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: isMobile ? 10 : 12,
                                ),
                                child: _buildBookIssueCard(record, isMobile),
                              );
                            }).toList(),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildBookIssueCard(Map<String, dynamic> record, bool isMobile) {
    // Determine the status based on F4_BT value
    String status = 'जारी';
    Color statusColor = Colors.blue;
    IconData statusIcon = Icons.book;

    final btValue = record['F4_BT']?.toString() ?? '1';
    switch (btValue) {
      case '1':
        status = 'जारी';
        statusColor = Colors.blue;
        statusIcon = Icons.book;
        break;
      case '2':
        status = 'वापस (सही स्थिति)';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case '3':
        status = 'वापस (क्षतिग्रस्त)';
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        break;
      case '4':
        status = 'खो गई';
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      default:
        status = 'अज्ञात';
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 8 : 10,
                  vertical: isMobile ? 4 : 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      statusIcon,
                      color: statusColor,
                      size: isMobile ? 14 : 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: isMobile ? 11 : 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Transaction Code
              // if (record['F4_BT'] != null)
              //   Text(
              //     'TX: ${record['F4_BT']}',
              //     style: TextStyle(
              //       color: Colors.grey[600],
              //       fontSize: isMobile ? 10 : 11,
              //       fontFamily: 'monospace',
              //     ),
              //   ),
            ],
          ),
          SizedBox(height: isMobile ? 10 : 12),
          // Student Info
          Row(
            children: [
              Container(
                width: isMobile ? 36 : 40,
                height: isMobile ? 36 : 40,
                decoration: BoxDecoration(
                  color: Colors.purple[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.person,
                  color: Colors.purple[700],
                  size: isMobile ? 20 : 22,
                ),
              ),
              SizedBox(width: isMobile ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record['studentName'] ?? record['F4_PARTY1N'] ?? 'N/A',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: isMobile ? 13 : 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'कक्षा: ${record['className'] ?? record['F4_TXT1'] ?? 'N/A'}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: isMobile ? 11 : 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 10 : 12),
          Divider(color: Colors.grey[300]),
          SizedBox(height: isMobile ? 8 : 10),
          // Book Info
          Row(
            children: [
              Icon(
                Icons.menu_book,
                color: Colors.purple,
                size: isMobile ? 18 : 20,
              ),
              SizedBox(width: isMobile ? 8 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record['bookName'] ?? record['F4_PARTYN'] ?? 'N/A',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: isMobile ? 12 : 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'पुस्तक आईडी: ${record['F4_PARTY_NO']}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: isMobile ? 11 : 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 10 : 12),
          // Date Info
          Column(
            children: [
              // Issue Date
              if (record['F4_DATE1'] != null || record['F4_DATE'] != null)
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: Colors.grey[600],
                      size: isMobile ? 14 : 16,
                    ),
                    SizedBox(width: isMobile ? 6 : 8),
                    Text(
                      'जारी: ${record['F4_DATE1'] ?? record['F4_DATE'] ?? 'N/A'}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: isMobile ? 11 : 12,
                      ),
                    ),
                  ],
                ),
              // Return Date (if available)
              if (record['F4_DATE2'] != null &&
                  record['F4_DATE2'].toString().isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: isMobile ? 4 : 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_available,
                        color: Colors.grey[600],
                        size: isMobile ? 14 : 16,
                      ),
                      SizedBox(width: isMobile ? 6 : 8),
                      Text(
                        'वापसी: ${record['F4_DATE2']}',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: isMobile ? 11 : 12,
                        ),
                      ),
                    ],
                  ),
                ),
              // User Date (if different from issue date)
              if (record['F4_USERDT'] != null &&
                  record['F4_USERDT'].toString().isNotEmpty &&
                  record['F4_USERDT'] != record['F4_DATE1'])
                Padding(
                  padding: EdgeInsets.only(top: isMobile ? 4 : 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: Colors.grey[600],
                        size: isMobile ? 14 : 16,
                      ),
                      SizedBox(width: isMobile ? 6 : 8),
                      Text(
                        'अपडेट: ${record['F4_USERDT']}',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: isMobile ? 11 : 12,
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: isMobile ? 10 : 12),
            ],
          ),
        ],
      ),
    );
  }
}
