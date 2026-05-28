import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:room_to_read/controllers/checkin_controller.dart';
import 'package:room_to_read/models/grade_model.dart';
import 'package:room_to_read/widgets/custom_app_bar.dart';
import 'package:room_to_read/widgets/shimmer_loading.dart';
import 'package:room_to_read/widgets/offline_status_widget.dart';

class CheckinPage extends GetView<CheckinController> {
  const CheckinPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final horizontalPadding = isMobile ? 16.0 : 24.0;
    final verticalPadding = isMobile ? 16.0 : 20.0;

    return Scaffold(
      appBar: CustomAppBar(title: 'Room To Read'),
      body: Column(
        children: [
          // Offline Status Widget
          OfflineStatusWidget(),
          // Main Content
          Expanded(
            child: Obx(() {
              // Show shimmer loading state
              if (controller.isLoading.value) {
                return Column(
                  children: [
                    // Show loading message after a delay
                    Container(
                      padding: EdgeInsets.all(16),
                      margin: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'चेक इन किताबें लोड हो रही हैं... कृपया प्रतीक्षा करें।',
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Show shimmer cards
                    Expanded(
                      child: ListView.builder(
                        itemCount: 3,
                        itemBuilder: (context, index) =>
                            const StudentCardShimmer(),
                      ),
                    ),
                  ],
                );
              }

              // Show detail view if a record is selected
              if (controller.selectedRecord.value != null) {
                return _buildDetailView(
                  context,
                  controller.selectedRecord.value!,
                  isMobile,
                  horizontalPadding,
                  verticalPadding,
                );
              }

              // Show list view
              return RefreshIndicator(
                onRefresh: () async {
                  await controller.refreshCheckedOutBooks();
                },
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Container(
                        color: Colors.green,
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
                                  'चेक इन',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isMobile ? 20 : 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: verticalPadding),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Obx(
                                        () => DropdownButton<Grade>(
                                          value: controller.classes
                                              .firstWhereOrNull(
                                                (g) =>
                                                    g.name ==
                                                    controller
                                                        .selectedClass
                                                        .value,
                                              ),
                                          isExpanded: true,
                                          underline: const SizedBox(),
                                          hint: const Text('ग्रेड चुनें'),
                                          items: controller.classes.map((
                                            Grade grade,
                                          ) {
                                            return DropdownMenuItem<Grade>(
                                              value: grade,
                                              child: Text(
                                                'ग्रेड: ${grade.name}',
                                                style: TextStyle(
                                                  fontSize: isMobile ? 14 : 15,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (Grade? newValue) {
                                            if (newValue != null) {
                                              controller.selectClass(newValue);
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                // Clear class filter button
                                Obx(
                                  () => controller.selectedClass.value != null
                                      ? GestureDetector(
                                          onTap: () {
                                            controller.clearClassFilter();
                                          },
                                          child: Container(
                                            padding: EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.red[50],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.red[200]!,
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.close,
                                              color: Colors.red[700],
                                              size: 20,
                                            ),
                                          ),
                                        )
                                      : SizedBox(width: 40),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: verticalPadding,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date Filter - Always show from and to date pickers
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
                            SizedBox(height: isMobile ? 12 : 14),

                            // Date range pickers - always visible
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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

                                      GestureDetector(
                                        onTap: () async {
                                          final DateTime?
                                          picked = await showDatePicker(
                                            context: context,
                                            initialDate: DateTime.now(),
                                            firstDate: DateTime(2020),
                                            lastDate: DateTime.now(),
                                            builder: (context, child) {
                                              return Theme(
                                                data: Theme.of(context).copyWith(
                                                  colorScheme:
                                                      const ColorScheme.light(
                                                        primary: Colors.green,
                                                        onPrimary: Colors.white,
                                                        onSurface: Colors.black,
                                                      ),
                                                ),
                                                child: child!,
                                              );
                                            },
                                          );
                                          if (picked != null) {
                                            controller.setDateFilter(
                                              '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}',
                                              controller.dateToFilter.value,
                                            );
                                          }
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isMobile ? 12 : 14,
                                            vertical: isMobile ? 12 : 14,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[50],
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.grey[300]!,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Obx(
                                                () => Text(
                                                  controller
                                                          .dateFromFilter
                                                          .value
                                                          .isEmpty
                                                      ? 'तारीख चुनें'
                                                      : controller
                                                            .dateFromFilter
                                                            .value,
                                                  style: TextStyle(
                                                    color:
                                                        controller
                                                            .dateFromFilter
                                                            .value
                                                            .isEmpty
                                                        ? Colors.grey[400]
                                                        : Colors.black,
                                                    fontSize: isMobile
                                                        ? 13
                                                        : 14,
                                                  ),
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
                                    ],
                                  ),
                                ),
                                SizedBox(width: isMobile ? 10 : 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                      GestureDetector(
                                        onTap: () async {
                                          final DateTime?
                                          picked = await showDatePicker(
                                            context: context,
                                            initialDate: DateTime.now(),
                                            firstDate: DateTime(2020),
                                            lastDate: DateTime.now(),
                                            builder: (context, child) {
                                              return Theme(
                                                data: Theme.of(context).copyWith(
                                                  colorScheme:
                                                      const ColorScheme.light(
                                                        primary: Colors.green,
                                                        onPrimary: Colors.white,
                                                        onSurface: Colors.black,
                                                      ),
                                                ),
                                                child: child!,
                                              );
                                            },
                                          );
                                          if (picked != null) {
                                            controller.setDateFilter(
                                              controller.dateFromFilter.value,
                                              '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}',
                                            );
                                          }
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isMobile ? 12 : 14,
                                            vertical: isMobile ? 12 : 14,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[50],
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.grey[300]!,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Obx(
                                                () => Text(
                                                  controller
                                                          .dateToFilter
                                                          .value
                                                          .isEmpty
                                                      ? 'तारीख चुनें'
                                                      : controller
                                                            .dateToFilter
                                                            .value,
                                                  style: TextStyle(
                                                    color:
                                                        controller
                                                            .dateToFilter
                                                            .value
                                                            .isEmpty
                                                        ? Colors.grey[400]
                                                        : Colors.black,
                                                    fontSize: isMobile
                                                        ? 13
                                                        : 14,
                                                  ),
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
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // After the two date picker rows, add:
                            Obx(
                              () =>
                                  (controller.dateFromFilter.value.isNotEmpty ||
                                      controller.dateToFilter.value.isNotEmpty)
                                  ? Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: GestureDetector(
                                        onTap: () {
                                          controller.setDateFilter('', '');
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange[50],
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.orange[200]!,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.clear,
                                                color: Colors.orange[700],
                                                size: 16,
                                              ),
                                              SizedBox(width: 6),
                                              Text(
                                                'तिथि फिल्टर हटाएं',
                                                style: TextStyle(
                                                  color: Colors.orange[700],
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    )
                                  : SizedBox.shrink(),
                            ),

                            SizedBox(height: isMobile ? 16 : 20),
                            // Search
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: TextField(
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
                            // Records
                            Obx(() {
                              // Use filteredRecords if search or class filter is active
                              // Otherwise use all checkedOutBooks
                              // AFTER
                              List<Map<String, dynamic>> records = controller
                                  .filteredRecords
                                  .toList();

                              // Filter out records with completely empty data
                              // Only exclude if BOTH student name AND book code are missing
                              records = records.where((record) {
                                // Parse rawData if available
                                Map<String, dynamic>? rawData;
                                try {
                                  if (record['rawData'] != null &&
                                      record['rawData'].toString().isNotEmpty) {
                                    rawData = jsonDecode(record['rawData']);
                                  }
                                } catch (e) {
                                  // Silent fail
                                }

                                final studentName =
                                    rawData?['F4_PARTY1N']?.toString() ??
                                    record['F4_PARTY1N']?.toString() ??
                                    record['studentName']?.toString() ??
                                    '';
                                final bookCode =
                                    rawData?['F4_LCODE']?.toString() ??
                                    record['F4_LCODE']?.toString() ??
                                    record['bookCode']?.toString() ??
                                    '';

                                // Only exclude if we have neither student name nor book code
                                // (completely invalid record)
                                return studentName.isNotEmpty ||
                                    bookCode.isNotEmpty;
                              }).toList();

                              // Debug: Print the records being displayed

                              // Additional debug: Print actual content
                              if (records.isNotEmpty) {
                                for (int i = 0; i < records.length; i++) {}
                              } else {}

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'चेक आउट किताबें (${records.length}) - केवल बैकएंड डेटा',
                                        style: TextStyle(
                                          fontSize: isMobile ? 14 : 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      Spacer(),

                                      // Debug info
                                      SizedBox(width: 8),
                                      // Refresh button
                                      GestureDetector(
                                        onTap: () async {
                                          await controller
                                              .refreshCheckedOutBooks();
                                        },
                                        child: Container(
                                          padding: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.green[50],
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: Colors.green[200]!,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.refresh,
                                                color: Colors.green[700],
                                                size: 16,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'रिफ्रेश',
                                                style: TextStyle(
                                                  color: Colors.green[700],
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: isMobile ? 10 : 12),
                                  if (records.isEmpty)
                                    Container(
                                      padding: EdgeInsets.all(
                                        isMobile ? 16 : 20,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.grey[300]!,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.inbox_outlined,
                                            size: 48,
                                            color: Colors.grey[400],
                                          ),
                                          SizedBox(height: 12),
                                          Text(
                                            'कोई रिकॉर्ड नहीं मिला',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: isMobile ? 14 : 15,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'चेक आउट किताबों की सूची खाली है या कोई भी रिकॉर्ड फिल्टर के बाद नहीं बचा है।',
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: isMobile ? 12 : 13,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    Column(
                                      children: [
                                        // Debug section for troubleshooting

                                        // Records list - Use ListView.builder for better performance and display
                                        ListView.builder(
                                          shrinkWrap: true,
                                          physics:
                                              NeverScrollableScrollPhysics(),
                                          itemCount: records.length,
                                          itemBuilder: (context, index) {
                                            final record = records[index];

                                            // Debug: Print each record to see what data is available

                                            // Debug: Print ALL available fields to understand the structure
                                            record.forEach((key, value) {});

                                            // Parse rawData if available for better data extraction
                                            Map<String, dynamic>? rawData;
                                            try {
                                              if (record['rawData'] != null &&
                                                  record['rawData']
                                                      .toString()
                                                      .isNotEmpty) {
                                                rawData = jsonDecode(
                                                  record['rawData'],
                                                );
                                              }
                                              // ignore: empty_catches
                                            } catch (e) {}

                                            // Enhanced field extraction - get first non-empty value (from rawData first, then record)
                                            String getFieldValue(
                                              Map<String, dynamic> rec,
                                              Map<String, dynamic>? rawDataMap,
                                              List<String> keys, {
                                              String defaultValue = '',
                                            }) {
                                              // First, try rawData if available
                                              if (rawDataMap != null) {
                                                for (final key in keys) {
                                                  final value =
                                                      rawDataMap[key]
                                                          ?.toString()
                                                          .trim() ??
                                                      '';
                                                  if (value.isNotEmpty) {
                                                    return value;
                                                  }
                                                }
                                              }

                                              // Then, try direct record fields
                                              for (final key in keys) {
                                                final value =
                                                    rec[key]
                                                        ?.toString()
                                                        .trim() ??
                                                    '';
                                                if (value.isNotEmpty) {
                                                  return value;
                                                }
                                              }
                                              return defaultValue;
                                            }

                                            final studentName = getFieldValue(
                                              record,
                                              rawData,
                                              [
                                                'F4_PARTY1N',
                                                'studentName',
                                                'student_name',
                                              ],
                                              defaultValue: 'Unknown Student',
                                            );

                                            final className =
                                                getFieldValue(record, rawData, [
                                                  'F4_TXT2',
                                                  'F4_TXT1',
                                                  'className',
                                                  'class',
                                                ], defaultValue: 'N/A');

                                            // Book name extraction
                                            final bookName = getFieldValue(
                                              record,
                                              rawData,
                                              [
                                                '_extracted_book_name',
                                                'F4_PARTYN',
                                                'book_roman_name',
                                                'book_local_name',
                                                'Book Roman Name',
                                                'Book Local Name',
                                                'bookName',
                                                'book_name',
                                                'M1_NAME',
                                                'M1_FNAME',
                                                'M1_LNAME',
                                              ],
                                              defaultValue: 'Unknown Book',
                                            );

                                            getFieldValue(record, rawData, [
                                              'F4_LCODE',
                                              'bookCode',
                                              'book_code',
                                            ], defaultValue: 'N/A');
                                            // Enhanced date extraction and overdue calculation

                                            final dueDate =
                                                record['F4_DATE2'] ??
                                                record['F4_DT2'] ??
                                                rawData?['F4_DT2'] ??
                                                rawData?['F4_DATE2'] ??
                                                record['F4_DATE2'] ??
                                                'N/A';

                                            // Calculate overdue status
                                            bool isOverdue = false;
                                            String formattedDueDate = 'N/A';

                                            if (dueDate != 'N/A' &&
                                                dueDate.isNotEmpty) {
                                              try {
                                                DateTime? dueDateParsed;

                                                // Try different date formats
                                                if (dueDate.contains('-')) {
                                                  dueDateParsed =
                                                      DateTime.tryParse(
                                                        dueDate,
                                                      );
                                                } else if (dueDate.contains(
                                                  '/',
                                                )) {
                                                  final parts = dueDate.split(
                                                    '/',
                                                  );
                                                  if (parts.length == 3) {
                                                    dueDateParsed = DateTime(
                                                      int.parse(
                                                        parts[2],
                                                      ), // year
                                                      int.parse(
                                                        parts[1],
                                                      ), // month
                                                      int.parse(
                                                        parts[0],
                                                      ), // day
                                                    );
                                                  }
                                                }

                                                if (dueDateParsed != null) {
                                                  isOverdue = dueDateParsed
                                                      .isBefore(DateTime.now());

                                                  // Format date in Hindi
                                                  final months = [
                                                    'जनवरी',
                                                    'फरवरी',
                                                    'मार्च',
                                                    'अप्रैल',
                                                    'मई',
                                                    'जून',
                                                    'जुलाई',
                                                    'अगस्त',
                                                    'सितंबर',
                                                    'अक्टूबर',
                                                    'नवंबर',
                                                    'दिसंबर',
                                                  ];
                                                  formattedDueDate =
                                                      'जारी: ${dueDateParsed.day} ${months[dueDateParsed.month - 1]} ${dueDateParsed.year}';
                                                } else {
                                                  formattedDueDate =
                                                      'जारी: $dueDate';
                                                }
                                              } catch (e) {
                                                formattedDueDate =
                                                    'देय तिथि: $dueDate';
                                              }
                                            } else {
                                              formattedDueDate =
                                                  'देय तिथि: अज्ञात';
                                            }

                                            return Padding(
                                              padding: EdgeInsets.only(
                                                bottom: isMobile ? 10 : 12,
                                              ),
                                              child: _buildStudentRecord(
                                                studentName,
                                                'ग्रेड: $className',
                                                bookName,
                                                formattedDueDate,
                                                isOverdue ? 'अतिदेय' : '',
                                                isOverdue
                                                    ? Colors.red[50]!
                                                    : Colors.blue[50]!,
                                                isMobile,
                                                () {
                                                  controller.selectRecordByData(
                                                    record,
                                                  );
                                                },
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailView(
    BuildContext context,
    Map<String, dynamic> record,
    bool isMobile,
    double horizontalPadding,
    double verticalPadding,
  ) {
    // Parse rawData if available for better data extraction
    Map<String, dynamic>? rawData;
    try {
      if (record['rawData'] != null &&
          record['rawData'].toString().isNotEmpty) {
        rawData = jsonDecode(record['rawData']);
      }
      // ignore: empty_catches
    } catch (e) {}

    // Extract data with fallback priority: direct record -> rawData -> 'N/A'
    final studentName =
        record['F4_PARTY1N'] ??
        rawData?['F4_PARTY1N'] ??
        record['studentName'] ??
        rawData?['student_name'] ??
        'N/A';
    final className =
        record['F4_TXT2'] ??
        rawData?['F4_TXT2'] ??
        record['className'] ??
        rawData?['class'] ??
        'N/A';
    final bookName =
        record['F4_PARTYN'] ??
        rawData?['F4_PARTYN'] ??
        record['bookName'] ??
        rawData?['book_name'] ??
        'N/A';
    final bookCode =
        record['F4_PARTY_NO'] ??
        rawData?['F4_PARTY_NO'] ??
        record['F4_PARTY_NO'] ??
        rawData?['F4_PARTY_NO'] ??
        'N/A';
    final dueDate =
        record['F4_DATE2'] ??
        record['F4_DT2'] ??
        rawData?['F4_DT2'] ??
        rawData?['due_date'] ??
        record['dueDate'] ??
        'N/A';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            color: Colors.green,
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => controller.clearRecordSelection(),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'चेक इन विवरण',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Alert Box
                if (record['isOverdue'] == true)
                  Container(
                    padding: EdgeInsets.all(isMobile ? 12 : 14),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_outlined,
                          color: Colors.red,
                          size: isMobile ? 20 : 22,
                        ),
                        SizedBox(width: isMobile ? 10 : 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'यह किताब अतिरेय है',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: isMobile ? 13 : 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'जारी: $dueDate',
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: isMobile ? 12 : 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (record['isOverdue'] == true)
                  SizedBox(height: isMobile ? 16 : 20),
                // Student Info
                Text(
                  'छात्र जानकारी',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: isMobile ? 8 : 10),
                Container(
                  padding: EdgeInsets.all(isMobile ? 12 : 14),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: isMobile ? 40 : 44,
                        height: isMobile ? 40 : 44,
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.person,
                          color: Colors.blue[700],
                          size: isMobile ? 22 : 24,
                        ),
                      ),
                      SizedBox(width: isMobile ? 10 : 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              studentName,
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: isMobile ? 13 : 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'ग्रेड: $className',
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
                ),
                SizedBox(height: isMobile ? 16 : 20),
                // Book Info
                Text(
                  'किताब जानकारी',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: isMobile ? 8 : 10),
                Container(
                  padding: EdgeInsets.all(isMobile ? 12 : 14),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: isMobile ? 40 : 44,
                        height: isMobile ? 40 : 44,
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.menu_book,
                          color: Colors.green[700],
                          size: isMobile ? 22 : 24,
                        ),
                      ),
                      SizedBox(width: isMobile ? 10 : 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bookName,
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: isMobile ? 13 : 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'ID: $bookCode',
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
                ),
                SizedBox(height: isMobile ? 16 : 20),
                // Book Status
                Text(
                  'किताब की स्थिति',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: isMobile ? 8 : 10),
                Column(
                  children: [
                    _buildSelectableStatusItem(
                      Icons.check_circle_outline,
                      'सही स्थिति में वापस',
                      'कोई क्षति नहीं',
                      Colors.green,
                      isMobile,
                      'good',
                      controller,
                    ),
                    SizedBox(height: isMobile ? 8 : 10),
                    _buildSelectableStatusItem(
                      Icons.warning_outlined,
                      'क्षतिग्रस्त',
                      'किताब को नुकसान हुआ है',
                      Colors.orange,
                      isMobile,
                      'damaged',
                      controller,
                    ),
                    SizedBox(height: isMobile ? 8 : 10),
                    _buildSelectableStatusItem(
                      Icons.close_outlined,
                      'खो गई',
                      'किताब वापस नहीं मिली',
                      Colors.red,
                      isMobile,
                      'lost',
                      controller,
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 20 : 24),
                // Checkin Button
                Obx(() {
                  final canProceed = !controller
                      .isLoading
                      .value; // Always allow if not loading

                  return GestureDetector(
                    onTap: canProceed
                        ? () async {
                            final result = await controller.completeCheckin(
                              controller.selectedCondition.value,
                            );

                            if (result['success'] == true) {
                              Get.snackbar(
                                'सफल',
                                result['message'] ?? 'चेक इन सफल रहा',
                                backgroundColor: Colors.green,
                                colorText: Colors.white,
                                duration: const Duration(seconds: 2),
                              );

                              // Clear selection and refresh the list instead of navigating away
                              controller.clearRecordSelection();
                              await controller.refreshCheckedOutBooks();
                            } else {
                              Get.snackbar(
                                'त्रुटि',
                                result['message'] ?? 'चेक इन विफल रहा',
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
                                duration: const Duration(seconds: 3),
                              );
                            }
                          }
                        : null,
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        vertical: isMobile ? 14 : 16,
                      ),
                      decoration: BoxDecoration(
                        color: controller.isLoading.value
                            ? Colors.grey
                            : Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: controller.isLoading.value
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                'चेक इन करें',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isMobile ? 16 : 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  );
                }),
                SizedBox(height: verticalPadding),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectableStatusItem(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    bool isMobile,
    String value,
    CheckinController controller,
  ) {
    return GestureDetector(
      onTap: () {
        controller.selectCondition(value);
      },
      child: Obx(
        () => Container(
          padding: EdgeInsets.all(isMobile ? 12 : 14),
          decoration: BoxDecoration(
            color: controller.selectedCondition.value == value
                ? color.withValues(alpha: 0.15)
                : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: controller.selectedCondition.value == value
                  ? color
                  : color.withValues(alpha: 0.3),
              width: controller.selectedCondition.value == value ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: isMobile ? 20 : 22),
              SizedBox(width: isMobile ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontSize: isMobile ? 13 : 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: color.withValues(alpha: 0.7),
                        fontSize: isMobile ? 11 : 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (controller.selectedCondition.value == value)
                Icon(
                  Icons.check_circle,
                  color: color,
                  size: isMobile ? 20 : 22,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentRecord(
    String studentName,
    String studentClass,
    String bookTitle,
    String dueDate,
    String overdueStatus,
    Color bgColor,
    bool isMobile,
    VoidCallback onTap,
  ) {
    final bool isOverdue = overdueStatus.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isMobile ? 16 : 18),
        margin: EdgeInsets.only(bottom: isMobile ? 8 : 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOverdue ? Colors.red[200]! : Colors.grey[200]!,
            width: isOverdue ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Student Name
                  Text(
                    studentName,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),

                  // Class
                  Text(
                    studentClass,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: isMobile ? 13 : 14,
                    ),
                  ),
                  SizedBox(height: 12),

                  // Book Name
                  Text(
                    bookTitle,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: isMobile ? 14 : 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),

                  // Due Date and Overdue Status
                  Row(
                    children: [
                      Text(
                        dueDate,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: isMobile ? 12 : 13,
                        ),
                      ),
                      if (isOverdue) ...[
                        SizedBox(width: 12),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            overdueStatus,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 10 : 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Arrow Icon
            Icon(
              Icons.chevron_right,
              color: isOverdue ? Colors.red[400] : Colors.grey[400],
              size: isMobile ? 24 : 28,
            ),
          ],
        ),
      ),
    );
  }
}
