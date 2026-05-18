import 'package:get/get.dart';
import 'package:room_to_read/controllers/student_controller.dart';
import 'package:room_to_read/services/api_service.dart';


class StudentBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ApiService>(() => ApiService());
    Get.lazyPut<StudentController>(() => StudentController());
  }
}
