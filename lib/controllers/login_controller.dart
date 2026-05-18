import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:room_to_read/services/auth_service.dart';
import 'package:room_to_read/utils/debug_helper.dart';

class LoginController extends GetxController {
  final AuthService _authService = Get.find<AuthService>();
  final mobileController = TextEditingController();
  final passwordController = TextEditingController();

  final obscurePassword = true.obs;
  final isLoading = false.obs;
  final mobileError = ''.obs;
  final mobileText = ''.obs; // Add reactive mobile text

  @override
  void onInit() {
    super.onInit();
    // Listen to mobile number changes for real-time validation
    mobileController.addListener(() {
      mobileText.value = mobileController.text; // Update reactive text
      validateMobileNumber(mobileController.text);
    });
  }

  void validateMobileNumber(String value) {
    if (value.isEmpty) {
      mobileError.value = '';
    } else if (value.length < 10) {
      mobileError.value = 'Mobile number must be 10 digits';
    } else if (value.length == 10) {
      // Check if it's a valid Indian mobile number (starts with 6, 7, 8, or 9)
      if (RegExp(r'^[6-9][0-9]{9}$').hasMatch(value)) {
        mobileError.value = '';
      } else {
        mobileError.value = 'Invalid mobile number format';
      }
    } else {
      mobileError.value = 'Mobile number cannot exceed 10 digits';
    }
  }

  bool isValidMobileNumber(String mobile) {
    return mobile.length == 10 && RegExp(r'^[6-9][0-9]{9}$').hasMatch(mobile);
  }

  void togglePasswordVisibility() {
    obscurePassword.value = !obscurePassword.value;
  }

  Future<void> login() async {
    final mobile = mobileController.text.trim();
    final password = passwordController.text.trim();

    // Validate mobile number
    if (mobile.isEmpty) {
      Get.snackbar(
        'Error',
        'Please enter mobile number',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[400],
        colorText: Colors.white,
      );
      return;
    }

    if (!isValidMobileNumber(mobile)) {
      Get.snackbar(
        'Error',
        'Please enter a valid 10-digit mobile number',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[400],
        colorText: Colors.white,
      );
      return;
    }

    if (password.isEmpty) {
      Get.snackbar(
        'Error',
        'Please enter password',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[400],
        colorText: Colors.white,
      );
      return;
    }

    isLoading.value = true;

    try {
      DebugHelper.logAuth('Starting login process...');

      final success = await _authService.login(mobile, password);

      if (success) {
        DebugHelper.logAuth('Login successful, navigating to home...');
        Get.snackbar(
          'Success',
          'Login successful',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green[400],
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
        // Use a delay to ensure the snackbar shows
        await Future.delayed(const Duration(milliseconds: 500));
        Get.offAllNamed('/');
      } else {
        DebugHelper.logError('Login failed');
        Get.snackbar(
          'Login Failed',
          'Invalid mobile number or password. Please check your credentials and try again.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red[400],
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      DebugHelper.logError('Login exception: $e', exception: e);

      String errorMessage = 'An error occurred during login. Please try again.';
      String title = 'Login Error';

      // Handle specific network errors with helpful guidance
      if (e.toString().contains('Network connection failed') ||
          e.toString().contains('Cannot connect to server') ||
          e.toString().contains('Failed host lookup')) {
        title = 'Network Issue';
        errorMessage =
            'Cannot connect to server. Try:\n'
            '• Check internet connection\n'
            '• Switch between WiFi and mobile data';
      } else if (e.toString().contains('timed out')) {
        title = 'Connection Timeout';
        errorMessage =
            'Connection timed out. Your internet might be slow.\n'
            'Please try again.';
      } else if (e.toString().contains('Invalid server response')) {
        title = 'Server Error';
        errorMessage =
            'Server returned invalid response. The server might be under maintenance.\n'
            'Please try again later.';
      }

      Get.snackbar(
        title,
        errorMessage,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange[600],
        colorText: Colors.white,
        duration: const Duration(seconds: 8),
        maxWidth: 400,
      );
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    mobileController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
