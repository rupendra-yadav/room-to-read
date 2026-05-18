import 'package:get/get.dart';
import 'package:room_to_read/controllers/book_controller.dart';
import 'package:room_to_read/services/api_service.dart';

class BookBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ApiService>(() => ApiService());
    Get.lazyPut<BookController>(() => BookController());
  }
}
