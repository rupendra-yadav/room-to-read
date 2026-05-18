import 'package:get/get.dart';
import 'package:room_to_read/controllers/checkout_controller.dart';
import 'package:room_to_read/controllers/student_controller.dart';
import 'package:room_to_read/controllers/book_controller.dart';
import 'package:room_to_read/services/api_service.dart';

class CheckoutBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ApiService>(() => ApiService());
    Get.lazyPut<CheckoutController>(() => CheckoutController());
    Get.lazyPut<StudentController>(() => StudentController());
    Get.lazyPut<BookController>(() => BookController());
  }
}
