import 'package:get/get.dart';
import 'package:room_to_read/controllers/books_controller.dart';
import 'package:room_to_read/services/api_service.dart';


class BooksBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ApiService>(() => ApiService());
    Get.lazyPut<BooksController>(() => BooksController());
  }
}
