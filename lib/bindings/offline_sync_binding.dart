import 'package:get/get.dart';
import 'package:room_to_read/controllers/offline_sync_controller.dart';

class OfflineSyncBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<OfflineSyncController>(() => OfflineSyncController());
  }
}