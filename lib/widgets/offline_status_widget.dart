import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:room_to_read/services/enhanced_offline_service.dart';

class OfflineStatusWidget extends StatelessWidget {
  const OfflineStatusWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final enhancedOfflineService = Get.find<EnhancedOfflineService>();
    
    return Obx(() {
      if (!enhancedOfflineService.isOfflineMode.value) {
        return SizedBox.shrink();
      }
      
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Colors.orange[100],
        child: Row(
          children: [
            Icon(
              Icons.wifi_off,
              color: Colors.orange[800],
              size: 16,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'ऑफलाइन मोड - सभी कार्य उपलब्ध हैं',
                style: TextStyle(
                  color: Colors.orange[800],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (enhancedOfflineService.pendingTransactions.value > 0) ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange[800],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${enhancedOfflineService.pendingTransactions.value}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 4),
              Text(
                'सिंक प्रतीक्षा',
                style: TextStyle(
                  color: Colors.orange[800],
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}