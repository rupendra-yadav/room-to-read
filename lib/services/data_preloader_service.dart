import 'package:get/get.dart';
import 'package:room_to_read/services/auth_service.dart';
import 'package:room_to_read/services/connectivity_service.dart';
import 'package:room_to_read/services/hybrid_api_service.dart';
import 'package:room_to_read/services/offline_database_service.dart';

class DataPreloaderService extends GetxService {
  final AuthService _authService = Get.find<AuthService>();
  final ConnectivityService _connectivityService =
      Get.find<ConnectivityService>();
  final HybridApiService _hybridApiService = Get.find<HybridApiService>();
  final OfflineDatabaseService _offlineDb = Get.find<OfflineDatabaseService>();

  final RxBool isPreloading = false.obs;
  final RxString preloadStatus = ''.obs;
  final RxInt preloadProgress = 0.obs;

  @override
  void onInit() {
    super.onInit();

    // NOTE: Removed automatic preload on login and connectivity changes
    // Users should manually tap the sync button to download data
    // This prevents unwanted API calls when coming online

    // Listen for user login (but don't auto-sync)
    ever(_authService.isLoggedIn, (isLoggedIn) {
      print('🔐 User login status changed: $isLoggedIn');
      // Preload is now manual only - user must tap the sync button
    });

    // Listen for connection changes (but don't auto-sync)
    ever(_connectivityService.isOnline, (isOnline) {
      print('🌐 Connectivity changed: ${isOnline ? "Online" : "Offline"}');
      // Preload is now manual only - user must tap the sync button
    });
  }

  Future<void> preloadAllData() async {
    if (isPreloading.value) return; // Already preloading

    try {
      isPreloading.value = true;
      preloadProgress.value = 0;

      final currentUser = _authService.currentUser.value;
      if (currentUser == null) return;

      final teacherId = currentUser.code;
      final userId = currentUser.code;

      print('🔄 Starting data preload for user: $teacherId');

      // Step 1: Preload students (25%)
      preloadStatus.value = 'छात्र डेटा लोड हो रहा है...';
      try {
        await _hybridApiService.getStudents(group1: teacherId);
        preloadProgress.value = 25;
        print('✅ Students preloaded');
      } catch (e) {
        print('⚠️ Students preload failed: $e');
      }

      // Step 2: Preload books (50%)
      preloadStatus.value = 'किताबों का डेटा लोड हो रहा है...';
      try {
        await _hybridApiService.getBooks(userId: userId);
        preloadProgress.value = 50;
        print('✅ Books preloaded');
      } catch (e) {
        print('⚠️ Books preload failed: $e');
      }

      // Step 3: Preload classes (65%)
      preloadStatus.value = 'कक्षाओं का डेटा लोड हो रहा है...';
      try {
        await _hybridApiService.getClasses();
        preloadProgress.value = 65;
        print('✅ Classes preloaded');
      } catch (e) {
        print('⚠️ Classes preload failed: $e');
      }

      // Step 4: Preload checked out books (100%)
      preloadStatus.value = 'जारी किताबों का डेटा लोड हो रहा है...';
      try {
        await _hybridApiService.getCheckedOutBooks(teacherId: teacherId);
        preloadProgress.value = 100;
        print('✅ Checked out books preloaded');
      } catch (e) {
        print('⚠️ Checked out books preload failed: $e');
      }

      // Complete (100%)
      preloadProgress.value = 100;
      preloadStatus.value = 'डेटा लोड पूरा हुआ';

      print('🎉 Data preload completed successfully');

      // Show success message
      Get.snackbar(
        'डेटा तैयार',
        'सभी डेटा ऑफलाइन उपयोग के लिए तैयार है',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      print('❌ Error during data preload: $e');
      preloadStatus.value = 'डेटा लोड में त्रुटि';
    } finally {
      isPreloading.value = false;

      // Clear status after a delay
      Future.delayed(const Duration(seconds: 3), () {
        preloadStatus.value = '';
        preloadProgress.value = 0;
      });
    }
  }

  Future<void> forcePreloadAllData() async {
    isPreloading.value = false; // Reset flag
    await preloadAllData();
  }

  Future<Map<String, dynamic>> getPreloadStats() async {
    final stats = await _offlineDb.getOfflineStats();

    return {
      'isPreloading': isPreloading.value,
      'preloadStatus': preloadStatus.value,
      'preloadProgress': preloadProgress.value,
      'cachedStudents': stats['students'] ?? 0,
      'cachedBooks': stats['books'] ?? 0,
      'cachedClasses': stats['classes'] ?? 0,
      'cachedCheckedOutBooks': stats['checkedOutBooks'] ?? 0,
      'lastPreloadTime': DateTime.now().toIso8601String(),
    };
  }
}
