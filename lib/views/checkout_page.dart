import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:room_to_read/controllers/book_controller.dart';
import 'package:room_to_read/controllers/checkout_controller.dart';
import 'package:room_to_read/controllers/student_controller.dart';
import 'package:room_to_read/models/grade_model.dart';
import 'package:room_to_read/widgets/custom_app_bar.dart';
import 'package:room_to_read/widgets/offline_status_widget.dart';

class CheckoutPage extends GetView<CheckoutController> {
  const CheckoutPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final horizontalPadding = isMobile ? 16.0 : 24.0;
    final verticalPadding = isMobile ? 16.0 : 20.0;

    final studentController = Get.find<StudentController>();
    final bookController = Get.find<BookController>();

    return SafeArea(
      child: Scaffold(
        appBar: CustomAppBar(title: 'Room To Read'),
        body: Column(
          children: [
            // Offline Status Widget
            OfflineStatusWidget(),
            // Main Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      color: Colors.blue,
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
                                'चेक आउट',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isMobile ? 20 : 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: verticalPadding),
                          Container(
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
                                  value: controller.classes.firstWhereOrNull(
                                    (g) =>
                                        g.name ==
                                        controller.selectedClass.value,
                                  ),
                                  hint: Text(
                                    'ग्रेड चुनें',
                                    style: TextStyle(
                                      fontSize: isMobile ? 14 : 15,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  isExpanded: true,
                                  underline: const SizedBox(),
                                  items: controller.classes.map((Grade grade) {
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
                                      studentController.setClassFilter(
                                        newValue.name,
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Selected Student Display ──────────────────────────────
                    Obx(() {
                      if (controller.selectedStudent.value == null) {
                        return const SizedBox.shrink();
                      }
                      final student = controller.selectedStudent.value!;
                      return Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: isMobile ? 8 : 10,
                        ),
                        padding: EdgeInsets.all(isMobile ? 12 : 14),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[300]!),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: isMobile ? 48 : 52,
                              height: isMobile ? 48 : 52,
                              decoration: BoxDecoration(
                                color: Colors.blue[100],
                                borderRadius: BorderRadius.circular(10),
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
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.blue[600],
                                        size: isMobile ? 16 : 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'चयनित छात्र',
                                        style: TextStyle(
                                          color: Colors.blue[600],
                                          fontSize: isMobile ? 12 : 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    student.name,
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: isMobile ? 16 : 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'ID: ${student.id} • ग्रेड: ${student.className} • रीडिंग लेवल: ${student.readingLevel}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: isMobile ? 12 : 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => controller.clearStudentSelection(),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.blue[100],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.blue[700],
                                  size: isMobile ? 16 : 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    // ── Selected Books Display (multi-select list) ────────────
                    Obx(() {
                      if (controller.selectedBooks.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: isMobile ? 8 : 10,
                        ),
                        padding: EdgeInsets.all(isMobile ? 12 : 14),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green[300]!),
                        ),
                        child: Column(
                          children: controller.selectedBooks.map((book) {
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                Icons.menu_book,
                                color: Colors.green[700],
                              ),
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    book.bookName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (book.bookRomanName.isNotEmpty)
                                    Text(
                                      book.bookRomanName,
                                      style: const TextStyle(
                                        fontStyle: FontStyle.italic,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  if (book.bookLocalName.isNotEmpty &&
                                      book.bookLocalName != book.bookName)
                                    Text(
                                      book.bookLocalName,
                                      style: const TextStyle(fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                '${book.author} • कोड: ${book.bookCode} • उपलब्ध: ${book.availableCopies}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => controller.removeBook(book),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    }),

                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: verticalPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Step 1: Select Student ──────────────────────────
                          _buildStepHeader('1', 'छात्र का चयन करें', isMobile),
                          SizedBox(height: isMobile ? 10 : 12),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: TextField(
                              controller: controller.studentSearchController,
                              onChanged: (value) {
                                studentController.searchStudents(value);
                              },
                              decoration: InputDecoration(
                                hintText: 'नाम या रोल नंबर से खोजें',
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
                          SizedBox(height: isMobile ? 12 : 14),

                          // Students Search Results
                          Obx(() {
                            if (controller.selectedStudent.value != null) {
                              return const SizedBox.shrink();
                            }
                            if (controller.selectedClass.value.isEmpty) {
                              return _buildInfoBox(
                                icon: Icons.info_outline,
                                color: Colors.blue,
                                text: 'पहले ग्रेड चुनें',
                                isMobile: isMobile,
                              );
                            }
                            if (studentController.searchQuery.value.isEmpty) {
                              return _buildInfoBox(
                                icon: Icons.search,
                                color: Colors.green,
                                text: 'छात्र का नाम या रोल नंबर टाइप करें',
                                isMobile: isMobile,
                              );
                            }
                            if (studentController.filteredStudents.isEmpty) {
                              return Container(
                                padding: EdgeInsets.all(isMobile ? 16 : 20),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Center(
                                  child: Text(
                                    'कोई छात्र नहीं मिला',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: isMobile ? 13 : 14,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              constraints: BoxConstraints(
                                maxHeight: isMobile ? 300 : 400,
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                physics: const AlwaysScrollableScrollPhysics(),
                                itemCount:
                                    studentController.filteredStudents.length,
                                itemBuilder: (context, index) {
                                  final student =
                                      studentController.filteredStudents[index];
                                  return Obx(() {
                                    final isSelected =
                                        controller.selectedStudent.value !=
                                            null &&
                                        controller.selectedStudent.value.id ==
                                            student.id;
                                    return GestureDetector(
                                      onTap: () =>
                                          controller.selectStudent(student),
                                      child: Container(
                                        padding: EdgeInsets.all(
                                          isMobile ? 12 : 14,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Colors.grey[200]!,
                                            ),
                                            left: BorderSide(
                                              color: isSelected
                                                  ? Colors.blue
                                                  : Colors.transparent,
                                              width: isSelected ? 4 : 0,
                                            ),
                                          ),
                                          color: isSelected
                                              ? Colors.blue[50]
                                              : Colors.white,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: isMobile ? 40 : 44,
                                              height: isMobile ? 40 : 44,
                                              decoration: BoxDecoration(
                                                color: Colors.blue[100],
                                                borderRadius:
                                                    BorderRadius.circular(8),
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
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    student.name,
                                                    style: TextStyle(
                                                      color: Colors.black,
                                                      fontSize: isMobile
                                                          ? 14
                                                          : 15,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  Text(
                                                    'ID: ${student.id} • ग्रेड: ${student.className}',
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: isMobile
                                                          ? 12
                                                          : 13,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (isSelected)
                                              Icon(
                                                Icons.check_circle,
                                                color: Colors.blue,
                                                size: isMobile ? 20 : 22,
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  });
                                },
                              ),
                            );
                          }),

                          SizedBox(height: isMobile ? 20 : 24),

                          // ── Step 2: Select Book ─────────────────────────────
                          _buildStepHeader('2', 'किताब का चयन करें', isMobile),
                          SizedBox(height: isMobile ? 10 : 12),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: TextField(
                              controller: controller.bookSearchController,
                              onChanged: (value) =>
                                  bookController.searchBooks(value),
                              decoration: InputDecoration(
                                hintText: 'किताब का नाम, लेखक, या ID खोजें',
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
                          SizedBox(height: isMobile ? 12 : 14),

                          // Books Search Results
                          Obx(() {
                            if (bookController.searchQuery.value.isEmpty) {
                              return _buildInfoBox(
                                icon: Icons.info_outline,
                                color: Colors.green,
                                text:
                                    'किताब खोजने के लिए नाम, लेखक या ID टाइप करें',
                                isMobile: isMobile,
                              );
                            }
                            if (bookController.filteredBooks.isEmpty) {
                              return Container(
                                padding: EdgeInsets.all(isMobile ? 16 : 20),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Center(
                                  child: Text(
                                    'कोई किताब नहीं मिली',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: isMobile ? 13 : 14,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              constraints: BoxConstraints(
                                maxHeight: isMobile ? 300 : 400,
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                physics: const AlwaysScrollableScrollPhysics(),
                                itemCount: bookController.filteredBooks.length,
                                itemBuilder: (context, index) {
                                  final book =
                                      bookController.filteredBooks[index];
                                  return Obx(() {
                                    // ✅ FIX: Check against selectedBooks list, not selectedBook
                                    final isSelected = controller.selectedBooks
                                        .any(
                                          (b) =>
                                              (b.bookCode.isNotEmpty &&
                                                  book.bookCode.isNotEmpty &&
                                                  b.bookCode ==
                                                      book.bookCode) ||
                                              (b.bookId.isNotEmpty &&
                                                  book.bookId.isNotEmpty &&
                                                  b.bookId == book.bookId),
                                        );

                                    return GestureDetector(
                                      onTap: () {
                                        // ✅ FIX: Check against selectedBooks list
                                        if (isSelected) {
                                          Get.snackbar(
                                            'पहले से चयनित',
                                            'यह किताब पहले से चयनित है।',
                                            backgroundColor: Colors.blue,
                                            colorText: Colors.white,
                                            duration: const Duration(
                                              seconds: 2,
                                            ),
                                          );
                                          return;
                                        }
                                        if (book.availableCopies > 0) {
                                          controller.selectBook(book);
                                          controller.bookSearchController
                                              .clear();
                                          bookController.searchBooks('');
                                        } else {
                                          Get.snackbar(
                                            'उपलब्ध नहीं',
                                            'यह किताब उपलब्ध नहीं है। उपलब्ध प्रतियां: ${book.availableCopies}',
                                            backgroundColor: Colors.red,
                                            colorText: Colors.white,
                                            duration: const Duration(
                                              seconds: 2,
                                            ),
                                          );
                                        }
                                      },
                                      child: Container(
                                        padding: EdgeInsets.all(
                                          isMobile ? 12 : 14,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Colors.grey[200]!,
                                            ),
                                            left: BorderSide(
                                              color: isSelected
                                                  ? Colors.green
                                                  : Colors.transparent,
                                              width: isSelected ? 4 : 0,
                                            ),
                                          ),
                                          color: isSelected
                                              ? Colors.green[50]
                                              : book.availableCopies <= 0
                                              ? Colors.red[50]
                                              : Colors.white,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: isMobile ? 40 : 44,
                                              height: isMobile ? 40 : 44,
                                              decoration: BoxDecoration(
                                                color: book.availableCopies <= 0
                                                    ? Colors.red[100]
                                                    : Colors.green[100],
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.menu_book,
                                                color: book.availableCopies <= 0
                                                    ? Colors.red[700]
                                                    : Colors.green[700],
                                                size: isMobile ? 22 : 24,
                                              ),
                                            ),
                                            SizedBox(width: isMobile ? 10 : 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    book.bookName,
                                                    style: TextStyle(
                                                      color: Colors.black,
                                                      fontSize: isMobile
                                                          ? 14
                                                          : 15,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  if (book.bookRomanName
                                                      .isNotEmpty)
                                                    Text(
                                                      book.bookRomanName,
                                                      style: TextStyle(
                                                        color:
                                                            Colors.grey[700],
                                                        fontSize: isMobile
                                                            ? 12
                                                            : 13,
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow
                                                          .ellipsis,
                                                    ),
                                                  if (book.bookLocalName
                                                          .isNotEmpty &&
                                                      book.bookLocalName !=
                                                          book.bookName)
                                                    Text(
                                                      book.bookLocalName,
                                                      style: TextStyle(
                                                        color:
                                                            Colors.grey[500],
                                                        fontSize: isMobile
                                                            ? 11
                                                            : 12,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow
                                                          .ellipsis,
                                                    ),
                                                  Text(
                                                    book.author,
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: isMobile
                                                          ? 12
                                                          : 13,
                                                    ),
                                                  ),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        book.availableCopies <=
                                                                0
                                                            ? Icons
                                                                  .error_outline
                                                            : Icons
                                                                  .check_circle_outline,
                                                        color:
                                                            book.availableCopies <=
                                                                0
                                                            ? Colors.red
                                                            : Colors.green,
                                                        size: isMobile
                                                            ? 14
                                                            : 16,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        book.availableCopies <=
                                                                0
                                                            ? 'उपलब्ध नहीं'
                                                            : 'उपलब्ध: ${book.availableCopies}',
                                                        style: TextStyle(
                                                          color:
                                                              book.availableCopies <=
                                                                  0
                                                              ? Colors.red
                                                              : Colors.green,
                                                          fontSize: isMobile
                                                              ? 10
                                                              : 11,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (isSelected)
                                              Icon(
                                                Icons.check_circle,
                                                color: Colors.green,
                                                size: isMobile ? 20 : 22,
                                              ),
                                            if (book.availableCopies <= 0 &&
                                                !isSelected)
                                              Icon(
                                                Icons.block,
                                                color: Colors.red,
                                                size: isMobile ? 20 : 22,
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  });
                                },
                              ),
                            );
                          }),

                          SizedBox(height: isMobile ? 20 : 24),

                          // ── Summary Section ─────────────────────────────────
                          // Show only when both student and at least one book are selected
                          Obx(() {
                            if (controller.selectedStudent.value == null ||
                                controller.selectedBooks.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            final student = controller.selectedStudent.value!;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ✅ FIX: Info box now summarises ALL selected books
                                Container(
                                  padding: EdgeInsets.all(isMobile ? 14 : 16),
                                  decoration: BoxDecoration(
                                    color: Colors.yellow[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.yellow[300]!,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: isMobile ? 40 : 44,
                                        height: isMobile ? 40 : 44,
                                        decoration: BoxDecoration(
                                          color: Colors.yellow[200],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.info_outline,
                                          color: Colors.orange,
                                          size: isMobile ? 22 : 24,
                                        ),
                                      ),
                                      SizedBox(width: isMobile ? 10 : 12),
                                      Expanded(
                                        child: Text(
                                          'चयनित किताबें: ${controller.selectedBooks.length}',
                                          style: TextStyle(
                                            color: Colors.orange,
                                            fontSize: isMobile ? 13 : 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: isMobile ? 16 : 20),

                                // Summary Details
                                Text(
                                  'सारांश',
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
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      _buildSummaryRow(
                                        'नाम',
                                        student.name,
                                        isMobile,
                                      ),
                                      Divider(
                                        color: Colors.grey[300],
                                        height: isMobile ? 12 : 14,
                                      ),
                                      _buildSummaryRow(
                                        'ग्रेड',
                                        controller.selectedClass.value,
                                        isMobile,
                                      ),
                                      Divider(
                                        color: Colors.grey[300],
                                        height: isMobile ? 12 : 14,
                                      ),
                                      _buildSummaryRow(
                                        'रीडिंग लेवल',
                                        student.readingLevel.toString(),
                                        isMobile,
                                      ),
                                      // ✅ FIX: Show a row for EACH selected book
                                      ...controller.selectedBooks
                                          .asMap()
                                          .entries
                                          .map((entry) {
                                            final idx = entry.key + 1;
                                            final b = entry.value;
                                            return Column(
                                              children: [
                                                Divider(
                                                  color: Colors.grey[300],
                                                  height: isMobile ? 12 : 14,
                                                ),
                                                _buildSummaryRow(
                                                  'किताब $idx',
                                                  b.title,
                                                  isMobile,
                                                ),
                                                Divider(
                                                  color: Colors.grey[300],
                                                  height: isMobile ? 12 : 14,
                                                ),
                                                _buildSummaryRow(
                                                  'उपलब्ध प्रतियां',
                                                  '${b.availableCopies}',
                                                  isMobile,
                                                ),
                                              ],
                                            );
                                          })
                                          .toList(),
                                    ],
                                  ),
                                ),

                                SizedBox(height: isMobile ? 20 : 24),

                                // ── Checkout Button ─────────────────────────
                                Obx(() {
                                  // ✅ FIX: Disable if ANY selected book is unavailable
                                  final hasUnavailableBook = controller
                                      .selectedBooks
                                      .any((b) => b.availableCopies <= 0);
                                  final isDisabled =
                                      controller.isLoading.value ||
                                      hasUnavailableBook;

                                  return Column(
                                    children: [
                                      if (hasUnavailableBook)
                                        Container(
                                          padding: EdgeInsets.all(
                                            isMobile ? 12 : 14,
                                          ),
                                          margin: EdgeInsets.only(
                                            bottom: isMobile ? 12 : 16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red[50],
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.red[200]!,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.warning_outlined,
                                                color: Colors.red,
                                                size: isMobile ? 20 : 22,
                                              ),
                                              SizedBox(
                                                width: isMobile ? 10 : 12,
                                              ),
                                              Expanded(
                                                child: Text(
                                                  'एक या अधिक चयनित किताबें उपलब्ध नहीं हैं। कृपया उन्हें हटाएं।',
                                                  style: TextStyle(
                                                    color: Colors.red[700],
                                                    fontSize: isMobile
                                                        ? 12
                                                        : 13,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      GestureDetector(
                                        onTap: isDisabled
                                            ? null
                                            : () async {
                                                final result = await controller
                                                    .completeCheckout();
                                                if (result['success'] == true) {
                                                  Get.snackbar(
                                                    'सफल',
                                                    result['message'] ??
                                                        'चेक आउट सफल रहा',
                                                    backgroundColor:
                                                        Colors.green,
                                                    colorText: Colors.white,
                                                    duration: const Duration(
                                                      seconds: 2,
                                                    ),
                                                  );
                                                  Get.offAndToNamed('/');
                                                } else {
                                                  Get.snackbar(
                                                    'त्रुटि',
                                                    result['message'] ??
                                                        'चेक आउट विफल रहा',
                                                    backgroundColor: Colors.red,
                                                    colorText: Colors.white,
                                                    duration: const Duration(
                                                      seconds: 3,
                                                    ),
                                                  );
                                                }
                                              },
                                        child: Container(
                                          width: double.infinity,
                                          padding: EdgeInsets.symmetric(
                                            vertical: isMobile ? 14 : 16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isDisabled
                                                ? Colors.grey
                                                : Colors.blue,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Center(
                                            child: controller.isLoading.value
                                                ? const SizedBox(
                                                    height: 20,
                                                    width: 20,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                            Color
                                                          >(Colors.white),
                                                    ),
                                                  )
                                                : Text(
                                                    hasUnavailableBook
                                                        ? 'किताब उपलब्ध नहीं'
                                                        : 'चेक आउट करें',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: isMobile
                                                          ? 16
                                                          : 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }),

                                SizedBox(height: verticalPadding),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _buildInfoBox({
    required IconData icon,
    required MaterialColor color,
    required String text,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color[200]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: color[700], size: isMobile ? 20 : 22),
          SizedBox(width: isMobile ? 10 : 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color[900], fontSize: isMobile ? 13 : 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepHeader(String step, String title, bool isMobile) {
    return Row(
      children: [
        Container(
          width: isMobile ? 28 : 32,
          height: isMobile ? 28 : 32,
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Center(
            child: Text(
              step,
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(width: isMobile ? 10 : 12),
        Text(
          title,
          style: TextStyle(
            color: Colors.black,
            fontSize: isMobile ? 15 : 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: isMobile ? 13 : 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: Colors.black,
              fontSize: isMobile ? 13 : 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
