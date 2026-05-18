import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:get/get.dart';
import 'package:room_to_read/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:room_to_read/config/api_config.dart';
import 'package:room_to_read/utils/debug_helper.dart';
import 'package:room_to_read/services/offline_database_service.dart';

class AuthService extends GetxService {
  static const String _isLoggedInKey = 'isLoggedIn';
  static const String _userDataKey = 'userData';

  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  final RxBool isLoggedIn = false.obs;

  Future<AuthService> init() async {
    try {
      print('🔐 Initializing AuthService...');
      await checkLoginStatus().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('⚠️ Auth check timed out, defaulting to logged out');
          isLoggedIn.value = false;
          return;
        },
      );
      print('✅ AuthService initialized successfully');
    } catch (e) {
      print('❌ Error in auth init: $e');
      isLoggedIn.value = false;
      currentUser.value = null;
    }
    return this;
  }

  Future<void> checkLoginStatus() async {
    try {
      DebugHelper.logAuth('Checking login status...');
      final prefs = await SharedPreferences.getInstance();
      final storedLoginStatus = prefs.getBool(_isLoggedInKey) ?? false;
      isLoggedIn.value = storedLoginStatus;
      DebugHelper.logAuth('Login status: ${isLoggedIn.value}');

      if (isLoggedIn.value) {
        final userDataString = prefs.getString(_userDataKey);
        if (userDataString != null && userDataString.isNotEmpty) {
          try {
            final userData = json.decode(userDataString);
            currentUser.value = UserModel.fromJson(userData);
            DebugHelper.logAuth('User loaded: ${currentUser.value?.name}');
          } catch (jsonError) {
            DebugHelper.logError('Error parsing stored user data: $jsonError');
            // Clear corrupted data
            await prefs.remove(_userDataKey);
            await prefs.remove(_isLoggedInKey);
            isLoggedIn.value = false;
            currentUser.value = null;
          }
        } else {
          // Try to load from offline database as fallback
          try {
            DebugHelper.logAuth(
              'Attempting to load user from offline database...',
            );
            final offlineDb = Get.find<OfflineDatabaseService>();
            final cachedUser = await offlineDb.getCachedUserProfile();

            if (cachedUser != null) {
              currentUser.value = UserModel.fromJson(cachedUser);
              DebugHelper.logAuth(
                'User restored from offline database: ${currentUser.value?.name}',
              );

              // Restore to SharedPreferences
              await prefs.setBool(_isLoggedInKey, true);
              await prefs.setString(_userDataKey, json.encode(cachedUser));
            } else {
              DebugHelper.logAuth(
                'No user data found in offline database either, logging out',
              );
              isLoggedIn.value = false;
              await prefs.remove(_isLoggedInKey);
            }
          } catch (offlineError) {
            DebugHelper.logAuth(
              'Could not load from offline database: $offlineError',
            );
            isLoggedIn.value = false;
            await prefs.remove(_isLoggedInKey);
          }
        }
      }
    } catch (e) {
      DebugHelper.logError('Error checking login status: $e');
      isLoggedIn.value = false;
      currentUser.value = null;
    }
  }

  Future<bool> login(String mobile, String password) async {
    try {
      DebugHelper.logAuth('Attempting login...');
      DebugHelper.logAuth('Mobile: $mobile');
      DebugHelper.logNetwork('URL: ${ApiConfig.loginUrl}');

      // Add timeout to prevent hanging
      final response = await http
          .post(
            Uri.parse(ApiConfig.loginUrl),
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'Accept': 'application/json',
            },
            body: {'user_mobile': mobile, 'user_pswd': password},
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              DebugHelper.logError('Login request timed out');
              throw Exception(
                'Login request timed out. Please check your internet connection.',
              );
            },
          );

      DebugHelper.logNetwork('Login response status: ${response.statusCode}');
      DebugHelper.logNetwork('Login response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['response'] == 'success') {
          DebugHelper.logAuth('Login successful!');

          // Check if data array exists and has content
          if (data['data'] == null || data['data'].isEmpty) {
            DebugHelper.logError('No user data in login response');
            return false;
          }

          final userId = data['data'][0]['M1_CODE'];
          if (userId == null || userId.toString().isEmpty) {
            DebugHelper.logError('No user ID in login response');
            return false;
          }

          DebugHelper.logAuth('User ID: $userId');

          // Get user details
          final userDetailsResponse = await http
              .post(
                Uri.parse(ApiConfig.userDetailsUrl),
                headers: {
                  'Content-Type': 'application/x-www-form-urlencoded',
                  'Accept': 'application/json',
                },
                body: {'user_id': userId.toString()},
              )
              .timeout(
                const Duration(seconds: 15),
                onTimeout: () {
                  DebugHelper.logError('User details request timed out');
                  throw Exception('User details request timed out');
                },
              );

          DebugHelper.logNetwork(
            'User details response status: ${userDetailsResponse.statusCode}',
          );
          DebugHelper.logNetwork(
            'User details response body: ${userDetailsResponse.body}',
          );

          if (userDetailsResponse.statusCode == 200) {
            final userDetailsData = json.decode(userDetailsResponse.body);

            if (userDetailsData['response'] == 'success' &&
                userDetailsData['data'] != null &&
                userDetailsData['data'].isNotEmpty) {
              final user = UserModel.fromJson(userDetailsData['data'][0]);
              currentUser.value = user;
              DebugHelper.logAuth(
                'User model created: ${user.name} (${user.code})',
              );

              // Save login state
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool(_isLoggedInKey, true);
                final userJson = json.encode(user.toJson());
                await prefs.setString(_userDataKey, userJson);
                DebugHelper.logAuth('User data saved to SharedPreferences');

                // Also save to offline database for better offline experience
                try {
                  final offlineDb = Get.find<OfflineDatabaseService>();
                  await offlineDb.saveUserProfileOffline(user.toJson());
                  await offlineDb.saveCacheMetadata(
                    'last_login_user',
                    user.code,
                    'user_code',
                  );
                } catch (e) {
                  DebugHelper.logAuth('Note: Could not save to offline DB: $e');
                }

                isLoggedIn.value = true;
                DebugHelper.logAuth('Login complete!');
                return true;
              } catch (e) {
                DebugHelper.logError('Error saving user data: $e');
                // Even if saving fails, still log the user in for this session
                isLoggedIn.value = true;
                return true;
              }
            } else {
              DebugHelper.logError(
                'Invalid user details response: ${userDetailsData['message'] ?? 'No user data'}',
              );
            }
          } else {
            DebugHelper.logError(
              'User details HTTP error: ${userDetailsResponse.statusCode}',
            );
          }
        } else {
          DebugHelper.logError(
            'Login failed: ${data['message'] ?? 'Invalid credentials'}',
          );
        }
      } else {
        DebugHelper.logError('Login HTTP error: ${response.statusCode}');
        DebugHelper.logError('Response body: ${response.body}');
      }
      return false;
    } on SocketException catch (e) {
      DebugHelper.logError('Network error: $e', exception: e);
      DebugHelper.logNetwork('This appears to be a network connectivity issue');
      throw Exception(
        'Network connection failed. Please check your internet connection and try again.',
      );
    } on FormatException catch (e) {
      DebugHelper.logError('JSON parsing error: $e', exception: e);
      throw Exception('Invalid server response. Please try again.');
    } on TimeoutException catch (e) {
      DebugHelper.logError('Timeout error: $e', exception: e);
      throw Exception(
        'Request timed out. Please check your internet connection and try again.',
      );
    } catch (e) {
      DebugHelper.logError('Login error: $e', exception: e);

      // Check if it's a specific network error
      if (e.toString().contains('Failed host lookup') ||
          e.toString().contains('No address associated with hostname')) {
        throw Exception(
          'Cannot connect to server. Please check your internet connection and try again.',
        );
      }

      throw Exception('Login failed: ${e.toString()}');
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_isLoggedInKey);
    await prefs.remove(_userDataKey);

    currentUser.value = null;
    isLoggedIn.value = false;
  }
}
