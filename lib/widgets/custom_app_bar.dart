import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:room_to_read/services/connectivity_service.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showProfileIcon;

  const CustomAppBar({
    Key? key,
    required this.title,
    this.showProfileIcon = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final titleFontSize = isMobile ? 16.0 : 20.0;
    final subtitleFontSize = isMobile ? 11.0 : 13.0;
    final iconSize = isMobile ? 20.0 : 24.0;
    final containerSize = isMobile ? 36.0 : 44.0;

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Row(
        children: [
          Container(
            width: containerSize,
            height: containerSize,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.menu_book,
                      color: Colors.white,
                      size: iconSize,
                    ),
                  );
                },
              ),
            ),
          ),
          SizedBox(width: isMobile ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Library Manager',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: subtitleFontSize,
                    fontWeight: FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Offline status indicator
        Obx(() {
          final connectivityService = Get.find<ConnectivityService>();
          if (!connectivityService.isOnline.value) {
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Icon(
                Icons.wifi_off,
                color: Colors.orange,
                size: isMobile ? 18 : 20,
              ),
            );
          }
          return const SizedBox.shrink();
        }),
        if (showProfileIcon)
          Padding(
            padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
            child: GestureDetector(
              onTap: () => Get.toNamed('/profile'),
              child: CircleAvatar(
                backgroundColor: Colors.grey[300],
                radius: isMobile ? 16 : 20,
                child: Icon(
                  Icons.person,
                  color: Colors.grey,
                  size: isMobile ? 18 : 22,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
