import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:room_to_read/controllers/book_detail_controller.dart';
import 'package:room_to_read/models/book_model.dart' as book_model;
import 'package:room_to_read/widgets/custom_app_bar.dart';
import 'package:room_to_read/widgets/shimmer_loading.dart';

class BookDetailPage extends StatefulWidget {
  final book_model.Book book;

  const BookDetailPage({Key? key, required this.book}) : super(key: key);

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  late BookDetailController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(BookDetailController());
    controller.fetchBookDetails(widget.book.bookId);
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

        // Get fresh book details from controller, fallback to widget.book
        final bookData = controller.bookDetails.value;
        final totalCopies = bookData != null
            ? (int.tryParse(bookData['total_copy']?.toString() ?? '0') ??
                  widget.book.totalCopies)
            : widget.book.totalCopies;
        final availableCopies = bookData != null
            ? (int.tryParse(bookData['avail_copy']?.toString() ?? '0') ??
                  widget.book.availableCopies)
            : widget.book.availableCopies;
        final issuedCopies = bookData != null
            ? (int.tryParse(bookData['issue_copy']?.toString() ?? '0') ??
                  widget.book.issuedCopies)
            : widget.book.issuedCopies;
        final damagedCopies = bookData != null
            ? (int.tryParse(bookData['damage_copy']?.toString() ?? '0') ??
                  widget.book.damagedCopies)
            : widget.book.damagedCopies;
        final lostCopies = bookData != null
            ? (int.tryParse(bookData['lost_copy']?.toString() ?? '0') ??
                  widget.book.lostCopies)
            : widget.book.lostCopies;

        // Simple logic: Green if available, Red if not
        final bool isAvailable = availableCopies > 0;
        final Color statusColor = isAvailable ? Colors.green : Colors.red;
        final Color statusBgColor = isAvailable
            ? Colors.green[50]!
            : Colors.red[50]!;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with back button
              Container(
                color: statusColor,
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
                            'किताब विवरण',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 18 : 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'इंटेंटरी जानकारी',
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
              // Book Info Card
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: Container(
                  padding: EdgeInsets.all(isMobile ? 14 : 16),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: isMobile ? 50 : 56,
                        height: isMobile ? 50 : 56,
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.menu_book,
                          color: statusColor,
                          size: isMobile ? 28 : 32,
                        ),
                      ),
                      SizedBox(width: isMobile ? 12 : 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.book.title,
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: isMobile ? 16 : 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              widget.book.author,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: isMobile ? 13 : 14,
                              ),
                            ),
                            SizedBox(height: isMobile ? 6 : 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isAvailable
                                    ? '$availableCopies उपलब्ध'
                                    : 'अनुपलब्ध',
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: isMobile ? 11 : 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Inventory Section
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: Container(
                  padding: EdgeInsets.all(isMobile ? 16 : 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[200]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            color: Colors.grey[600],
                            size: isMobile ? 22 : 24,
                          ),
                          SizedBox(width: isMobile ? 10 : 12),
                          Text(
                            'इंटेंटरी विवरण',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: isMobile ? 17 : 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isMobile ? 16 : 20),
                      _buildInventoryRow(
                        'कुल प्रतियां',
                        totalCopies.toString(),
                        Colors.black,
                        isMobile,
                      ),
                      Divider(
                        color: Colors.grey[200],
                        height: isMobile ? 20 : 24,
                      ),
                      _buildInventoryRow(
                        'उपलब्ध प्रतियां',
                        availableCopies.toString(),
                        Colors.green,
                        isMobile,
                      ),
                      Divider(
                        color: Colors.grey[200],
                        height: isMobile ? 20 : 24,
                      ),
                      _buildInventoryRow(
                        'जारी प्रतियां',
                        issuedCopies.toString(),
                        Colors.blue,
                        isMobile,
                      ),
                      Divider(
                        color: Colors.grey[200],
                        height: isMobile ? 20 : 24,
                      ),
                      _buildInventoryRow(
                        'क्षतिग्रस्त प्रतियां',
                        damagedCopies.toString(),
                        Colors.orange,
                        isMobile,
                      ),
                      Divider(
                        color: Colors.grey[200],
                        height: isMobile ? 20 : 24,
                      ),
                      _buildInventoryRow(
                        'खोई हुई प्रतियां',
                        lostCopies.toString(),
                        Colors.red,
                        isMobile,
                      ),
                    ],
                  ),
                ),
              ),
              // Book ID
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: Container(
                  width: 500,
                  padding: EdgeInsets.all(isMobile ? 14 : 16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'किताब ID',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: isMobile ? 12 : 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: isMobile ? 6 : 8),
                      Text(
                        widget.book.bookCode,
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: isMobile ? 18 : 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
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

  Widget _buildInventoryRow(
    String label,
    String value,
    Color valueColor,
    bool isMobile,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: isMobile ? 14 : 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: isMobile ? 16 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
