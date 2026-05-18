import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:room_to_read/models/student_model.dart';
import 'package:room_to_read/services/api_service.dart';
import 'package:room_to_read/services/auth_service.dart';
import 'package:room_to_read/widgets/custom_app_bar.dart';
class StudentBookHistoryPage extends StatefulWidget {
  final Student student;

  const StudentBookHistoryPage({super.key, required this.student});

  @override
  State<StudentBookHistoryPage> createState() => _StudentBookHistoryPageState();
}

class _StudentBookHistoryPageState extends State<StudentBookHistoryPage> {
  final ApiService _apiService = Get.find<ApiService>();
  final AuthService _authService = Get.find<AuthService>();
  List<dynamic> bookHistory = [];
  bool isLoading = true;
  String dateFromFilter = '';
  String dateToFilter = '';         
  String sortBy = 'नवीनतम पहले'; // Default sort: newest first

  @override
  void initState() {
    super.initState();
    fetchBookHistory();
  }

  void applySorting() {
    setState(() {
      if (sortBy == 'नवीनतम पहले') {
        // Sort by issue date - newest first
        bookHistory.sort((a, b) {
          final aDate = (a['F4_DATE1'] ?? '').toString();
          final bDate = (b['F4_DATE1'] ?? '').toString();
          return bDate.compareTo(aDate);
        });
      } else if (sortBy == 'पुराना पहले') {
        // Sort by issue date - oldest first
        bookHistory.sort((a, b) {
          final aDate = (a['F4_DATE1'] ?? '').toString();
          final bDate = (b['F4_DATE1'] ?? '').toString();
          return aDate.compareTo(bDate);
        });
      } else if (sortBy == 'वापसी तिथि') {
        // Sort by return date
        bookHistory.sort((a, b) {
          final aDate = (a['F4_DATE2'] ?? '').toString();
          final bDate = (b['F4_DATE2'] ?? '').toString();
          return bDate.compareTo(aDate);
        });
      }
    });
  }

  Future<void> fetchBookHistory() async {
    setState(() {
      isLoading = true;
    });

    try {
      final currentUser = _authService.currentUser.value;
      if (currentUser == null) {
        Get.snackbar('Error', 'Please login first');
        return;
      }

      print('Fetching history for student code: ${widget.student.code}');
      print('Student ID: ${widget.student.id}');
      print('Student name: ${widget.student.name}');

      final history = await _apiService.getStudentBookHistory(
        studentId: widget.student.code,
        fromDate: dateFromFilter.isNotEmpty ? dateFromFilter : null,
        toDate: dateToFilter.isNotEmpty ? dateToFilter : null,
      );

      print('Total records received: ${history.length}');

      if (history.isNotEmpty) {
        print('Sample record: ${history[0]}');
      }

      // The API already filters by student_id, so we just sort by date
      history.sort((a, b) {
        final aDate = (a['F4_DATE1'] ?? '').toString();
        final bDate = (b['F4_DATE1'] ?? '').toString();
        return bDate.compareTo(aDate); // Most recent first
      });

      setState(() {
        bookHistory = history;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching book history: $e');
      setState(() {
        isLoading = false;
      });
      Get.snackbar('Error', 'Failed to load book history: $e');
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CICO हिस्ट्री',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isMobile ? 20 : 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'किताबों का पूर्ण रिकॉर्ड',
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
                ],
              ),
            ),
            // Student Info
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
            // Date Filter
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'तिथि फिल्टर',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: isMobile ? 10 : 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() {
                                dateFromFilter =
                                    '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                              });
                              fetchBookHistory();
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.all(isMobile ? 12 : 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  dateFromFilter.isEmpty
                                      ? 'से (From)'
                                      : dateFromFilter,
                                  style: TextStyle(
                                    color: dateFromFilter.isEmpty
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
                      SizedBox(width: isMobile ? 10 : 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() {
                                dateToFilter =
                                    '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                              });
                              fetchBookHistory();
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.all(isMobile ? 12 : 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  dateToFilter.isEmpty
                                      ? 'तक (To)'
                                      : dateToFilter,
                                  style: TextStyle(
                                    color: dateToFilter.isEmpty
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
                ],
              ),
            ),
            SizedBox(height: isMobile ? 16 : 20),
            // Sort Dropdown
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'क्रमबद्ध करें',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: isMobile ? 8 : 10),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: DropdownButton<String>(
                      value: sortBy,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: [
                        DropdownMenuItem(
                          value: 'नवीनतम पहले',
                          child: Text(
                            'नवीनतम पहले',
                            style: TextStyle(fontSize: isMobile ? 13 : 14),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'पुराना पहले',
                          child: Text(
                            'पुराना पहले',
                            style: TextStyle(fontSize: isMobile ? 13 : 14),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'वापसी तिथि',
                          child: Text(
                            'वापसी तिथि',
                            style: TextStyle(fontSize: isMobile ? 13 : 14),
                          ),
                        ),
                      ],
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            sortBy = newValue;
                          });
                          applySorting();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isMobile ? 16 : 20),
            // Book History List
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Text(
                'रिकॉर्ड (${bookHistory.length})',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            SizedBox(height: isMobile ? 10 : 12),
            isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : bookHistory.isEmpty
                ? Padding(
                    padding: EdgeInsets.all(horizontalPadding),
                    child: Container(
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
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    itemCount: bookHistory.length,
                    itemBuilder: (context, index) {
                      final record = bookHistory[index];
                      final isIssued = record['F4_BT'] == '1';

                      return Padding(
                        padding: EdgeInsets.only(bottom: isMobile ? 10 : 12),
                        child: Container(
                          padding: EdgeInsets.all(isMobile ? 12 : 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: isMobile ? 40 : 44,
                                height: isMobile ? 40 : 44,
                                decoration: BoxDecoration(
                                  color: isIssued
                                      ? Colors.blue[100]
                                      : Colors.green[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.menu_book,
                                  color: isIssued
                                      ? Colors.blue[700]
                                      : Colors.green[700],
                                  size: isMobile ? 22 : 24,
                                ),
                              ),
                              SizedBox(width: isMobile ? 10 : 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      record['book_name'] ?? 'N/A',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: isMobile ? 13 : 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'रीडिंग लेवल: ${record['reading_level'] ?? 'N/A'}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: isMobile ? 11 : 12,
                                      ),
                                    ),
                                    Text(
                                      'जारी: ${record['F4_DATE1'] ?? 'N/A'}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: isMobile ? 11 : 12,
                                      ),
                                    ),
                                    if (record['F4_DATE2'] != null &&
                                        record['F4_DATE2']
                                            .toString()
                                            .isNotEmpty)
                                      Text(
                                        'वापस: ${record['F4_DATE2']}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: isMobile ? 11 : 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 8 : 10,
                                  vertical: isMobile ? 4 : 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isIssued
                                      ? Colors.blue.withOpacity(0.2)
                                      : Colors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isIssued ? 'जारी है' : 'वापस की गई',
                                  style: TextStyle(
                                    fontSize: isMobile ? 11 : 12,
                                    fontWeight: FontWeight.bold,
                                    color: isIssued
                                        ? Colors.blue
                                        : Colors.green,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            SizedBox(height: verticalPadding),
          ],
        ),
      ),
    );
  }
}
