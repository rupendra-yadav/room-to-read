import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

class DebugHelper {
  static void log(String message, {String? name}) {
    if (kDebugMode) {
      print(message);
    } else {
      // In release mode, use developer.log which can be viewed via adb logcat
      developer.log(message, name: name ?? 'RoomToRead');
    }
  }

  static void logError(String error, {String? name, Object? exception}) {
    if (kDebugMode) {
      print('❌ ERROR: $error');
      if (exception != null) {
        print('Exception: $exception');
      }
    } else {
      developer.log(
        '❌ ERROR: $error',
        name: name ?? 'RoomToRead',
        error: exception,
      );
    }
  }

  static void logNetwork(String message) {
    log('🌐 NETWORK: $message', name: 'Network');
  }

  static void logAuth(String message) {
    log('🔐 AUTH: $message', name: 'Auth');
  }
}
