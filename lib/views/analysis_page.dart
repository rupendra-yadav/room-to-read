import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:room_to_read/controllers/analysis_controller.dart';
import 'package:room_to_read/widgets/custom_app_bar.dart';

class AnalysisPage extends GetView<AnalysisController> {
  const AnalysisPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final horizontalPadding = isMobile ? 16.0 : 24.0;
    final verticalPadding = isMobile ? 16.0 : 20.0;

    print("yaha dekh ${controller.selectedClass.value}");

    return SafeArea(
      child: Scaffold(
        appBar: CustomAppBar(title: 'Room To Read'),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                color: Colors.indigo,
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
                    Text(
                      'विश्लेषण परिणाम',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 18 : 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: SizedBox(), // Better than Spacer for this use case
                    ),
                    // Debug button (for testing)
                    GestureDetector(
                      onTap: () {
                        controller.debugAnalyticsState();
                      },
                      child: Container(
                        padding: EdgeInsets.all(6),
                        margin: EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          Icons.bug_report,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                    // Refresh button
                    Obx(
                      () => GestureDetector(
                        onTap: controller.isLoading.value
                            ? null
                            : () {
                                controller.refreshAnalytics();
                              },
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(
                              controller.isLoading.value ? 0.1 : 0.2,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: controller.isLoading.value
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.refresh,
                                  color: Colors.white,
                                  size: 20,
                                ),
                        ),
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
                    // Selected Filter Summary
                    Container(
                      padding: EdgeInsets.all(isMobile ? 12 : 14),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'चयनित फिल्टर',
                            style: TextStyle(
                              fontSize: isMobile ? 13 : 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: isMobile ? 8 : 10),
                          Obx(
                            () => Column(
                              children: [
                                _buildSummaryRow(
                                  'कक्षा',
                                  controller.selectedClass.value,
                                  isMobile,
                                ),
                                Divider(
                                  color: Colors.grey[300],
                                  height: isMobile ? 12 : 14,
                                ),
                                _buildSummaryRow(
                                  'तिथि',
                                  controller.dateFromFilter.value.isNotEmpty &&
                                          controller
                                              .dateToFilter
                                              .value
                                              .isNotEmpty
                                      ? '${controller.dateFromFilter.value} से ${controller.dateToFilter.value}'
                                      : controller
                                            .dateFromFilter
                                            .value
                                            .isNotEmpty
                                      ? '${controller.dateFromFilter.value} से आज तक'
                                      : controller.dateToFilter.value.isNotEmpty
                                      ? 'शुरुआत से ${controller.dateToFilter.value}'
                                      : 'सभी तारीखें',
                                  isMobile,
                                ),
                                Divider(
                                  color: Colors.grey[300],
                                  height: isMobile ? 12 : 14,
                                ),
                                _buildSummaryRow(
                                  'समूहन',
                                  controller.selectedAggregation.value,
                                  isMobile,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isMobile ? 16 : 20),
                    // Chart Section
                    Text(
                      'मासिक चेक-आउट रिपोर्ट',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: isMobile ? 10 : 12),
                    Container(
                      padding: EdgeInsets.all(isMobile ? 12 : 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            height: isMobile
                                ? 280
                                : 320, // Increased height for better chart visibility
                            child: Obx(() {
                              if (controller.isLoading.value) {
                                // Show loading indicator
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.blue,
                                            ),
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        'चार्ट लोड हो रहा है...',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: isMobile ? 12 : 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              } else if (controller.chartValues.isEmpty) {
                                // Show no data message
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.analytics_outlined,
                                        color: Colors.grey[400],
                                        size: isMobile ? 48 : 56,
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        'कोई डेटा उपलब्ध नहीं है',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: isMobile ? 14 : 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'कृपया अलग फिल्टर आज़माएं',
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: isMobile ? 12 : 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                // Show actual chart with data
                                return ClipRect(
                                  child: CustomPaint(
                                    painter: ChartPainter(
                                      labels: controller.chartLabels,
                                      values: controller.chartValues,
                                    ),
                                    child: Container(),
                                  ),
                                );
                              }
                            }),
                          ),
                          // Chart now has built-in axis labels
                        ],
                      ),
                    ),
                    SizedBox(height: isMobile ? 16 : 20),

                    // Statistics
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(isMobile ? 12 : 14),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'कुल रिकॉर्ड',
                                  style: TextStyle(
                                    fontSize: isMobile ? 12 : 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: isMobile ? 6 : 8),
                                Obx(
                                  () => Text(
                                    '${controller.totalRecords.value}',
                                    style: TextStyle(
                                      fontSize: isMobile ? 18 : 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: isMobile ? 10 : 12),
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(isMobile ? 12 : 14),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'औसत प्रति माह',
                                  style: TextStyle(
                                    fontSize: isMobile ? 12 : 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: isMobile ? 6 : 8),
                                Obx(
                                  () => Text(
                                    '${controller.avgPerMonth.value}',
                                    style: TextStyle(
                                      fontSize: isMobile ? 18 : 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isMobile ? 16 : 20),

                    // Info Box
                    Container(
                      padding: EdgeInsets.all(isMobile ? 12 : 14),
                      decoration: BoxDecoration(
                        color: Colors.yellow[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.yellow[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange,
                            size: isMobile ? 18 : 20,
                          ),
                          SizedBox(width: isMobile ? 10 : 12),
                          Expanded(
                            child: Text(
                              'यह डेटा चेक-आउट लिमिट के अनुसार पर मासिक रूप से संकलित है',
                              style: TextStyle(
                                fontSize: isMobile ? 12 : 13,
                                color: Colors.orange[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isMobile ? 16 : 20),

                    // Reports Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Obx(
                          () => Text(
                            'रिपोर्ट (${controller.reportList.length})',
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        Text(
                          'विस्तार देखें',
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 13,
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isMobile ? 10 : 12),

                    // No reports available
                    Obx(
                      () => controller.reportList.isEmpty
                          ? Container(
                              padding: EdgeInsets.all(isMobile ? 16 : 20),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Center(
                                child: Text(
                                  'कोई रिपोर्ट उपलब्ध नहीं है',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: isMobile ? 14 : 16,
                                  ),
                                ),
                              ),
                            )
                          : Column(
                              children: controller.reportList.map((report) {
                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: isMobile ? 10 : 12,
                                  ),
                                  child: _buildReportCard(
                                    report['book_name'] ?? 'N/A',
                                    'छात्र: ${report['student_name'] ?? 'N/A'}',
                                    'जारी: ${report['F4_DATE1'] ?? 'N/A'}${report['F4_DATE2'] != null && report['F4_DATE2'] != report['F4_DATE1'] ? ' • लौटा: ${report['F4_DATE2']}' : ''}',
                                    report['F4_BT'] == '1'
                                        ? 'जारी है'
                                        : 'वापस की गई',
                                    report['F4_BT'] == '1'
                                        ? Colors.blue
                                        : Colors.green,
                                    isMobile,
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isMobile ? 12 : 13,
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isMobile ? 12 : 13,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildReportCard(
    String title,
    String subtitle,
    String details,
    String status,
    Color statusColor,
    bool isMobile,
  ) {
    return Container(
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
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.menu_book,
              color: Colors.grey[600],
              size: isMobile ? 20 : 22,
            ),
          ),
          SizedBox(width: isMobile ? 12 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  details,
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    color: Colors.grey[600],
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
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: isMobile ? 11 : 12,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChartPainter extends CustomPainter {
  final List<String> labels;
  final List<int> values;

  ChartPainter({required this.labels, required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || labels.isEmpty) return;

    // Ensure we have valid dimensions
    if (size.width <= 0 || size.height <= 0) return;

    // Find max value for scaling
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    if (maxValue == 0) return;

    // Add padding for labels
    final leftPadding = 60.0; // More space for Y-axis labels
    final rightPadding = 30.0;
    final topPadding = 40.0; // More space for title and values
    final bottomPadding = 60.0; // More space for X-axis labels

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    // Ensure we have valid chart dimensions
    if (chartWidth <= 0 || chartHeight <= 0) return;

    // Calculate Y-axis scale - use increments of 3 like in the image (0, 3, 6, 9, 12)
    final yAxisMax = ((maxValue / 3).ceil() * 3).toInt();
    final yAxisStep = 3;
    final yAxisSteps = (yAxisMax / yAxisStep).toInt();

    // Draw Y-axis labels (no grid lines, just like the image)
    final yLabelPaint = TextStyle(
      color: Colors.grey[500]!,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );

    for (int i = 0; i <= yAxisSteps; i++) {
      final yValue = i * yAxisStep;
      final y = topPadding + chartHeight - (i / yAxisSteps) * chartHeight;

      // Draw Y-axis label
      final yLabelPainter = TextPainter(
        text: TextSpan(text: '$yValue', style: yLabelPaint),
        textDirection: TextDirection.ltr,
      );
      yLabelPainter.layout();
      yLabelPainter.paint(
        canvas,
        Offset(
          leftPadding - yLabelPainter.width - 15,
          y - yLabelPainter.height / 2,
        ),
      );
    }

    // Draw X-axis labels (Hindi month names)
    final xLabelPaint = TextStyle(
      color: Colors.grey[600]!,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );

    for (int i = 0; i < labels.length; i++) {
      final x = labels.length > 1
          ? leftPadding + (i / (labels.length - 1)) * chartWidth
          : leftPadding + chartWidth / 2;

      // Convert English month names to Hindi if needed
      String displayLabel = _convertToHindiMonth(labels[i]);

      // Draw X-axis label
      final xLabelPainter = TextPainter(
        text: TextSpan(text: displayLabel, style: xLabelPaint),
        textDirection: TextDirection.ltr,
      );
      xLabelPainter.layout();
      xLabelPainter.paint(
        canvas,
        Offset(x - xLabelPainter.width / 2, topPadding + chartHeight + 15),
      );
    }

    // Calculate data points
    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = values.length > 1
          ? leftPadding + (i / (values.length - 1)) * chartWidth
          : leftPadding + chartWidth / 2;
      final normalizedValue = values[i] / yAxisMax;
      final y = topPadding + chartHeight - (normalizedValue * chartHeight);
      points.add(Offset(x, y));
    }

    // Draw area under the line (smooth gradient fill like in the image)
    if (points.isNotEmpty) {
      final areaPath = Path();
      areaPath.moveTo(leftPadding, topPadding + chartHeight);

      if (points.length == 1) {
        // Single point - draw a small area around it
        areaPath.lineTo(points.first.dx, points.first.dy);
        areaPath.lineTo(points.first.dx, topPadding + chartHeight);
      } else if (points.length == 2) {
        // Two points - simple line
        areaPath.lineTo(points.first.dx, points.first.dy);
        areaPath.lineTo(points.last.dx, points.last.dy);
        areaPath.lineTo(points.last.dx, topPadding + chartHeight);
      } else {
        // Multiple points - draw very smooth curve using cubic bezier
        areaPath.lineTo(points.first.dx, points.first.dy);

        // Create smooth cubic bezier curve through all points
        for (int i = 0; i < points.length - 1; i++) {
          final current = points[i];
          final next = points[i + 1];

          // Calculate control points for smooth curve
          Offset controlPoint1, controlPoint2;

          if (i == 0) {
            // First segment
            final nextNext = i + 2 < points.length ? points[i + 2] : next;
            controlPoint1 = Offset(
              current.dx + (next.dx - current.dx) * 0.3,
              current.dy + (next.dy - current.dy) * 0.3,
            );
            controlPoint2 = Offset(
              next.dx - (nextNext.dx - current.dx) * 0.2,
              next.dy - (nextNext.dy - current.dy) * 0.2,
            );
          } else if (i == points.length - 2) {
            // Last segment
            final prev = points[i - 1];
            controlPoint1 = Offset(
              current.dx + (next.dx - prev.dx) * 0.2,
              current.dy + (next.dy - prev.dy) * 0.2,
            );
            controlPoint2 = Offset(
              next.dx - (next.dx - current.dx) * 0.3,
              next.dy - (next.dy - current.dy) * 0.3,
            );
          } else {
            // Middle segments
            final prev = points[i - 1];
            final nextNext = points[i + 2];
            controlPoint1 = Offset(
              current.dx + (next.dx - prev.dx) * 0.2,
              current.dy + (next.dy - prev.dy) * 0.2,
            );
            controlPoint2 = Offset(
              next.dx - (nextNext.dx - current.dx) * 0.2,
              next.dy - (nextNext.dy - current.dy) * 0.2,
            );
          }

          areaPath.cubicTo(
            controlPoint1.dx,
            controlPoint1.dy,
            controlPoint2.dx,
            controlPoint2.dy,
            next.dx,
            next.dy,
          );
        }

        areaPath.lineTo(points.last.dx, topPadding + chartHeight);
      }

      areaPath.lineTo(leftPadding, topPadding + chartHeight);
      areaPath.close();

      final areaPaint = Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF4A90E2).withOpacity(0.6), // Stronger blue at top
                Color(0xFF4A90E2).withOpacity(0.1), // Lighter blue at bottom
              ],
            ).createShader(
              Rect.fromLTWH(leftPadding, topPadding, chartWidth, chartHeight),
            )
        ..style = PaintingStyle.fill;

      canvas.drawPath(areaPath, areaPaint);
    }

    // Draw the line (very smooth curve using cubic bezier)
    if (points.length > 1) {
      final linePath = Path();
      linePath.moveTo(points.first.dx, points.first.dy);

      if (points.length == 2) {
        // Simple line for two points
        linePath.lineTo(points.last.dx, points.last.dy);
      } else {
        // Smooth cubic bezier curve for multiple points
        for (int i = 0; i < points.length - 1; i++) {
          final current = points[i];
          final next = points[i + 1];

          // Calculate control points for smooth curve
          Offset controlPoint1, controlPoint2;

          if (i == 0) {
            // First segment
            final nextNext = i + 2 < points.length ? points[i + 2] : next;
            controlPoint1 = Offset(
              current.dx + (next.dx - current.dx) * 0.3,
              current.dy + (next.dy - current.dy) * 0.3,
            );
            controlPoint2 = Offset(
              next.dx - (nextNext.dx - current.dx) * 0.2,
              next.dy - (nextNext.dy - current.dy) * 0.2,
            );
          } else if (i == points.length - 2) {
            // Last segment
            final prev = points[i - 1];
            controlPoint1 = Offset(
              current.dx + (next.dx - prev.dx) * 0.2,
              current.dy + (next.dy - prev.dy) * 0.2,
            );
            controlPoint2 = Offset(
              next.dx - (next.dx - current.dx) * 0.3,
              next.dy - (next.dy - current.dy) * 0.3,
            );
          } else {
            // Middle segments
            final prev = points[i - 1];
            final nextNext = points[i + 2];
            controlPoint1 = Offset(
              current.dx + (next.dx - prev.dx) * 0.2,
              current.dy + (next.dy - prev.dy) * 0.2,
            );
            controlPoint2 = Offset(
              next.dx - (nextNext.dx - current.dx) * 0.2,
              next.dy - (nextNext.dy - current.dy) * 0.2,
            );
          }

          linePath.cubicTo(
            controlPoint1.dx,
            controlPoint1.dy,
            controlPoint2.dx,
            controlPoint2.dy,
            next.dx,
            next.dy,
          );
        }
      }

      final linePaint = Paint()
        ..color =
            Color(0xFF4A90E2) // Nice blue color like in the image
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round; // Smooth joins

      canvas.drawPath(linePath, linePaint);
    }

    // Don't draw data point circles - keep it clean like the image

    // Draw Y-axis line
    final yAxisPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(leftPadding, topPadding),
      Offset(leftPadding, topPadding + chartHeight),
      yAxisPaint,
    );

    // Draw X-axis line (baseline)
    final xAxisPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(leftPadding, topPadding + chartHeight),
      Offset(size.width - rightPadding, topPadding + chartHeight),
      xAxisPaint,
    );
  }

  String _convertToHindiMonth(String englishMonth) {
    final monthMap = {
      'January': 'जनवरी',
      'February': 'फरवरी',
      'March': 'मार्च',
      'April': 'अप्रैल',
      'May': 'मई',
      'June': 'जून',
      'July': 'जुलाई',
      'August': 'अगस्त',
      'September': 'सितंबर',
      'October': 'अक्टूबर',
      'November': 'नवंबर',
      'December': 'दिसंबर',
      // Also handle short forms
      'Jan': 'जनवरी',
      'Feb': 'फरवरी',
      'Mar': 'मार्च',
      'Apr': 'अप्रैल',
      'Jun': 'जून',
      'Jul': 'जुलाई',
      'Aug': 'अगस्त',
      'Sep': 'सितंबर',
      'Oct': 'अक्टूबर',
      'Nov': 'नवंबर',
      'Dec': 'दिसंबर',
    };

    return monthMap[englishMonth] ?? englishMonth;
  }

  @override
  bool shouldRepaint(ChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.labels != labels;
  }
}
