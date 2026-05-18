import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:room_to_read/models/student_model.dart';
import 'package:room_to_read/widgets/custom_app_bar.dart';

class UpdateReadingLevelPage extends StatefulWidget {
  final Student student;

  const UpdateReadingLevelPage({Key? key, required this.student})
    : super(key: key);

  @override
  State<UpdateReadingLevelPage> createState() => _UpdateReadingLevelPageState();
}

class _UpdateReadingLevelPageState extends State<UpdateReadingLevelPage> {
  late TextEditingController levelController;
  late DateTime selectedDate;
  late int selectedLevel;

  @override
  void initState() {
    super.initState();
    levelController = TextEditingController(
      text: widget.student.readingLevel.toString(),
    );
    selectedLevel = widget.student.readingLevel;
    selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    levelController.dispose();
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
      body: SingleChildScrollView(
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
                          'रीडिंग लेवल बदलें',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 18 : 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'छात्र का लेवल अपडेट करें',
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
            // Reading Level Section
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: Container(
                padding: EdgeInsets.all(isMobile ? 14 : 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'रीडिंग लेवल',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: isMobile ? 14 : 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: isMobile ? 12 : 14),

                    // Level Text Input
                    DropdownButtonFormField<int>(
                      value: selectedLevel,
                      decoration: InputDecoration(
                        labelText: 'रीडिंग लेवल चुनें',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.blue[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.blue[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.blue, width: 2),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 12 : 14,
                          vertical: isMobile ? 14 : 16,
                        ),
                      ),
                      items: List.generate(
                        6,
                        (index) => DropdownMenuItem(
                          value: index + 1,
                          child: Text(
                            'लेवल ${index + 1}',
                            style: TextStyle(
                              fontSize: isMobile ? 15 : 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedLevel = value;
                          });
                        }
                      },
                    ),

                    SizedBox(height: isMobile ? 12 : 14),
                    // Level Change Info
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 14,
                        vertical: isMobile ? 8 : 10,
                      ),
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
                            size: isMobile ? 18 : 20,
                          ),
                          SizedBox(width: isMobile ? 8 : 10),
                          Expanded(
                            child: Text(
                              'पुरना लेवल: ${widget.student.previousLevel} → वर्तमान लेवल: ${widget.student.readingLevel}',
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontSize: isMobile ? 13 : 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isMobile ? 12 : 14),
                    // Last Update Date
                    Text(
                      'अंतिम मुख्यांकन: ${selectedDate.day} दिसंबर ${selectedDate.year}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: isMobile ? 12 : 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Action Buttons
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: Column(
                children: [
                  // Save Button
                  GestureDetector(
                    onTap: () {
                      print('✅ Selected reading level: $selectedLevel');

                      Get.back(result: selectedLevel);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        vertical: isMobile ? 14 : 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'सेव करें',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: isMobile ? 10 : 12),
                  // Cancel Button
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        vertical: isMobile ? 14 : 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Center(
                        child: Text(
                          'रद्द करें',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.bold,
                          ),
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
    );
  }
}
