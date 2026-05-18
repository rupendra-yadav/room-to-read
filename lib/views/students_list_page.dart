import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:room_to_read/controllers/student_controller.dart';
import 'package:room_to_read/models/student_model.dart';
import 'package:room_to_read/views/student_detail_page.dart';
import 'package:room_to_read/widgets/custom_app_bar.dart';
import 'package:room_to_read/widgets/shimmer_loading.dart';


class StudentsListPage extends GetView<StudentController> {
  const StudentsListPage({Key? key}) : super(key: key);

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

        return Column(
          children: [
            // Header with back button
            Container(
              color: Colors.amber,
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'छात्र प्रबंधन',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isMobile ? 20 : 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'कक्षा और रीडिंग लेवल',
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
                  SizedBox(height: verticalPadding),
                  // Filter Dropdown
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Obx(
                        () => DropdownButton<String>(
                          value: controller.filterType.value,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: ['सभी', ...controller.classes].map((
                            String value,
                          ) {
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
                              controller.setFilterType(newValue);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Search Bar
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: TextField(
                  onChanged: (value) => controller.searchStudents(value),
                  decoration: InputDecoration(
                    hintText: 'नाम या ID से खोजें',
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
            ),
            // Students List
            Expanded(
              child: Obx(
                () {
                  final studentCount = controller.filteredStudents.length;
                  return Column(
                    children: [
                      // Student count header
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'कुल छात्र: $studentCount',
                              style: TextStyle(
                                fontSize: isMobile ? 14 : 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                            if (controller.filterType.value != 'सभी')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber[100],
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.amber[300]!),
                                ),
                                child: Text(
                                  controller.filterType.value,
                                  style: TextStyle(
                                    fontSize: isMobile ? 12 : 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber[900],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: isMobile ? 8 : 10),
                      // Students list
                      Expanded(
                        child: studentCount == 0
                            ? Center(
                                child: Text(
                                  'कोई छात्र नहीं मिला',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: isMobile ? 14 : 16,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: EdgeInsets.symmetric(
                                  horizontal: horizontalPadding,
                                  vertical: verticalPadding,
                                ),
                                itemCount: studentCount,
                                itemBuilder: (context, index) {
                                  final student =
                                      controller.filteredStudents[index];
                                  return _buildStudentCard(
                                    student,
                                    isMobile,
                                    verticalPadding,
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildStudentCard(
    final Student student,
    bool isMobile,
    double spacing,
  ) {
    return GestureDetector(
      onTap: () => Get.to(() => StudentDetailPage(student: student)),
      child: Container(
        margin: EdgeInsets.only(bottom: spacing),
        padding: EdgeInsets.all(isMobile ? 12 : 14),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: Row(
          children: [
            Container(
              width: isMobile ? 48 : 52,
              height: isMobile ? 48 : 52,
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.person,
                color: Colors.blue[700],
                size: isMobile ? 26 : 28,
              ),
            ),
            SizedBox(width: isMobile ? 12 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: isMobile ? 15 : 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'कक्षा: ${student.className} • ID: ${student.id}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: isMobile ? 12 : 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'रीडिंग लेवल',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: isMobile ? 11 : 12,
                  ),
                ),
                Text(
                  '${student.currentLevel}',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(width: isMobile ? 8 : 10),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: isMobile ? 18 : 20,
            ),
          ],
        ),
      ),
    );
  }
}
