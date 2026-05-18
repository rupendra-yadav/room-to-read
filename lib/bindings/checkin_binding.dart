import 'package:get/get.dart';
import 'package:room_to_read/controllers/checkin_controller.dart';
import 'package:room_to_read/controllers/student_controller.dart';
import 'package:room_to_read/services/api_service.dart';

class CheckinBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ApiService>(() => ApiService());
    Get.lazyPut<StudentController>(() => StudentController());
    // Use put instead of lazyPut to ensure controller is created immediately
    // and data is refreshed each time the page is accessed
    Get.put<CheckinController>(CheckinController(), permanent: false);
  }
}
