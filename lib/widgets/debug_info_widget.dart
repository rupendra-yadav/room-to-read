import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:room_to_read/services/auth_service.dart';
import 'package:room_to_read/services/connectivity_service.dart';
import 'package:room_to_read/services/offline_database_service.dart';
import 'package:room_to_read/services/data_preloader_service.dart';
import 'package:room_to_read/services/api_service.dart';

class DebugInfoWidget extends StatelessWidget {
  const DebugInfoWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bug_report, size: 16, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                'Debug Info',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          SizedBox(height: 8),
          _buildDebugInfo(),
        ],
      ),
    );
  }

  Widget _buildDebugInfo() {
    return Obx(() {
      final authService = Get.find<AuthService>();
      final connectivityService = Get.find<ConnectivityService>();
      final dataPreloader = Get.find<DataPreloaderService>();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            'User',
            authService.currentUser.value?.name ?? 'Not logged in',
          ),
          _buildInfoRow(
            'User ID',
            authService.currentUser.value?.code ?? 'N/A',
          ),
          _buildInfoRow(
            'Online',
            connectivityService.isOnline.value ? 'Yes' : 'No',
          ),
          _buildInfoRow('Connection', connectivityService.connectionType.value),
          _buildInfoRow(
            'Preloading',
            dataPreloader.isPreloading.value ? 'Yes' : 'No',
          ),
          if (dataPreloader.preloadStatus.value.isNotEmpty)
            _buildInfoRow('Status', dataPreloader.preloadStatus.value),
          SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton(
                onPressed: () => _showDetailedDebug(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                child: Text('Detailed Debug', style: TextStyle(fontSize: 12)),
              ),
              SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _testApiDirectly(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                child: Text('Test API', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      );
    });
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDetailedDebug() async {
    final authService = Get.find<AuthService>();
    final connectivityService = Get.find<ConnectivityService>();
    final offlineDb = Get.find<OfflineDatabaseService>();

    try {
      final offlineBooks = await offlineDb.getBooksOffline();
      final stats = await offlineDb.getOfflineStats();

      Get.dialog(
        AlertDialog(
          title: Text('Detailed Debug Info'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Authentication:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('• Logged in: ${authService.isLoggedIn.value}'),
                Text(
                  '• User: ${authService.currentUser.value?.name ?? "None"}',
                ),
                Text(
                  '• User ID: ${authService.currentUser.value?.code ?? "None"}',
                ),
                SizedBox(height: 12),
                Text(
                  'Connectivity:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('• Online: ${connectivityService.isOnline.value}'),
                Text('• Type: ${connectivityService.connectionType.value}'),
                SizedBox(height: 12),
                Text(
                  'Offline Database:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('• Books stored: ${offlineBooks.length}'),
                Text('• Students: ${stats['students'] ?? 0}'),
                Text('• Classes: ${stats['classes'] ?? 0}'),
                if (offlineBooks.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Text(
                    'Sample book:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('• Name: ${offlineBooks.first['name'] ?? "N/A"}'),
                  Text('• Code: ${offlineBooks.first['code'] ?? "N/A"}'),
                  Text('• Author: ${offlineBooks.first['lname'] ?? "N/A"}'),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Get.back(), child: Text('Close')),
          ],
        ),
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to get debug info: $e');
    }
  }

  Future<void> _testApiDirectly() async {
    try {
      Get.snackbar(
        'Testing',
        'Running API test...',
        duration: Duration(seconds: 2),
      );

      final authService = Get.find<AuthService>();
      final currentUser = authService.currentUser.value;

      if (currentUser == null) {
        Get.snackbar('Error', 'No user logged in');
        return;
      }

      // Import and test API service directly
      final apiService = Get.find<ApiService>();

      print('🧪 Direct API test starting...');
      final books = await apiService.getBooks(userId: currentUser.code);
      print('🧪 Direct API test result: ${books.length} books');

      Get.snackbar(
        'API Test Result',
        'Found ${books.length} books',
        duration: Duration(seconds: 3),
      );
    } catch (e) {
      print('🧪 Direct API test failed: $e');
      Get.snackbar(
        'API Test Failed',
        e.toString(),
        duration: Duration(seconds: 5),
      );
    }
  }
}
