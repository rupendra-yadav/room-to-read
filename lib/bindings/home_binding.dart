import 'package:get/get.dart';
import 'package:room_to_read/controllers/home_controller.dart';
import 'package:room_to_read/services/api_service.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    // Ensure ApiService is available
    if (!Get.isRegistered<ApiService>()) {
      Get.lazyPut<ApiService>(() => ApiService());
    }
    
    // Initialize HomeController with proper error handling
    try {
      Get.delete<HomeController>(force: true);
    } catch (e) {
      print('⚠️ HomeController not found for deletion: $e');
    }
    
    Get.put<HomeController>(HomeController(), permanent: true);
    print('✅ HomeController initialized in HomeBinding');
  }
}
