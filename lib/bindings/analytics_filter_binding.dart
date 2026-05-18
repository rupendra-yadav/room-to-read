import 'package:get/get.dart';
import 'package:room_to_read/controllers/analytics_filter_controller.dart';

class AnalyticsFilterBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AnalyticsFilterController>(() => AnalyticsFilterController());
  }
}