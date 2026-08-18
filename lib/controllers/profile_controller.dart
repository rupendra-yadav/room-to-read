import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:room_to_read/controllers/offline_sync_controller.dart';
import 'package:room_to_read/models/user_model.dart';
import 'package:room_to_read/services/auth_service.dart';
import 'package:room_to_read/services/offline_database_service.dart';


class ProfileController extends GetxController {
  final AuthService _authService = Get.find<AuthService>();
  final OfflineDatabaseService _offlineDb = Get.find<OfflineDatabaseService>();

  Rx<UserModel?> get user => _authService.currentUser;

  Future<void> logout() async {
    await _authService.logout();
    Get.offAllNamed('/login');
  }

  /// Pushes any pending offline changes and re-downloads all data (students,
  /// books, classes, checked-out books) so the app is fully up to date for
  /// offline use. Reuses OfflineSyncController.syncOfflineData(), which
  /// already shows its own progress dialog and success/error snackbar.
  Future<void> resyncAllData() async {
    final syncController = Get.isRegistered<OfflineSyncController>()
        ? Get.find<OfflineSyncController>()
        : Get.put(OfflineSyncController());
    await syncController.syncOfflineData();
  }

  /// Permanently wipes every locally cached table (pending transactions AND
  /// downloaded students/books/classes/etc), then logs the user out. This
  /// is destructive and irreversible, so it warns explicitly — and warns
  /// harder if there's unsynced data that would be lost.
  Future<void> deleteAllDataAndLogout() async {
    final stats = await _offlineDb.getOfflineStats();
    final pendingCount =
        (stats['pendingTransactions'] as int? ?? 0) +
        (stats['pendingReadingLevelUpdates'] as int? ?? 0);

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('सभी डेटा हटाएं और लॉगआउट करें'),
        content: Text(
          pendingCount > 0
              ? 'आपके पास $pendingCount बिना सिंक किए हुए बदलाव हैं। '
                    'यह क्रिया सभी ऑफलाइन डेटा (छात्र, किताबें, कक्षाएं, और '
                    'बिना सिंक किए बदलाव) स्थायी रूप से हटा देगी और आपको '
                    'लॉगआउट कर देगी। यह क्रिया पूर्ववत नहीं की जा सकती।'
              : 'यह क्रिया सभी ऑफलाइन डेटा (छात्र, किताबें, कक्षाएं) स्थायी '
                    'रूप से हटा देगी और आपको लॉगआउट कर देगी। यह क्रिया '
                    'पूर्ववत नहीं की जा सकती।',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('रद्द करें'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('हटाएं और लॉगआउट करें'),
          ),
        ],
      ),
      barrierDismissible: false,
    );

    if (confirmed != true) return;

    try {
      await _offlineDb.wipeAllOfflineData();
    } catch (e) {
      Get.snackbar(
        'त्रुटि',
        'डेटा हटाने में त्रुटि: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    await _authService.logout();
    Get.offAllNamed('/login');
  }
}
