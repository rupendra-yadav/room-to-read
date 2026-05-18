import 'package:get/get.dart';
import 'package:room_to_read/models/user_model.dart';
import 'package:room_to_read/services/auth_service.dart';


class ProfileController extends GetxController {
  final AuthService _authService = Get.find<AuthService>();
  
  Rx<UserModel?> get user => _authService.currentUser;

  Future<void> logout() async {
    await _authService.logout();
    Get.offAllNamed('/login');
  }
}
