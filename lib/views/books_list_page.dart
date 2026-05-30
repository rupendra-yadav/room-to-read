import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:room_to_read/controllers/book_controller.dart';
import 'package:room_to_read/views/book_detail_page.dart';
import 'package:room_to_read/widgets/custom_app_bar.dart';
import 'package:room_to_read/widgets/shimmer_loading.dart';
import 'package:room_to_read/widgets/debug_info_widget.dart';
import 'package:room_to_read/widgets/offline_status_widget.dart';

class BooksListPage extends StatefulWidget {
  const BooksListPage({Key? key}) : super(key: key);

  @override
  State<BooksListPage> createState() => _BooksListPageState();
}

class _BooksListPageState extends State<BooksListPage> {
  final BookController controller = Get.find<BookController>();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
          _searchController.text = controller.searchQuery.value;
          return ListView.builder(
            itemCount: 5,
            itemBuilder: (context, index) => const StudentCardShimmer(),
          );
        }

        return Column(
          children: [
            // Offline Status Widget
            OfflineStatusWidget(),
            // Header with back button and search
            Container(
              color: Colors.orange,
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
                              'किताबें',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isMobile ? 20 : 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'पुस्तक प्रबंधन',
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
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => controller.searchBooks(value),
                      decoration: InputDecoration(
                        hintText: 'किताब का नाम या लेखक खोजें',
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
                  SizedBox(height: isMobile ? 10 : 12),
                ],
              ),
            ),
            // Book count header
            Padding(
              padding: EdgeInsets.all(horizontalPadding),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Obx(
                    () => Text(
                      'कुल किताबें: ${controller.filteredBooks.length}',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  // Refresh button
                  // IconButton(
                  //   onPressed: () => controller.loadBooks(),
                  //   icon: Obx(
                  //     () => controller.isLoading.value
                  //         ? SizedBox(
                  //             width: 20,
                  //             height: 20,
                  //             child: CircularProgressIndicator(
                  //               strokeWidth: 2,
                  //               valueColor: AlwaysStoppedAnimation<Color>(
                  //                 Colors.orange,
                  //               ),
                  //             ),
                  //           )
                  //         : Icon(Icons.refresh, color: Colors.orange, size: 24),
                  //   ),
                  //   tooltip: 'रीफ्रेश करें',
                  // ),
                ],
              ),
            ),
            // Debug info widget (only show if no books and not loading)
            Obx(() {
              if (!controller.isLoading.value && controller.books.isEmpty) {
                return DebugInfoWidget();
              }
              return SizedBox.shrink();
            }),
            // Books List
            Expanded(
              child: Obx(
                () => controller.filteredBooks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.menu_book_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              controller.isLoading.value
                                  ? 'किताबें लोड हो रही हैं...'
                                  : controller.books.isEmpty
                                  ? 'कोई किताब उपलब्ध नहीं है'
                                  : 'कोई किताब नहीं मिली',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: isMobile ? 16 : 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (!controller.isLoading.value &&
                                controller.books.isEmpty) ...[
                              SizedBox(height: 8),
                              Text(
                                'कृपया इंटरनेट कनेक्शन जांचें या रीफ्रेश करें',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: isMobile ? 12 : 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => controller.loadBooks(),
                                icon: Icon(Icons.refresh),
                                label: Text('रीफ्रेश करें'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: verticalPadding,
                        ),
                        itemCount: controller.filteredBooks.length,
                        itemBuilder: (context, index) {
                          final book = controller.filteredBooks[index];
                          return _buildBookCard(
                            book,
                            isMobile,
                            verticalPadding,
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildBookCard(dynamic book, bool isMobile, double spacing) {
    final bool isAvailable = book.availableCopy > 0;
    final Color statusColor = isAvailable ? Colors.green : Colors.red;
    final Color statusBgColor = isAvailable
        ? Colors.green[50]!
        : Colors.red[50]!;

    return GestureDetector(
      onTap: () => Get.to(() => BookDetailPage(book: book)),
      child: Container(
        margin: EdgeInsets.only(bottom: spacing),
        padding: EdgeInsets.all(isMobile ? 12 : 14),
        decoration: BoxDecoration(
          color: statusBgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: isMobile ? 48 : 52,
              height: isMobile ? 48 : 52,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.menu_book,
                color: statusColor,
                size: isMobile ? 26 : 28,
              ),
            ),
            SizedBox(width: isMobile ? 12 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.bookName,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: isMobile ? 15 : 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (book.bookRomanName != null &&
                      book.bookRomanName.toString().isNotEmpty)
                    Text(
                      book.bookRomanName,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: isMobile ? 12 : 13,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (book.bookLocalName != null &&
                      book.bookLocalName.toString().isNotEmpty &&
                      book.bookLocalName.toString() != book.bookName.toString())
                    Text(
                      book.bookLocalName,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: isMobile ? 11 : 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  SizedBox(height: isMobile ? 4 : 6),
                  Text(
                    book.authorName,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: isMobile ? 11 : 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: isMobile ? 4 : 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          isAvailable
                              ? '${book.availableCopies} उपलब्ध'
                              : 'अनुपलब्ध',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: isMobile ? 10 : 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
