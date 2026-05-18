import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:room_to_read/controllers/checkin_controller.dart';
import 'package:room_to_read/controllers/home_controller.dart';
import 'package:room_to_read/services/enhanced_offline_service.dart';
import 'package:room_to_read/widgets/custom_app_bar.dart';
import 'package:room_to_read/widgets/offline_status_widget.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('🏠 HomePage: build method called');
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final isDesktop = screenWidth >= 1200;

    final horizontalPadding = isMobile ? 16.0 : (isTablet ? 24.0 : 32.0);
    final verticalPadding = isMobile ? 16.0 : (isTablet ? 20.0 : 24.0);
    final sectionSpacing = isMobile ? 24.0 : (isTablet ? 32.0 : 40.0);
    final cardSpacing = isMobile ? 12.0 : (isTablet ? 16.0 : 20.0);

    return Scaffold(
      appBar: CustomAppBar(title: 'Room To Read'),
      body: Column(
        children: [
          // Offline Status Widget
          OfflineStatusWidget(),
          // Main Content
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main Tasks Section
                    _buildSectionTitle('मुख्य कार्य', isMobile),
                    SizedBox(height: cardSpacing),
                    // Checkout Card
                    _buildMainTaskCard(
                      icon: Icons.add_box_outlined,
                      title: 'चेक आउट',
                      subtitle: 'किताब जारी करें',
                      color: Colors.blue,
                      isMobile: isMobile,
                      onTap: () {
                        Get.toNamed('/checkout');
                      },
                    ),
                    SizedBox(height: cardSpacing),
                    // Return Card
                    Obx(() {
                      try {
                        final homeController = Get.find<HomeController>();
                        return _buildMainTaskCard(
                          icon: Icons.check_box_outlined,
                          title: 'चेक इन',
                          subtitle: 'किताब वापस लें',
                          color: Colors.green,
                          badge: '${homeController.returnCount.value} अतिदेय',
                          isMobile: isMobile,
                          onTap: () {
                            Get.toNamed('/checkin');
                          },
                        );
                      } catch (e) {
                        // Fallback if controller not found
                        return _buildMainTaskCard(
                          icon: Icons.check_box_outlined,
                          title: 'चेक इन',
                          subtitle: 'किताब वापस लें',
                          color: Colors.green,
                          badge: '0 अतिदेय',
                          isMobile: isMobile,
                          onTap: () {
                            Get.toNamed('/checkin');
                          },
                        );
                      }
                    }),
                    SizedBox(height: sectionSpacing),
                    // Management Section
                    _buildSectionTitle('प्रबंधन', isMobile),
                    SizedBox(height: cardSpacing),
                    _buildManagementGrid(
                      isMobile,
                      isTablet,
                      isDesktop,
                      cardSpacing,
                    ),
                    SizedBox(height: sectionSpacing),
                    // System and Reports Section
                    _buildSectionTitle('सिस्टम और रिपोर्ट', isMobile),
                    SizedBox(height: cardSpacing),
                    _buildReportsList(isMobile, cardSpacing),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isMobile) {
    return Text(
      title,
      style: TextStyle(
        fontSize: isMobile ? 20 : 24,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
    );
  }

  Widget _buildMainTaskCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    String? badge,
    required bool isMobile,
    VoidCallback? onTap,
  }) {
    final iconSize = isMobile ? 28.0 : 32.0;
    final containerSize = isMobile ? 50.0 : 56.0;
    final titleFontSize = isMobile ? 18.0 : 20.0;
    final subtitleFontSize = isMobile ? 15.0 : 16.0;
    final padding = isMobile ? 14.0 : 18.0;

    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [color.withOpacity(1), color.withOpacity(0.6)],
    );

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: containerSize,
              height: containerSize,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: iconSize),
            ),
            SizedBox(width: isMobile ? 12 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: subtitleFontSize,
                    ),
                  ),
                ],
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementGrid(
    bool isMobile,
    bool isTablet,
    bool isDesktop,
    double spacing,
  ) {
    int crossAxisCount = isMobile ? 2 : (isTablet ? 3 : 4);

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      children: [
        _buildManagementCard(
          icon: Icons.people_outline,
          title: 'छात्र प्रबंधन',
          color: Colors.amber,
          isMobile: isMobile,
          onTap: () {
            Get.toNamed('/students');
          },
        ),
        _buildManagementCard(
          icon: Icons.menu_book_outlined,
          title: 'किताबें',
          color: Colors.orange,
          isMobile: isMobile,
          onTap: () {
            Get.toNamed('/books');
          },
        ),
      ],
    );
  }

  Widget _buildManagementCard({
    required IconData icon,
    required String title,
    required Color color,
    required bool isMobile,
    VoidCallback? onTap,
  }) {
    final iconSize = isMobile ? 32.0 : 36.0;
    final fontSize = isMobile ? 14.0 : 16.0;
    final padding = isMobile ? 14.0 : 18.0;

    // Different gradients for each card based on title
    late LinearGradient gradient;
    if (title == 'छात्र प्रबंधन') {
      gradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xffffdd00), Color(0xffFF7105)],
      );
    } else if (title == 'किताबें') {
      gradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xffFF8632), Color(0xffFF5722)],
      );
    } else {
      gradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color, color.withOpacity(0.7)],
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: iconSize),
            SizedBox(height: isMobile ? 6 : 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsList(bool isMobile, double spacing) {
    return Column(
      children: [
        _buildReportItem(
          icon: Icons.description_outlined,
          title: 'रिपोर्ट / निर्यात',
          color: Colors.purple,
          isMobile: isMobile,
          onTap: () {
            Get.toNamed('/cico-report');
          },
        ),
        SizedBox(height: spacing),
        _buildReportItem(
          icon: Icons.bar_chart_outlined,
          title: 'विश्लेषण',
          color: Colors.indigo,
          isMobile: isMobile,
          onTap: () {
            print('🔍 Navigating to analytics filter page...');
            Get.toNamed('/analysis-filter');
          },
        ),
        SizedBox(height: spacing),
        _buildReportItem(
          icon: Icons.offline_bolt_outlined,
          title: 'ऑफलाइन सिंक',
          color: Colors.teal,
          isMobile: isMobile,
          onTap: () async {
            // Perform sync directly without navigation
            try {
              Get.snackbar(
                'सिंक शुरू',
                'ऑफलाइन डेटा सिंक हो रहा है...',
                backgroundColor: Colors.teal,
                colorText: Colors.white,
                duration: Duration(seconds: 2),
              );

              final enhancedOfflineService = Get.find<EnhancedOfflineService>();
              final result = await enhancedOfflineService.syncAllCachedData();

              Get.snackbar(
                result['success'] == true ? 'सिंक सफल' : 'सिंक त्रुटि',
                result['message'] ?? 'सिंक पूरा',
                backgroundColor: result['success'] == true
                    ? Colors.green
                    : Colors.red,
                colorText: Colors.white,
                duration: Duration(seconds: 4),
              );

              // Refresh home data after sync
              if (result['success'] == true) {
                // ✅ Refresh HomeController to update book issue counts
                try {
                  final homeController = Get.find<HomeController>();
                  print('🔄 Refreshing HomeController from sync button...');
                  await homeController.fetchBookIssueCounts();
                  print('✅ HomeController refreshed from sync button');
                } catch (e) {
                  print('⚠️ Error refreshing HomeController: $e');
                }

                // ✅ NEW: Refresh checkin list to remove synced books
                try {
                  if (Get.isRegistered<CheckinController>()) {
                    final checkinController = Get.find<CheckinController>();
                    print(
                      '🔄 Refreshing checkin list after successful sync from home...',
                    );
                    await checkinController.refreshCheckedOutBooks();
                    print(
                      '✅ Checkin list refreshed from home - synced books should be removed',
                    );
                  }
                } catch (e) {
                  print(
                    '⚠️ Error refreshing checkin list after sync from home: $e',
                  );
                }
              }
            } catch (e) {
              Get.snackbar(
                'सिंक त्रुटि',
                'सिंक में त्रुटि: $e',
                backgroundColor: Colors.red,
                colorText: Colors.white,
                duration: Duration(seconds: 3),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildReportItem({
    required IconData icon,
    required String title,
    required Color color,
    required bool isMobile,
    VoidCallback? onTap,
  }) {
    final iconSize = isMobile ? 22.0 : 24.0;
    final containerSize = isMobile ? 42.0 : 46.0;
    final fontSize = isMobile ? 15.0 : 16.0;
    final padding = isMobile ? 12.0 : 14.0;

    // Different gradients for each report item
    late LinearGradient gradient;
    if (title == 'रिपोर्ट / निर्यात') {
      gradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff9C27B0), Color(0xff7B1FA2)],
      );
    } else if (title == 'विश्लेषण') {
      gradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff3F51B5), Color(0xff1A237E)],
      );
    } else if (title == 'ऑफलाइन सिंक') {
      gradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff009688), Color(0xff00695C)],
      );
    } else {
      gradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color, color.withOpacity(0.7)],
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Container(
              width: containerSize,
              height: containerSize,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: iconSize),
            ),
            SizedBox(width: isMobile ? 10 : 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
