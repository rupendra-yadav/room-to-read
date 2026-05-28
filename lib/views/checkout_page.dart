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
                    // Selected Student Display - Show when student is selected
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
                                      SizedBox(width: 6),
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
                                  SizedBox(height: 4),
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
                              onTap: () {
                                controller.clearStudentSelection();
                              },
                              child: Container(
                                padding: EdgeInsets.all(6),
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
                    // Selected Book Display - Show when book is selected
                    Obx(() {
                      if (controller.selectedBook.value == null) {
                        return const SizedBox.shrink();
                      }
                      final book = controller.selectedBook.value!;
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
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.1),
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
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.menu_book,
                                color: Colors.green[700],
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
                                        color: Colors.green[600],
                                        size: isMobile ? 16 : 18,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'चयनित किताब',
                                        style: TextStyle(
                                          color: Colors.green[600],
                                          fontSize: isMobile ? 12 : 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    book.title,
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: isMobile ? 16 : 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${book.author} • कोड: ${book.bookCode} • उपलब्ध: ${book.availableCopies}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: isMobile ? 12 : 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                controller.clearBookSelection();
                              },
                              child: Container(
                                padding: EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.green[700],
                                  size: isMobile ? 16 : 18,
                                ),
                              ),
                            ),
                          ],
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
                          // Step 1: Select Student
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
                          // Students Search Results - Hide when student is selected
                          Obx(() {
                            // Hide student list if a student is already selected
                            if (controller.selectedStudent.value != null) {
                              return const SizedBox.shrink();
                            }

                            // Show message if no class selected
                            if (controller.selectedClass.value.isEmpty) {
                              return Container(
                                padding: EdgeInsets.all(isMobile ? 16 : 20),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue[200]!),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Colors.blue[700],
                                      size: isMobile ? 20 : 22,
                                    ),
                                    SizedBox(width: isMobile ? 10 : 12),
                                    Expanded(
                                      child: Text(
                                        'पहले ग्रेड चुनें',
                                        style: TextStyle(
                                          color: Colors.blue[900],
                                          fontSize: isMobile ? 13 : 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            // ✅ NEW: Show message if class is selected but no search query
                            if (studentController.searchQuery.value.isEmpty) {
                              return Container(
                                padding: EdgeInsets.all(isMobile ? 16 : 20),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green[200]!),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.search,
                                      color: Colors.green[700],
                                      size: isMobile ? 20 : 22,
                                    ),
                                    SizedBox(width: isMobile ? 10 : 12),
                                    Expanded(
                                      child: Text(
                                        'छात्र का नाम या रोल नंबर टाइप करें',
                                        style: TextStyle(
                                          color: Colors.green[900],
                                          fontSize: isMobile ? 13 : 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
                                    studentController.searchQuery.value.isEmpty
                                        ? 'इस ग्रेड में कोई छात्र नहीं मिला'
                                        : 'कोई छात्र नहीं मिला',
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
                                      onTap: () {
                                        controller.selectStudent(student);
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
                          // Step 2: Select Book
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
                            // Show message if no search query
                            if (bookController.searchQuery.value.isEmpty) {
                              return Container(
                                padding: EdgeInsets.all(isMobile ? 16 : 20),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green[200]!),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Colors.green[700],
                                      size: isMobile ? 20 : 22,
                                    ),
                                    SizedBox(width: isMobile ? 10 : 12),
                                    Expanded(
                                      child: Text(
                                        'किताब खोजने के लिए नाम, लेखक या ID टाइप करें',
                                        style: TextStyle(
                                          color: Colors.green[900],
                                          fontSize: isMobile ? 13 : 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
                                    // Check if this book is selected
                                    // Use both bookCode and bookId for comparison, but only if they're not empty
                                    final isSelected =
                                        controller.selectedBook.value != null &&
                                        ((controller
                                                    .selectedBook
                                                    .value
                                                    .bookCode
                                                    .isNotEmpty &&
                                                book.bookCode.isNotEmpty &&
                                                controller
                                                        .selectedBook
                                                        .value
                                                        .bookCode ==
                                                    book.bookCode) ||
                                            (controller
                                                    .selectedBook
                                                    .value
                                                    .bookId
                                                    .isNotEmpty &&
                                                book.bookId.isNotEmpty &&
                                                controller
                                                        .selectedBook
                                                        .value
                                                        .bookId ==
                                                    book.bookId));

                                    return GestureDetector(
                                      onTap: () {
                                        // Debug: Log complete book selection details
                                        print(
                                          '\n📚 ========== BOOK SELECTED ==========',
                                        );
                                        print('   📖 Title: "${book.title}"');
                                        print(
                                          '   📝 Book Name (EN): "${book.bookRomanName}"',
                                        );
                                        print(
                                          '   📝 Book Name (Local): "${book.bookLocalName}"',
                                        );
                                        print(
                                          '   🏷️  BookId (M1_CODE): "${book.bookId}"',
                                        );
                                        print(
                                          '   🏷️  BookCode (M1_NO): "${book.bookCode}"',
                                        );
                                        print('   👤 Author: "${book.author}"');
                                        print(
                                          '   📊 Available Copies: ${book.availableCopies}',
                                        );
                                        print(
                                          '   📚 Total Copies: ${book.totalCopies}',
                                        );
                                        print(
                                          '   ⬆️  Issued Copies: ${book.issuedCopies}',
                                        );
                                        print(
                                          '   🔴 Reading Level: ${book.readingLevel}',
                                        );
                                        print(
                                          '   ✅ Is Active: ${book.isActive}',
                                        );
                                        print(
                                          '   🎓 Program Code: "${book.programCode}"',
                                        );
                                        print(
                                          '   Currently Selected: ${controller.selectedBook.value?.title ?? "None"}',
                                        );
                                        print(
                                          '=====================================\n',
                                        );

                                        // Check if this book is already selected
                                        if (controller.selectedBook.value !=
                                                null &&
                                            (controller
                                                        .selectedBook
                                                        .value
                                                        .bookCode ==
                                                    book.bookCode ||
                                                controller
                                                        .selectedBook
                                                        .value
                                                        .bookId ==
                                                    book.bookId)) {
                                          print('⚠️ Book already selected');
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

                                        // Only allow selection if book is available
                                        // Only allow selection if book is available
                                        if (book.availableCopies > 0) {
                                          print(
                                            '✅ Selecting book: ${book.title}',
                                          );
                                          controller.selectBook(book);
                                          // Clear search field and close results dropdown
                                          controller.bookSearchController
                                              .clear();
                                          bookController.searchBooks('');
                                        } else {
                                          print(
                                            '❌ Book not available: ${book.availableCopies} copies',
                                          );
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
                                                    book.title,
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
                                                    book.author,
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: isMobile
                                                          ? 12
                                                          : 13,
                                                    ),
                                                  ),
                                                  if (book.bookId.isNotEmpty)
                                                    // Text(
                                                    //   'Book ID: ${book.bookId}',
                                                    //   style: TextStyle(
                                                    //     color: Colors.grey[600],
                                                    //     fontSize: isMobile
                                                    //         ? 11
                                                    //         : 12,
                                                    //   ),
                                                    // ),
                                                    // Text(
                                                    //   'Code: ${book.bookCode}',
                                                    //   style: TextStyle(
                                                    //     color: Colors.grey[600],
                                                    //     fontSize: isMobile
                                                    //         ? 11
                                                    //         : 12,
                                                    //   ),
                                                    // ),
                                                    // Copy information
                                                    // Text(
                                                    //   'कुल: ${book.totalCopies} | उपलब्ध: ${book.availableCopies} | जारी: ${book.issuedCopies}',
                                                    //   style: TextStyle(
                                                    //     color: Colors.grey[700],
                                                    //     fontSize: isMobile
                                                    //         ? 11
                                                    //         : 12,
                                                    //     fontWeight: FontWeight.w500,
                                                    //   ),
                                                    // ),
                                                    // Availability indicator
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
                                                        SizedBox(width: 4),
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
                          // Summary Section - Only show when both selected
                          Obx(() {
                            if (controller.selectedStudent.value == null ||
                                controller.selectedBook.value == null) {
                              return const SizedBox.shrink();
                            }
                            final student = controller.selectedStudent.value;
                            final book = controller.selectedBook.value;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Selected Student Card
                                // Container(
                                //   padding: EdgeInsets.all(isMobile ? 12 : 14),
                                //   decoration: BoxDecoration(
                                //     color: Colors.blue[50],
                                //     borderRadius: BorderRadius.circular(8),
                                //     border: Border.all(
                                //       color: Colors.blue[200]!,
                                //     ),
                                //   ),
                                //   child: Row(
                                //     children: [
                                //       Container(
                                //         width: isMobile ? 44 : 48,
                                //         height: isMobile ? 44 : 48,
                                //         decoration: BoxDecoration(
                                //           color: Colors.blue[100],
                                //           borderRadius: BorderRadius.circular(
                                //             8,
                                //           ),
                                //         ),
                                //         child: Icon(
                                //           Icons.person,
                                //           color: Colors.blue[700],
                                //           size: isMobile ? 24 : 26,
                                //         ),
                                //       ),
                                //       SizedBox(width: isMobile ? 10 : 12),
                                //       Expanded(
                                //         child: Column(
                                //           crossAxisAlignment:
                                //               CrossAxisAlignment.start,
                                //           children: [
                                //             Text(
                                //               student.name,
                                //               style: TextStyle(
                                //                 color: Colors.black,
                                //                 fontSize: isMobile ? 14 : 15,
                                //                 fontWeight: FontWeight.bold,
                                //               ),
                                //             ),
                                //             Text(
                                //               'ID: ${student.id} • कक्षा: ${student.className}',
                                //               style: TextStyle(
                                //                 color: Colors.grey[600],
                                //                 fontSize: isMobile ? 12 : 13,
                                //               ),
                                //             ),
                                //           ],
                                //         ),
                                //       ),
                                //     ],
                                //   ),
                                // ),
                                // SizedBox(height: isMobile ? 12 : 14),
                                // // Selected Book Card
                                // Container(
                                //   padding: EdgeInsets.all(isMobile ? 12 : 14),
                                //   decoration: BoxDecoration(
                                //     color: Colors.green[50],
                                //     borderRadius: BorderRadius.circular(8),
                                //     border: Border.all(
                                //       color: Colors.green[200]!,
                                //     ),
                                //   ),
                                //   child: Row(
                                //     children: [
                                //       Container(
                                //         width: isMobile ? 44 : 48,
                                //         height: isMobile ? 44 : 48,
                                //         decoration: BoxDecoration(
                                //           color: Colors.green[100],
                                //           borderRadius: BorderRadius.circular(
                                //             8,
                                //           ),
                                //         ),
                                //         child: Icon(
                                //           Icons.menu_book,
                                //           color: Colors.green[700],
                                //           size: isMobile ? 24 : 26,
                                //         ),
                                //       ),
                                //       SizedBox(width: isMobile ? 10 : 12),
                                //       Expanded(
                                //         child: Column(
                                //           crossAxisAlignment:
                                //               CrossAxisAlignment.start,
                                //           children: [
                                //             Text(
                                //               book.title,
                                //               style: TextStyle(
                                //                 color: Colors.black,
                                //                 fontSize: isMobile ? 14 : 15,
                                //                 fontWeight: FontWeight.bold,
                                //               ),
                                //             ),
                                //             Text(
                                //               book.author,
                                //               style: TextStyle(
                                //                 color: Colors.grey[600],
                                //                 fontSize: isMobile ? 12 : 13,
                                //               ),
                                //             ),
                                //           ],
                                //         ),
                                //       ),
                                //     ],
                                //   ),
                                // ),
                                SizedBox(height: isMobile ? 16 : 20),
                                // Summary Box
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
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'कुल पुस्तकें ',
                                              style: TextStyle(
                                                color: Colors.orange,
                                                fontSize: isMobile ? 12 : 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              'बुक निर्गत पुस्तकें',
                                              style: TextStyle(
                                                color: Colors.orange,
                                                fontSize: isMobile ? 11 : 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${book.totalCopies}',
                                            style: TextStyle(
                                              color: Colors.orange,
                                              fontSize: isMobile ? 13 : 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            'उपलब्ध: ${book.availableCopies}',
                                            style: TextStyle(
                                              color: Colors.orange,
                                              fontSize: isMobile ? 11 : 12,
                                            ),
                                          ),
                                        ],
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
                                      Divider(
                                        color: Colors.grey[300],
                                        height: isMobile ? 12 : 14,
                                      ),
                                      _buildSummaryRow(
                                        'किताब',
                                        book.title,
                                        isMobile,
                                      ),

                                      Divider(
                                        color: Colors.grey[300],
                                        height: isMobile ? 12 : 14,
                                      ),
                                      _buildSummaryRow(
                                        'शीर्ष प्रतियां',
                                        '${book.availableCopies - 1}',
                                        isMobile,
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: isMobile ? 20 : 24),
                                // Checkout Button
                                Obx(() {
                                  final book = controller.selectedBook.value;
                                  final isBookUnavailable =
                                      book != null && book.availableCopies <= 0;
                                  final isDisabled =
                                      controller.isLoading.value ||
                                      isBookUnavailable;

                                  return Column(
                                    children: [
                                      // Show warning if book is unavailable
                                      if (isBookUnavailable)
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
                                                  'चयनित किताब उपलब्ध नहीं है। कृपया दूसरी किताब चुनें।',
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

                                                  // Navigate back to home with a fresh start
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
                                                    isBookUnavailable
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
        Text(
          value,
          style: TextStyle(
            color: Colors.black,
            fontSize: isMobile ? 13 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
