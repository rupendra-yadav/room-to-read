import 'package:get/get.dart';
import 'package:room_to_read/services/hybrid_api_service.dart';

class BookDetailController extends GetxController {
  late HybridApiService apiService;

  var bookDetails = Rxn<Map<String, dynamic>>();
  var isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    apiService = Get.find<HybridApiService>();
  }

  Future<void> fetchBookDetails(String bookCode) async {
    try {
      isLoading.value = true;
      final details = await apiService.getBookDetails(bookCode);
      bookDetails.value = details.cast<String, dynamic>();
      print('Book details loaded: $details');
    } catch (e) {
      print('Error loading book details: $e');
      Get.snackbar('Error', 'Failed to load book details: $e');
    } finally {
      isLoading.value = false;
    }
  }
}
