import 'package:get/get.dart';
import 'package:room_to_read/controllers/cico_report_controller.dart';
import 'package:room_to_read/services/api_service.dart';

class ReportBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ApiService>(() => ApiService());
    Get.lazyPut<CicoReportController>(() => CicoReportController());
  }
}
