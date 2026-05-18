import 'package:get/get.dart';
import 'package:room_to_read/services/hybrid_api_service.dart';
import 'package:room_to_read/services/auth_service.dart';

class HomeController extends GetxController {
  HybridApiService? _apiService;
  AuthService? _authService;
  
  var checkoutCount = 0.obs;
  var returnCount = 0.obs; // Remove hardcoded value
  var isLoading = false.obs;

  // Lazy getters for services with error handling
  HybridApiService get apiService {
    try {
      _apiService ??= Get.find<HybridApiService>();
      return _apiService!;
    } catch (e) {
      print('⚠️ HybridApiService not found in HomeController: $e');
      rethrow;
    }
  }

  AuthService get authService {
    try {
      _authService ??= Get.find<AuthService>();
      return _authService!;
    } catch (e) {
      print('⚠️ AuthService not found in HomeController: $e');
      rethrow;
    }
  }

  @override
  void onInit() {
    super.onInit();
    print('🏠 HomeController onInit called');
    // Use a delayed call to ensure services are available
    Future.delayed(Duration(milliseconds: 100), () {
      fetchBookIssueCounts();
    });
  }

  @override
  void onReady() {
    super.onReady();
    print('🏠 HomeController onReady called');
    // Ensure data is refreshed when controller is ready
    fetchBookIssueCounts();
  }

  Future<void> fetchBookIssueCounts() async {
    try {
      print('🔄 HomeController: Starting fetchBookIssueCounts');
      isLoading.value = true;
      
      // Get current user for teacher ID
      final currentUser = authService.currentUser.value;
      if (currentUser == null) {
        print('⚠️ No current user found for fetching book counts');
        returnCount.value = 0;
        checkoutCount.value = 0;
        return;
      }

      print('👤 HomeController: Current user: ${currentUser.code}');

      // Fetch both counts in parallel
      final results = await Future.wait([
        apiService.getBookIssueCount(currentUser.code),
        apiService.getCheckoutCount(currentUser.code),
      ]);
      
      final issueCount = results[0];
      final checkoutCountValue = results[1];
      
      print('📊 HomeController: Book issue count: $issueCount');
      print('📊 HomeController: Book checkout count: $checkoutCountValue');
      
      returnCount.value = issueCount;
      checkoutCount.value = checkoutCountValue;
      
      print('✅ Book counts updated - Issue: $issueCount, Checkout: $checkoutCountValue');
    } catch (e) {
      print('❌ Error fetching book counts: $e');
      returnCount.value = 0;
      checkoutCount.value = 0;
    } finally {
      isLoading.value = false;
      print('🏁 HomeController: fetchBookIssueCounts completed');
    }
  }

  void incrementCheckout() {
    checkoutCount.value++;
  }

  void incrementReturn() {
    returnCount.value++;
  }

  // Method to refresh counts (can be called after checkout/checkin operations)
  Future<void> refreshCounts() async {
    await fetchBookIssueCounts();
  }
}
