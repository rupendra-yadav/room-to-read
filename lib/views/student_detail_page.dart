import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:room_to_read/controllers/student_detail_controller.dart';
import 'package:room_to_read/models/student_model.dart';
import 'package:room_to_read/services/api_service.dart';
import 'package:room_to_read/views/student_book_history_page.dart';
import 'package:room_to_read/views/update_reading_level_page.dart';
import 'package:room_to_read/widgets/custom_app_bar.dart';
import 'package:room_to_read/widgets/shimmer_loading.dart';

class StudentDetailPage extends StatefulWidget {
  final Student student;

  const StudentDetailPage({Key? key, required this.student}) : super(key: key);

  @override
  State<StudentDetailPage> createState() => _StudentDetailPageState();
}

class _StudentDetailPageState extends State<StudentDetailPage> {
  late StudentDetailController controller;

  @override
  void initState() {
    super.initState();
    // Ensure ApiService is available
    if (!Get.isRegistered<ApiService>()) {
      Get.lazyPut<ApiService>(() => ApiService());
    }
    controller = Get.put(StudentDetailController());
    // Use M1_CODE for the API call
    controller.fetchStudentDetails(widget.student.code);
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
        if (controller.isLoading.value) {
          return ListView.builder(
            itemCount: 3,
            itemBuilder: (context, index) => const StudentCardShimmer(),
          );
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with back button
              Container(
                color: Colors.amber,
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
                            'छात्र विवरण',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 18 : 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'पूर्ण जानकारी',
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
              // Student Info Card
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: Text(
                  'छात्र जानकारी',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Container(
                  padding: EdgeInsets.all(isMobile ? 14 : 16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: isMobile ? 50 : 56,
                        height: isMobile ? 50 : 56,
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.person,
                          color: Colors.blue[700],
                          size: isMobile ? 28 : 32,
                        ),
                      ),
                      SizedBox(width: isMobile ? 12 : 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.student.name,
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: isMobile ? 16 : 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'ID: ${widget.student.id} • कक्षा: ${widget.student.className}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: isMobile ? 13 : 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: isMobile ? 20 : 24),
              // Reading Level Section Title
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Text(
                  'रीडिंग लेवल',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              SizedBox(height: isMobile ? 12 : 14),
              // Reading Level Section
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Container(
                  padding: EdgeInsets.all(isMobile ? 14 : 16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'वर्तमान लेवल',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: isMobile ? 12 : 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: isMobile ? 4 : 6),
                          Text(
                            widget.student.readingLevel.toString(),
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: isMobile ? 28 : 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'अंतिम प्रयुक्तकरण',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: isMobile ? 12 : 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: isMobile ? 4 : 6),
                          Text(
                            '${widget.student.lastUpdated.day} जनवरी ${widget.student.lastUpdated.year}',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: isMobile ? 13 : 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: isMobile ? 12 : 14),
              // Edit Reading Level Button
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: GestureDetector(
                  onTap: () async {
                    final result = await Get.to(
                      () => UpdateReadingLevelPage(student: widget.student),
                    );
                    if (result != null && result is int) {
                      print(
                        '🔍 Received reading level update: $result (type: ${result.runtimeType})',
                      );

                      // Call hybrid API to update reading level (works online/offline)
                      try {
                        final response = await controller.apiService
                            .updateReadingLevel(widget.student.code, result);

                        print('🔍 API Response: $response');

                        // Check if response indicates success
                        if (response['success'] == true) {
                          final previousLevel = widget.student.readingLevel;

                          // Update student object with data from API response if available
                          if (response['data'] != null &&
                              response['data'] is Map &&
                              (response['data'] as Map).isNotEmpty) {
                            final apiData =
                                response['data'] as Map<String, dynamic>;

                            // Update with actual API response data
                            final newLevel =
                                int.tryParse(
                                  apiData['M1_TXT2']?.toString() ?? '',
                                ) ??
                                result;
                            final actualPreviousLevel =
                                int.tryParse(
                                  apiData['M1_TXT1']?.toString() ?? '',
                                ) ??
                                previousLevel;

                            widget.student.readingLevel = newLevel;
                            widget.student.currentLevel = newLevel;
                            widget.student.previousLevel = actualPreviousLevel;

                            print(
                              '✅ Updated student from API data: previous=$actualPreviousLevel, current=$newLevel',
                            );
                          } else {
                            // API update successful but no data returned - update manually
                            // This is common when API only confirms the update without returning full data
                            final newLevel = result;
                            widget.student.previousLevel =
                                previousLevel; // Store the old level as previous
                            widget.student.readingLevel = newLevel;
                            widget.student.currentLevel = newLevel;

                            print(
                              '✅ Updated student manually after successful API call: previous=$previousLevel, current=$newLevel',
                            );
                          }

                          final currentLevel = widget.student.readingLevel;
                          final prevLevel = widget.student.previousLevel;

                          // Show appropriate success message
                          final message = response['offline'] == true
                              ? 'रीडिंग लेवल ऑफलाइन अपडेट: $prevLevel → $currentLevel (सिंक के लिए इंतजार में)'
                              : 'रीडिंग लेवल अपडेट हो गया: $prevLevel → $currentLevel';

                          Get.snackbar(
                            'सफल',
                            message,
                            backgroundColor: Colors.green,
                            colorText: Colors.white,
                            duration: const Duration(seconds: 3),
                          );

                          // Refresh UI
                          setState(() {});
                        } else {
                          Get.snackbar(
                            'त्रुटि',
                            response['message'] ??
                                'रीडिंग लेवल अपडेट करने में विफल',
                            backgroundColor: Colors.red,
                            colorText: Colors.white,
                            duration: const Duration(seconds: 3),
                          );
                        }
                      } catch (e) {
                        Get.snackbar(
                          'त्रुटि',
                          'रीडिंग लेवल अपडेट करने में विफल: $e',
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                          duration: const Duration(seconds: 3),
                        );
                      }
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 14 : 16,
                      vertical: isMobile ? 12 : 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[300]!, width: 2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.edit,
                          color: Colors.blue[700],
                          size: isMobile ? 18 : 20,
                        ),
                        SizedBox(width: isMobile ? 8 : 10),
                        Text(
                          'रीडिंग लेवल बदलें',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: isMobile ? 15 : 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: isMobile ? 12 : 14),
              // Books Section
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: GestureDetector(
                  onTap: () {
                    Get.to(
                      () => StudentBookHistoryPage(student: widget.student),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.all(isMobile ? 14 : 16),
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple[200]!),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: isMobile ? 48 : 52,
                          height: isMobile ? 48 : 52,
                          decoration: BoxDecoration(
                            color: Colors.purple[300],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.history,
                            color: Colors.white,
                            size: isMobile ? 26 : 28,
                          ),
                        ),
                        SizedBox(width: isMobile ? 12 : 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'पूरी CICO हिंदी रेखा',
                                style: TextStyle(
                                  color: Colors.purple[700],
                                  fontSize: isMobile ? 15 : 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'सभी किताबों का रिकॉर्ड',
                                style: TextStyle(
                                  color: Colors.purple[600],
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
              ),
              SizedBox(height: verticalPadding),
            ],
          ),
        );
      }),
    );
  }
}
