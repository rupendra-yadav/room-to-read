import 'package:get/get.dart';
import 'package:room_to_read/controllers/analysis_controller.dart';
import 'package:room_to_read/services/api_service.dart';

class AnalysisBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ApiService>(() => ApiService());
    Get.lazyPut<AnalysisController>(() => AnalysisController());
  }
}
