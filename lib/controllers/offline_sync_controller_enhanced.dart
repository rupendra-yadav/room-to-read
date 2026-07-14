import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:convert';
import 'package:room_to_read/controllers/checkin_controller.dart';
import 'package:room_to_read/controllers/home_controller.dart';
import 'package:room_to_read/services/connectivity_service.dart';
import 'package:room_to_read/services/offline_database_service.dart';
import 'package:room_to_read/services/offline_sync_service.dart';
import 'package:room_to_read/services/api_service.dart';

/// Enhanced Offline Sync Controller with better debugging and error handling
/// Ensures data is properly sent to the database via APIs
class OfflineSyncControllerEnhanced extends GetxController {
  final ConnectivityService _connectivityService =
      Get.find<ConnectivityService>();
  final OfflineDatabaseService _offlineDb = Get.find<OfflineDatabaseService>();
  final OfflineSyncService _syncService = Get.find<OfflineSyncService>();
  final ApiService _apiService = Get.find<ApiService>();

  // Observable variables
  final RxBool isOnline = false.obs;
  final RxString connectionType = 'unknown'.obs;
  final RxInt pendingTransactions = 0.obs;
  final RxBool isSyncing = false.obs;
  final RxInt syncProgress = 0.obs;
  final RxString syncStatus = ''.obs;
  final RxList<Map<String, dynamic>> syncLogs = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    _bindConnectivityService();
    _bindSyncService();
    loadPendingTransactions();
  }

  void _bindConnectivityService() {
    isOnline.bindStream(_connectivityService.isOnline.stream);
    connectionType.bindStream(_connectivityService.connectionType.stream);
  }

  void _bindSyncService() {
    isSyncing.bindStream(_syncService.isSyncing.stream);
    syncProgress.bindStream(_syncService.syncProgress.stream);
    syncStatus.bindStream(_syncService.syncStatus.stream);
  }

  Future<void> loadPendingTransactions() async {
    try {
      final transactions = await _offlineDb.getPendingOfflineTransactions();
      pendingTransactions.value = transactions.length;
      print('📊 Pending transactions: ${transactions.length}');
    } catch (e) {
      print('❌ Error loading pending transactions: $e');
    }
  }

  void _addSyncLog(String message, {bool isError = false}) {
    final log = {
      'message': message,
      'timestamp': DateTime.now().toString(),
      'isError': isError,
    };
    syncLogs.insert(0, log);
    print(message);
  }

  /// Enhanced bulk sync with detailed debugging
  Future<void> bulkSyncWithDebug() async {
    if (!isOnline.value) {
      _addSyncLog('❌ ऑफलाइन - सिंक के लिए इंटरनेट चाहिए', isError: true);
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
      _addSyncLog('🔄 बल्क सिंक शुरू हो रहा है...');

      // Step 1: Get pending transactions
      _addSyncLog('📋 Step 1: पेंडिंग ट्रांजैक्शन प्राप्त कर रहे हैं...');
      final pendingTransactions = await _offlineDb
          .getPendingOfflineTransactions();
      _addSyncLog('📊 कुल पेंडिंग: ${pendingTransactions.length}');

      if (pendingTransactions.isEmpty) {
        _addSyncLog('✅ कोई पेंडिंग ट्रांजैक्शन नहीं');
        Get.snackbar(
          'कोई डेटा नहीं',
          'सिंक करने के लिए कोई ऑफलाइन ट्रांजैक्शन नहीं',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.blue,
          colorText: Colors.white,
        );
        return;
      }

      // Show progress dialog
      Get.dialog(
        AlertDialog(
          title: const Text('बल्क सिंक'),
          content: Obx(
            () => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  syncStatus.value.isNotEmpty
                      ? syncStatus.value
                      : 'डेटा सिंक हो रहा है...',
                ),
                if (syncProgress.value > 0) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: syncProgress.value / 100),
                  const SizedBox(height: 4),
                  Text('${syncProgress.value}% पूरा'),
                ],
              ],
            ),
          ),
        ),
        barrierDismissible: false,
      );

      // Step 2: Separate checkout and checkin transactions
      _addSyncLog('📋 Step 2: ट्रांजैक्शन को अलग कर रहे हैं...');
      final checkoutTransactions = pendingTransactions
          .where((t) => t['transaction_type'] == 'checkout')
          .toList();
      final checkinTransactions = pendingTransactions
          .where((t) => t['transaction_type'] == 'checkin')
          .toList();

      _addSyncLog('   ✅ Checkouts: ${checkoutTransactions.length}');
      _addSyncLog('   ✅ Checkins: ${checkinTransactions.length}');

      int totalSynced = 0;
      int totalFailed = 0;

      // Step 3: Sync checkouts
      if (checkoutTransactions.isNotEmpty) {
        _addSyncLog('📤 Step 3: Checkouts सिंक कर रहे हैं...');
        final checkoutResult = await _syncBulkCheckouts(checkoutTransactions);
        totalSynced += checkoutResult['synced'] ?? 0;
        totalFailed += checkoutResult['failed'] ?? 0;
      }

      // Step 4: Sync checkins
      if (checkinTransactions.isNotEmpty) {
        _addSyncLog('📤 Step 4: Checkins सिंक कर रहे हैं...');
        final checkinResult = await _syncBulkCheckins(checkinTransactions);
        totalSynced += checkinResult['synced'] ?? 0;
        totalFailed += checkinResult['failed'] ?? 0;
      }

      Get.back(); // Close progress dialog

      // Final result
      _addSyncLog('✅ सिंक पूरा: $totalSynced सफल, $totalFailed असफल');

      if (totalSynced > 0) {
        Get.snackbar(
          'सिंक सफल',
          '$totalSynced ट्रांजैक्शन डेटाबेस में भेजे गए',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );

        // Refresh UI
        await loadPendingTransactions();

        // ✅ Refresh HomeController to update book issue counts
        try {
          if (Get.isRegistered<HomeController>()) {
            final homeController = Get.find<HomeController>();
            _addSyncLog('🔄 Refreshing HomeController after sync...');
            await homeController.fetchBookIssueCounts();
            _addSyncLog('✅ HomeController refreshed');
          }
        } catch (e) {
          _addSyncLog(
            '⚠️ HomeController रीफ्रेश में त्रुटि: $e',
            isError: true,
          );
        }

        try {
          if (Get.isRegistered<CheckinController>()) {
            final checkinController = Get.find<CheckinController>();
            await checkinController.refreshCheckedOutBooks();
          }
        } catch (e) {
          _addSyncLog('⚠️ UI रीफ्रेश में त्रुटि: $e', isError: true);
        }
      } else if (totalFailed > 0) {
        Get.snackbar(
          'सिंक असफल',
          '$totalFailed ट्रांजैक्शन असफल रहे',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      Get.back(); // Close progress dialog
      _addSyncLog('❌ सिंक में त्रुटि: $e', isError: true);
      Get.snackbar(
        'त्रुटि',
        'सिंक में त्रुटि: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Sync bulk checkouts with detailed debugging
  /// API expects: program_id, school_id, teacher_id, book_id, student_id, class
  Future<Map<String, int>> _syncBulkCheckouts(
    List<Map<String, dynamic>> checkoutTransactions,
  ) async {
    try {
      _addSyncLog(
        '🔄 ${checkoutTransactions.length} checkouts तैयार कर रहे हैं...',
      );

      // Prepare bulk data with correct field names for API
      final bulkRecords = <Map<String, dynamic>>[];
      for (final transaction in checkoutTransactions) {
        try {
          final rawData = transaction['raw_data'] as String?;
          if (rawData != null) {
            final data = jsonDecode(rawData);

            // Extract values with proper defaults
            final programId = data['program_id']?.toString() ?? '2014';
            final schoolId = data['school_id']?.toString() ?? '3898';
            final teacherId = data['teacher_id']?.toString() ?? '';
            final bookId = data['book_id']?.toString() ?? '';
            final bookCode = data['F4_LCODE']?.toString();
            final studentId = data['student_id']?.toString() ?? '';
            final className = data['class']?.toString() ?? '';

            print('📋 Raw checkout data from DB:');
            print('   book_id (M1_CODE): $bookId');
            print('   F4_LCODE (book_code): $bookCode');
            print('   teacher_id: $teacherId');
            print('   student_id: $studentId');
            print('   class: $className');

            _addSyncLog(
              '   📋 Record: teacher=$teacherId, book=$bookCode, student=$studentId',
            );

            bulkRecords.add({
              'F4_LCODE': bookCode, // ✅ CRITICAL: Book code for API
              'program_id': programId,
              'school_id': schoolId,
              'teacher_id': teacherId,
              'book_id': bookId,
              'student_id': studentId,
              'class': className,
            });
          }
        } catch (e) {
          _addSyncLog('⚠️ Checkout पार्स में त्रुटि: $e', isError: true);
        }
      }

      if (bulkRecords.isEmpty) {
        _addSyncLog('❌ कोई checkout डेटा तैयार नहीं हो सका', isError: true);
        return {'synced': 0, 'failed': checkoutTransactions.length};
      }

      _addSyncLog('📤 ${bulkRecords.length} checkouts API को भेज रहे हैं...');
      _addSyncLog('   Endpoint: /get_checkout_bulk');
      _addSyncLog(
        '   Fields: F4_LCODE, program_id, school_id, teacher_id, book_id, student_id, class',
      );
      _addSyncLog('   Sample: ${bulkRecords.first}');

      // Send to API
      final result = await _apiService.bulkSyncCheckout(bulkRecords);

      if (result['success'] == true) {
        final syncedCount = result['synced_count'] ?? bulkRecords.length;
        _addSyncLog('✅ Checkouts API सफल: $syncedCount सिंक');

        // Mark as synced in database
        for (final transaction in checkoutTransactions) {
          await _offlineDb.markOfflineTransactionSynced(
            transaction['transaction_id'],
          );
        }

        _addSyncLog('✅ Database में सभी checkouts को synced चिह्नित किया');
        return {'synced': syncedCount, 'failed': 0};
      } else {
        _addSyncLog(
          '❌ Checkouts API असफल: ${result['message']}',
          isError: true,
        );
        return {'synced': 0, 'failed': checkoutTransactions.length};
      }
    } catch (e) {
      _addSyncLog('❌ Checkout सिंक में त्रुटि: $e', isError: true);
      return {'synced': 0, 'failed': checkoutTransactions.length};
    }
  }

  /// Sync bulk checkins with detailed debugging
  Future<Map<String, int>> _syncBulkCheckins(
    List<Map<String, dynamic>> checkinTransactions,
  ) async {
    try {
      _addSyncLog(
        '🔄 ${checkinTransactions.length} checkins तैयार कर रहे हैं...',
      );

      // Prepare bulk data
      final bulkRecords = <Map<String, dynamic>>[];
      for (final transaction in checkinTransactions) {
        try {
          final rawData = transaction['raw_data'] as String?;
          if (rawData != null) {
            final data = jsonDecode(rawData);
            bulkRecords.add({
              'F4_BT': data['F4_BT'] ?? '2',
              'F4_LCODE': data['F4_LCODE'],
              'teacher_id': data['teacher_id'],
              'book_id': data['book_id'],
              'student_id': data['student_id'],
              'class': data['class'],
              'program_id': data['program_id'],
              'school_id': data['school_id'],
            });
          }
        } catch (e) {
          _addSyncLog('⚠️ Checkin पार्स में त्रुटि: $e', isError: true);
        }
      }

      if (bulkRecords.isEmpty) {
        _addSyncLog('❌ कोई checkin डेटा तैयार नहीं हो सका', isError: true);
        return {'synced': 0, 'failed': checkinTransactions.length};
      }

      _addSyncLog('📤 ${bulkRecords.length} checkins API को भेज रहे हैं...');
      _addSyncLog('   Endpoint: /get_checkin_bulk');
      _addSyncLog('   Data: ${bulkRecords.length} records');

      // Send to API
      final result = await _apiService.bulkSyncCheckin(bulkRecords);

      if (result['success'] == true) {
        final syncedCount = result['synced_count'] ?? bulkRecords.length;
        _addSyncLog('✅ Checkins API सफल: $syncedCount सिंक');

        // Mark as synced in database
        for (final transaction in checkinTransactions) {
          await _offlineDb.markCheckinSynced(
            transaction['transaction_id'],
            transaction,
          );
        }

        _addSyncLog('✅ Database में सभी checkins को synced चिह्नित किया');
        return {'synced': syncedCount, 'failed': 0};
      } else {
        _addSyncLog('❌ Checkins API असफल: ${result['message']}', isError: true);
        return {'synced': 0, 'failed': checkinTransactions.length};
      }
    } catch (e) {
      _addSyncLog('❌ Checkin सिंक में त्रुटि: $e', isError: true);
      return {'synced': 0, 'failed': checkinTransactions.length};
    }
  }

  /// View sync logs
  void showSyncLogs() {
    Get.dialog(
      AlertDialog(
        title: const Text('सिंक लॉग्स'),
        content: SizedBox(
          width: double.maxFinite,
          child: Obx(
            () => ListView.builder(
              itemCount: syncLogs.length,
              itemBuilder: (context, index) {
                final log = syncLogs[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${log['timestamp']}: ${log['message']}',
                    style: TextStyle(
                      color: log['isError'] ? Colors.red : Colors.black,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('बंद करें'),
          ),
        ],
      ),
    );
  }

  @override
  void onClose() {
    super.onClose();
  }
}
