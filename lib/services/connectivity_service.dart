import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

class ConnectivityService extends GetxService {
  final Connectivity _connectivity = Connectivity();
  final RxBool isOnline = true.obs;
  final RxString connectionType = 'unknown'.obs;

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  @override
  void onInit() {
    super.onInit();
    _initConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
  }

  @override
  void onClose() {
    _connectivitySubscription?.cancel();
    super.onClose();
  }

  Future<void> _initConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      print('❌ Error checking connectivity: $e');
      isOnline.value = false;
    }
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        isOnline.value = true;
        connectionType.value = 'wifi';
        print('📶 Connected via WiFi');
        break;
      case ConnectivityResult.mobile:
        isOnline.value = true;
        connectionType.value = 'mobile';
        print('📱 Connected via Mobile Data');
        break;
      case ConnectivityResult.ethernet:
        isOnline.value = true;
        connectionType.value = 'ethernet';
        print('🔌 Connected via Ethernet');
        break;
      case ConnectivityResult.none:
        isOnline.value = false;
        connectionType.value = 'none';
        print('❌ No internet connection');
        break;
      default:
        isOnline.value = false;
        connectionType.value = 'unknown';
        print('❓ Unknown connection status');
    }

    // Show snackbar when connection status changes
    if (isOnline.value) {
      Get.snackbar(
        'कनेक्शन बहाल',
        'इंटरनेट कनेक्शन उपलब्ध है। ऑफलाइन सिंक सक्रिय करने के लिए बटन दबाएं।',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 3),
      );

      // ✅ CHANGED: No longer auto-sync when connection restored
      // User must manually tap the "ऑफलाइन सिंक" button to sync
    } else {
      Get.snackbar(
        'ऑफलाइन मोड',
        'इंटरनेट कनेक्शन नहीं है - ऑफलाइन मोड में काम कर रहे हैं',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 3),
      );
    }
  }

  Future<bool> hasInternetConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      print('❌ Error checking internet connection: $e');
      return false;
    }
  }
}
