import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:room_to_read/controllers/book_controller.dart'
    show BookController;
import 'package:room_to_read/controllers/checkin_controller.dart';
import 'package:room_to_read/controllers/student_controller.dart';
import 'package:room_to_read/services/auth_service.dart';
import 'package:room_to_read/services/connectivity_service.dart';
import 'package:room_to_read/services/offline_database_service.dart';
import 'package:room_to_read/services/offline_sync_service.dart';

class OfflineSyncController extends GetxController {
  final ConnectivityService _connectivityService =
      Get.find<ConnectivityService>();
  final OfflineDatabaseService _offlineDb = Get.find<OfflineDatabaseService>();
  final OfflineSyncService _syncService = Get.find<OfflineSyncService>();
  final AuthService _authService = Get.find<AuthService>();

  final TextEditingController apiKeyController = TextEditingController();

  // Observable variables
  final RxBool isOnline = false.obs;
  final RxString connectionType = 'unknown'.obs;
  final RxInt offlineStudents = 0.obs;
  final RxInt offlineBooks = 0.obs;
  final RxInt offlineClasses = 0.obs;
  final RxInt checkedOutBooks = 0.obs;
  final RxInt pendingTransactions = 0.obs;
  final RxInt pendingSyncItems = 0.obs;
  final RxInt pendingReadingLevelUpdates = 0.obs;
  final RxBool isSyncing = false.obs;
  final RxInt syncProgress = 0.obs;
  final RxString syncStatus = ''.obs;
  final RxList<Map<String, dynamic>> offlineTransactions =
      <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    _bindConnectivityService();
    _bindSyncService();
    loadOfflineStats();
    loadOfflineTransactions();
  }

  void _bindConnectivityService() {
    // Bind connectivity status
    isOnline.bindStream(_connectivityService.isOnline.stream);
    connectionType.bindStream(_connectivityService.connectionType.stream);
  }

  void _bindSyncService() {
    // Bind sync service status
    isSyncing.bindStream(_syncService.isSyncing.stream);
    syncProgress.bindStream(_syncService.syncProgress.stream);
    syncStatus.bindStream(_syncService.syncStatus.stream);
  }

  Future<void> loadOfflineStats() async {
    try {
      final stats = await _syncService.getSyncStats();

      offlineStudents.value = stats['offlineStudents'] ?? 0;
      offlineBooks.value = stats['offlineBooks'] ?? 0;
      offlineClasses.value = stats['offlineClasses'] ?? 0;
      checkedOutBooks.value = stats['checkedOutBooks'] ?? 0;
      pendingTransactions.value = stats['pendingTransactions'] ?? 0;
      pendingSyncItems.value = stats['pendingSyncItems'] ?? 0;
      pendingReadingLevelUpdates.value =
          stats['pendingReadingLevelUpdates'] ?? 0;

      print('📊 Offline stats loaded: $stats');
    } catch (e) {
      print('❌ Error loading offline stats: $e');
    }
  }

  Future<void> loadOfflineTransactions() async {
    try {
      final transactions = await _offlineDb.getOfflineTransactions();
      offlineTransactions.value = transactions;
      print('📋 Loaded ${transactions.length} offline transactions');
    } catch (e) {
      print('❌ Error loading offline transactions: $e');
    }
  }

  Future<void> downloadFreshData() async {
    if (!isOnline.value) {
      Get.snackbar(
        'ऑफलाइन',
        'डेटा डाउनलोड के लिए इंटरनेट कनेक्शन चाहिए',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      final teacherId = _authService.currentUser.value?.code;
      final userId = _authService.currentUser.value?.code;

      final result = await _syncService.downloadFreshData(
        teacherId: teacherId,
        userId: userId,
      );

      Get.back(); // Close loading dialog

      if (result['success']) {
        Get.snackbar(
          'सफल',
          result['message'],
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );

        // Refresh stats
        await loadOfflineStats();

        // Also refresh the controllers to show new data
        try {
          final bookController = Get.find<BookController>();
          await bookController.loadBooks();

          final studentController = Get.find<StudentController>();
          await studentController.loadStudents();

          print('✅ Controllers refreshed after data download');
        } catch (e) {
          print('⚠️ Could not refresh controllers: $e');
        }
      } else {
        Get.snackbar(
          'त्रुटि',
          result['message'],
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.back(); // Close loading dialog
      Get.snackbar(
        'त्रुटि',
        'डेटा डाउनलोड में त्रुटि: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Method to manually download and cache all data
  Future<void> manualDataDownload() async {
    if (!isOnline.value) {
      Get.snackbar(
        'ऑफलाइन',
        'डेटा डाउनलोड के लिए इंटरनेट कनेक्शन चाहिए',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      Get.dialog(
        AlertDialog(
          title: Text('डेटा डाउनलोड'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('सभी डेटा डाउनलोड हो रहा है...'),
            ],
          ),
        ),
        barrierDismissible: false,
      );

      print('🔄 Starting manual data download...');

      // Download books
      try {
        final bookController = Get.find<BookController>();
        await bookController.downloadAndCacheData();
      } catch (e) {
        print('❌ Error downloading books: $e');
      }

      // Download students
      try {
        final studentController = Get.find<StudentController>();
        await studentController.downloadAndCacheData();
      } catch (e) {
        print('❌ Error downloading students: $e');
      }

      // Download other data using sync service
      final teacherId = _authService.currentUser.value?.code;
      if (teacherId != null) {
        try {
          final result = await _syncService.downloadFreshData(
            teacherId: teacherId,
            userId: teacherId,
          );
          print('📊 Sync service download result: $result');
        } catch (e) {
          print('❌ Error with sync service download: $e');
        }
      }

      Get.back(); // Close loading dialog

      // Refresh stats
      await loadOfflineStats();

      Get.snackbar(
        'सफल',
        'सभी डेटा सफलतापूर्वक डाउनलोड हो गया',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );

      print('✅ Manual data download completed');
    } catch (e) {
      Get.back(); // Close loading dialog
      Get.snackbar(
        'त्रुटि',
        'डेटा डाउनलोड में त्रुटि: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      print('❌ Error in manual data download: $e');
    }
  }

  // Enhanced offline sync - syncs all pending data and downloads fresh data
  Future<void> syncOfflineData() async {
    if (!isOnline.value) {
      Get.snackbar(
        'ऑफलाइन',
        'सिंक के लिए इंटरनेट कनेक्शन चाहिए',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      // Show progress dialog
      Get.dialog(
        AlertDialog(
          title: Text('ऑफलाइन सिंक'),
          content: Obx(
            () => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  syncStatus.value.isNotEmpty
                      ? syncStatus.value
                      : 'सिंक शुरू हो रहा है...',
                ),
                if (syncProgress.value > 0) ...[
                  SizedBox(height: 8),
                  LinearProgressIndicator(value: syncProgress.value / 100),
                  SizedBox(height: 4),
                  Text('${syncProgress.value}% पूरा'),
                ],
              ],
            ),
          ),
        ),
        barrierDismissible: false,
      );

      // Use the new enhanced sync method that handles both pending transactions and fresh data
      final result = await _syncService.syncAllOfflineData();

      Get.back(); // Close progress dialog

      if (result['success']) {
        Get.snackbar(
          'सिंक सफल',
          result['message'],
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: Duration(seconds: 4),
        );

        // Refresh stats and transactions
        await loadOfflineStats();
        await loadOfflineTransactions();

        // ✅ NEW: Refresh checkin list to remove synced books
        try {
          if (Get.isRegistered<CheckinController>()) {
            final checkinController = Get.find<CheckinController>();
            print('🔄 Refreshing checkin list after successful sync...');
            await checkinController.refreshCheckedOutBooks();
            print('✅ Checkin list refreshed - synced books should be removed');
          }
        } catch (e) {
          print('⚠️ Error refreshing checkin list after sync: $e');
        }

        // Refresh controllers to show updated data
        try {
          final bookController = Get.find<BookController>();
          await bookController.loadBooks();

          final studentController = Get.find<StudentController>();
          await studentController.loadStudents();

          print('✅ Controllers refreshed after offline sync');
        } catch (e) {
          print('⚠️ Could not refresh controllers: $e');
        }
      } else {
        Get.snackbar(
          'सिंक असफल',
          result['message'],
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: Duration(seconds: 4),
        );
      }
    } catch (e) {
      Get.back(); // Close progress dialog if still open
      Get.snackbar(
        'त्रुटि',
        'सिंक में त्रुटि: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      print('❌ Error in offline sync: $e');
    }
  }

  // NEW: Simple bulk sync method for offline transactions only
  Future<void> bulkSyncOfflineTransactions() async {
    if (!isOnline.value) {
      Get.snackbar(
        'ऑफलाइन',
        'बल्क सिंक के लिए इंटरनेट कनेक्शन चाहिए',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      // Check if there are any pending transactions
      final stats = await _syncService.getSyncStats();
      final pendingCount = stats['pendingTransactions'] ?? 0;

      if (pendingCount == 0) {
        Get.snackbar(
          'कोई डेटा नहीं',
          'सिंक करने के लिए कोई ऑफलाइन ट्रांजैक्शन नहीं मिला',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.blue,
          colorText: Colors.white,
        );
        return;
      }

      // Show progress dialog
      Get.dialog(
        AlertDialog(
          title: Text('बल्क सिंक'),
          content: Obx(
            () => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  syncStatus.value.isNotEmpty
                      ? syncStatus.value
                      : '$pendingCount ट्रांजैक्शन सिंक हो रहे हैं...',
                ),
                if (syncProgress.value > 0) ...[
                  SizedBox(height: 8),
                  LinearProgressIndicator(value: syncProgress.value / 100),
                  SizedBox(height: 4),
                  Text('${syncProgress.value}% पूरा'),
                ],
              ],
            ),
          ),
        ),
        barrierDismissible: false,
      );

      // Sync only pending transactions using bulk APIs
      final result = await _syncService.syncAllPendingOfflineTransactions();

      Get.back(); // Close progress dialog

      if (result['success']) {
        final successCount = result['successCount'] ?? 0;
        final failureCount = result['failureCount'] ?? 0;

        String message = 'बल्क सिंक पूरा!';
        if (successCount > 0) {
          message += ' $successCount ट्रांजैक्शन सफल';
        }
        if (failureCount > 0) {
          message += ', $failureCount असफल';
        }

        Get.snackbar(
          'बल्क सिंक सफल',
          message,
          snackPosition: SnackPosition.TOP,
          backgroundColor: successCount > 0 ? Colors.green : Colors.orange,
          colorText: Colors.white,
          duration: Duration(seconds: 4),
        );

        // Refresh stats and transactions
        await loadOfflineStats();
        await loadOfflineTransactions();

        // Refresh checkin list to remove synced books
        try {
          if (Get.isRegistered<CheckinController>()) {
            final checkinController = Get.find<CheckinController>();
            print('🔄 Refreshing checkin list after bulk sync...');
            await checkinController.refreshCheckedOutBooks();
            print('✅ Checkin list refreshed after bulk sync');
          }
        } catch (e) {
          print('⚠️ Error refreshing checkin list after bulk sync: $e');
        }
      } else {
        Get.snackbar(
          'बल्क सिंक असफल',
          result['message'] ?? 'बल्क सिंक में त्रुटि',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: Duration(seconds: 4),
        );
      }
    } catch (e) {
      Get.back(); // Close progress dialog if still open
      Get.snackbar(
        'त्रुटि',
        'बल्क सिंक में त्रुटि: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      print('❌ Error in bulk sync: $e');
    }
  }

  Future<void> clearOfflineData() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('पुष्टि करें'),
        content: const Text(
          'क्या आप वाकई सभी ऑफलाइन डेटा साफ करना चाहते हैं? '
          'यह क्रिया पूर्ववत नहीं की जा सकती।',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('रद्द करें'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('साफ करें'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _offlineDb.clearOfflineData();

        Get.snackbar(
          'सफल',
          'सभी ऑफलाइन डेटा साफ कर दिया गया',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );

        // Refresh stats and transactions
        await loadOfflineStats();
        await loadOfflineTransactions();
      } catch (e) {
        Get.snackbar(
          'त्रुटि',
          'डेटा साफ करने में त्रुटि: $e',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  @override
  void onClose() {
    apiKeyController.dispose();
    super.onClose();
  }
}
