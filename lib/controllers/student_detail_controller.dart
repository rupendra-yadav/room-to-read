import 'package:get/get.dart';
import 'package:room_to_read/services/hybrid_api_service.dart';

class StudentDetailController extends GetxController {
  late HybridApiService apiService;

  var studentDetails = Rxn<Map<String, dynamic>>();
  var isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    apiService = Get.find<HybridApiService>();
  }

  Future<void> fetchStudentDetails(String studentCode) async {
    try {
      isLoading.value = true;
      print('Using student details from list - data already available');
      // Student details are already available from the students list
      // The list includes M1_TXT1 (previous level) and M1_TXT2 (current level)
      studentDetails.value = null;
    } catch (e) {
      print('Error loading student details: $e');
      studentDetails.value = null;
    } finally {
      isLoading.value = false;
    }
  }
}
