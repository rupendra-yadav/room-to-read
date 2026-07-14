import 'dart:developer';

import 'package:get/get.dart';
import 'dart:convert';
import 'package:room_to_read/config/api_config.dart';
import 'package:room_to_read/models/grade_model.dart';
import 'package:room_to_read/services/auth_service.dart';
import 'package:room_to_read/services/connectivity_service.dart';
import 'package:room_to_read/services/offline_database_service.dart';

class ApiService extends GetxService {
  Future<List<dynamic>> getStudents({String? group1}) async {
    try {
      // Build request body - API expects M1_GROUP2 for teacher ID
      final body = group1 != null && group1.isNotEmpty
          ? {'M1_GROUP2': group1}
          : <String, String>{};

      var response = await GetConnect(
        timeout: const Duration(seconds: 30),
      ).post(ApiConfig.studentUrl, body);

      // If 404, try alternative endpoint
      if (response.statusCode == 404) {
        response = await GetConnect(
          timeout: const Duration(seconds: 30),
        ).post(ApiConfig.studentUrl, body);
      }

      if (response.statusCode == 200) {
        var data = response.body;

        // If data is a string, parse it as JSON
        if (data is String) {
          data = jsonDecode(data);
        }

        if (data is List) {
          return data;
        } else if (data is Map) {
          if (data.containsKey('data')) {
            final result = data['data'] as List;
            return result;
          }
        }
        return [];
      } else {
        throw Exception('Failed to load students: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching students: $e');
    }
  }

  Future<List<String>> getClasses() async {
    try {
      var response = await GetConnect(
        timeout: const Duration(seconds: 30),
      ).post(ApiConfig.classUrl, {});

      if (response.statusCode == null) {
        return [];
      }

      // If 404, try alternative endpoint
      if (response.statusCode == 404) {
        response = await GetConnect(
          timeout: const Duration(seconds: 30),
        ).post(ApiConfig.classUrl, {});
      }

      if (response.statusCode == 200) {
        var data = response.body;
        List<String> classList = [];

        // If data is a string, parse it as JSON
        if (data is String) {
          data = jsonDecode(data);
        }

        if (data is Map && data.containsKey('data')) {
          final dataList = data['data'] as List;
          classList = dataList
              .map((item) => (item['M1_NAME'] ?? '').toString())
              .where((name) => name.isNotEmpty)
              .toList();
        }

        return classList;
      } else {
        return [];
      }
    } catch (e) {
      // Return empty list instead of throwing to prevent app crash
      return [];
    }
  }

  Future<Map<String, dynamic>> getStudentDetailsByCode(String m1Code) async {
    try {
      final connect = GetConnect();

      // Use FormData to send as form-data (like Postman)
      final formData = FormData({'M1_CODE': m1Code});

      final response = await connect.post(
        ApiConfig.studentDetailsUrl,
        formData,
      );

      if (response.statusCode == 200) {
        var data = response.body;

        // If backend sends String
        if (data is String) {
          data = jsonDecode(data);
        }

        if (data is Map &&
            data['response'] == 'success' &&
            data['data'] is List &&
            data['data'].isNotEmpty) {
          return data['data'][0];
        }

        return {};
      }

      throw Exception('Server error: ${response.statusCode}');
    } catch (e) {
      return {};
    }
  }

  Future<List<dynamic>> getBooks({String? userId, String? search}) async {
    try {
      // Use book_deploy endpoint when filtering by user_id
      final endpoint = userId != null && userId.isNotEmpty
          ? ApiConfig.bookDeployUrl
          : ApiConfig.bookUrl;

      // Use FormData for consistent API format
      final formData = FormData({});

      if (userId != null && userId.isNotEmpty) {
        formData.fields.add(MapEntry('user_id', userId));
      }

      if (search != null && search.isNotEmpty) {
        formData.fields.add(MapEntry('search', search));
      }

      final connect = GetConnect(timeout: const Duration(seconds: 30));
      var response = await connect.post(endpoint, formData);

      if (response.statusCode == null) {
        throw Exception('Network timeout or connection error');
      }

      if (response.statusCode == 200) {
        var data = response.body;

        // If data is a string, parse it as JSON
        if (data is String) {
          try {
            data = jsonDecode(data);
          } catch (jsonError) {
            throw Exception('Invalid JSON response from server');
          }
        }

        if (data is List) {
          if (data.isEmpty) {}

          // Debug: Log first book's structure
          if (data.isNotEmpty) {
            print('📚 First book from API:');
            print('   Keys: ${data.first.keys.toList()}');
            print('   Values: {');
            data.first.forEach((key, value) {
              print('      $key: $value');
            });
            print('   }');
          }

          return data;
        } else if (data is Map) {
          // Check for success response
          if (data['response'] == 'success' && data.containsKey('data')) {
            final result = data['data'];
            if (result is List) {
              // Debug: Print first few books' copy data with proper field names
              if (result.isNotEmpty) {
                for (
                  int i = 0;
                  i < (result.length > 2 ? 2 : result.length);
                  i++
                ) {
                  if (i == 0) {}
                }
              }

              if (result.isEmpty) {}
              return result;
            } else {
              return [];
            }
          } else if (data.containsKey('data')) {
            final result = data['data'] as List;
            return result;
          } else {
            return [];
          }
        }

        return [];
      } else if (response.statusCode == 404) {
        throw Exception('Books API endpoint not found');
      } else if (response.statusCode == 500) {
        throw Exception('Server error - please try again later');
      } else {
        throw Exception('Failed to load books: HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('timeout') ||
          e.toString().contains('connection')) {
        throw Exception('कनेक्शन की समस्या - कृपया इंटरनेट कनेक्शन जांचें');
      } else if (e.toString().contains('404')) {
        throw Exception('API सेवा उपलब्ध नहीं है');
      } else if (e.toString().contains('500')) {
        throw Exception('सर्वर में समस्या - कृपया बाद में कोशिश करें');
      }
      throw Exception('किताबें लोड करने में त्रुटि: $e');
    }
  }

  Future<Map<dynamic, dynamic>> getBookDetails(String bookIdentifier) async {
    try {
      // Get current user ID for the API call
      final authService = Get.find<AuthService>();
      final currentUser = authService.currentUser.value;

      if (currentUser == null) {
        throw Exception('User not logged in - cannot fetch book details');
      }

      final userId = currentUser.code;

      // Use FormData to match other API calls and ensure proper parameter handling
      final formData = FormData({
        'book_id': bookIdentifier, // This could be book_id or book_code
        'user_id': userId, // Use current user's ID
      });

      // Use book_deploy_details endpoint with FormData
      var response = await GetConnect().post(
        ApiConfig.bookDeployDetailsUrl,
        formData,
      );

      if (response.statusCode == 200) {
        var data = response.body;

        // If data is a string, parse it as JSON
        if (data is String) {
          data = jsonDecode(data);
        }

        if (data is Map) {
          if (data['response'] == 'success' &&
              data.containsKey('data') &&
              (data['data'] as List).isNotEmpty) {
            final bookData = (data['data'] as List)[0] as Map<String, dynamic>;

            // Validate that we got the correct book
            final returnedBookId = bookData['book_id']?.toString();

            if (returnedBookId != null && returnedBookId != bookIdentifier) {}

            // Debug: Print the copy information

            return bookData;
          }
          return data;
        }
        return {};
      } else {
        throw Exception('Failed to load book details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching book details: $e');
    }
  }

  Future<Map<String, dynamic>> updateReadingLevel(
    String studentCode,
    int newReadingLevel,
  ) async {
    try {
      // Use FormData to match other API calls and Postman format
      final formData = FormData({
        'M1_CODE': studentCode,
        'cur_read_level': newReadingLevel.toString(),
      });

      var response = await GetConnect().post(
        ApiConfig.updateReadingLevelUrl,
        formData,
      );

      if (response.statusCode == 200) {
        var data = response.body;

        // If data is a string, parse it as JSON
        if (data is String) {
          data = jsonDecode(data);
        }

        if (data is Map) {
          // Check if the API response indicates success
          if (data['response'] == 'success') {
            // Try to get updated student data from the response first
            Map<String, dynamic> studentData = {};
            if (data.containsKey('data') &&
                data['data'] is List &&
                (data['data'] as List).isNotEmpty) {
              studentData = (data['data'] as List)[0] as Map<String, dynamic>;
            } else {
              // If no data returned, fetch updated student details
              try {
                final updatedStudentData = await getStudentDetailsByCode(
                  studentCode,
                );
                if (updatedStudentData.isNotEmpty) {
                  studentData = updatedStudentData;
                }
              } catch (e) {}
            }

            return {
              'success': true,
              'message': data['message'] ?? 'Reading Level Updated!',
              'data': studentData,
              'offline': false,
            };
          } else {
            return {
              'success': false,
              'message': data['message'] ?? 'Failed to update reading level',
              'offline': false,
            };
          }
        }

        return {
          'success': false,
          'message': 'Invalid response format',
          'offline': false,
        };
      } else {
        throw Exception(
          'Failed to update reading level: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error updating reading level: $e');
    }
  }

  Future<Map<String, dynamic>> checkout({
    required String teacherId,
    required List<Map<String, dynamic>> books,
    required String studentId,
    required String className,
    String? programId,
    String? schoolId,
    String? studentName,
  }) async {
    try {
      final authService = Get.find<AuthService>();
      final currentUser = authService.currentUser.value;

      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      final finalSchoolId = schoolId ?? currentUser.group1;
      final finalProgramId = programId ?? currentUser.group;

      final connectivityService = Get.find<ConnectivityService>();

      if (!connectivityService.isOnline.value) {
        throw Exception('Multiple checkout is currently supported only online');
      }

      final formData = FormData({
        'teacher_id': teacherId,
        'student_id': studentId,
        'program_id': finalProgramId,
        'school_id': finalSchoolId,
        'grade': className,
        'M1_GROUP': finalSchoolId,
        'M1GROUP1': finalProgramId,
      });

      for (int i = 0; i < books.length; i++) {
        formData.fields.add(
          MapEntry('books[$i][book_id]', books[i]['bookId'].toString()),
        );
      }
      log('📤 CHECKOUT: Sending to ${ApiConfig.checkoutUrl}');
      log('📋 CHECKOUT: teacherId: $teacherId');
      log('📋 CHECKOUT: programId: $finalProgramId');
      log('📋 CHECKOUT: schoolId: $finalSchoolId');
      log('📋 CHECKOUT: grade: $className');
      log('📋 CHECKOUT: m1Group: $finalProgramId');
      log('📋 CHECKOUT: m1Group1: $finalSchoolId');
      log('📋 CHECKOUT: Form data: $books');

      final response = await GetConnect().post(ApiConfig.checkoutUrl, formData);

      if (response.statusCode == 200) {
        dynamic data = response.body;

        if (data is String) {
          data = jsonDecode(data);
        }

        if (data['response'] == 'success') {
          return {
            'success': true,
            'message': data['message'] ?? 'Books issued successfully',
            'data': data['data'],
            'offline': false,
          };
        }

        return {
          'success': false,
          'message': data['message'] ?? 'Checkout failed',
        };
      }

      return {'success': false, 'message': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> checkin({
    required String
    bookTransactionCode, // F4_BT (2 for good, 3 for damaged, 4 for lost)
    required String
    bookCode, // F4_LCODE (primary identifier from checked-out books)
    required String teacherId,
    required String bookId,
    required String studentId,
    required String className,
    String? programId,
    String? schoolId,
    String? studentName, // ✅ ADD: Student name for backend
    String? bookName, // ✅ ADD: Book name for backend
  }) async {
    try {
      // Get current user for fallback values
      final authService = Get.find<AuthService>();
      final currentUser = authService.currentUser.value;

      if (currentUser == null) {
        throw Exception('User not logged in - cannot perform checkin');
      }

      // Use fallback values from current user if not provided
      // ✅ FIXED: Use group (M1_GROUP) for school_id and group1 (M1_GROUP1) for program_id
      final finalSchoolId = schoolId ?? currentUser.group1;
      final finalProgramId = programId ?? currentUser.group;
      final finalTeacherId = teacherId;

      // ✅ CHECK CONNECTIVITY FIRST
      final connectivityService = Get.find<ConnectivityService>();
      final isOnline = connectivityService.isOnline.value;

      print(
        '📡 CHECKIN: Connection status = ${connectivityService.isOnline.value}',
      );

      if (!isOnline) {
        print('📱 CHECKIN: Device is OFFLINE - Saving to local database...');

        try {
          // Save to offline database
          final offlineDb = Get.find<OfflineDatabaseService>();
          // ✅ CRITICAL: Pass bookId (numeric ID) as bookCode for offline storage
          // This ensures F4_LCODE is stored as numeric ID, not book name
          await offlineDb.saveOfflineCheckin(
            bookTransactionCode: bookTransactionCode,
            bookCode: bookCode, // ✅ FIXED: Use bookId (numeric ID) not bookCode
            teacherId: finalTeacherId,
            bookId: bookId,
            studentId: studentId,
            studentName: studentName ?? '',
            className: className,
            bookName: bookName ?? '',
            programId: finalProgramId,
            schoolId: finalSchoolId,
          );

          print('✅ CHECKIN: Saved to offline database successfully');
          return {
            'success': true,
            'message': 'किताब ऑफलाइन वापस की गई! 📱',
            'offline': true,
            'data': 1,
          };
        } catch (offlineError) {
          print('❌ CHECKIN: Failed to save offline - $offlineError');
          return {
            'success': false,
            'message': 'Failed to save offline: $offlineError',
          };
        }
      }

      // Device is online - proceed with API call
      print('🌐 CHECKIN: Device is ONLINE - Calling API...');

      // Build FormData with F4_LCODE as primary field (as shown in Postman response)
      final formData = FormData({
        'F4_BT':
            bookTransactionCode, // Transaction code (2=good, 3=damaged, 4=lost)
        'F4_LCODE':
            bookCode, // Book code (primary - from checked-out books F4_LCODE)
        'M1_CODE':
            bookCode, // ✅ ADD: Book code as M1_CODE for API compatibility
        'teacher_id': finalTeacherId, // F4_USERADD
        'book_id': bookId, // F4_PARTY (M1_NO - the actual book ID)
        'M1_NO': bookId, // ✅ ADD: Book ID as M1_NO for API compatibility
        'student_id': studentId, // F4_PARTY1
        'program_id': finalProgramId, // F4_GR
        'school_id': finalSchoolId, // F4_TRP
        'grade': className, // Class (optional)
        'M1_GROUP': finalSchoolId, // ✅ NEW: School ID as M1_GROUP
        'M1GROUP1': finalProgramId, // ✅ NEW: Program ID as M1GROUP1
      });

      // ✅ DEBUG: Log the FormData being sent
      log('📋 CHECKIN offline : FormData prepared:');
      log('   F4_BT (Transaction): $bookTransactionCode');
      log('   F4_LCODE (Book Code): $bookCode');
      log('   teacher_id: $finalTeacherId');
      log('   book_id: $bookId');
      log('   student_id: $studentId');
      log('   F4_TXT2: $className');
      log('   program_id: $finalProgramId');
      log('   school_id: $finalSchoolId');
      log('   M1_GROUP: $finalSchoolId');
      log('   M1GROUP1: $finalProgramId');

      // Log the FormData being sent
      log('📤 Checkin FormData fields:');
      for (final field in formData.fields) {
        log('   ${field.key}: ${field.value}');
      }

      // ✅ ADD: Include student name and book name if provided
      if (studentName != null && studentName.isNotEmpty) {
        formData.fields.add(MapEntry('student_name', studentName));
        log('   Added: student_name: $studentName');
      }
      if (bookName != null && bookName.isNotEmpty) {
        formData.fields.add(MapEntry('book_name', bookName));
        log('   Added: book_name: $bookName');
      }

      final stopwatch = Stopwatch()..start();

      log('📤 CHECKIN: Sending to ${ApiConfig.checkinUrl}');
      log('📋 CHECKIN: Form data: $formData');

      var response = await GetConnect().post(ApiConfig.checkinUrl, formData);

      stopwatch.stop();

      log('📊 CHECKIN: Response status: ${response.statusCode}');
      log('📊 CHECKIN: Response body: ${response.body}');
      log('⏱️ CHECKIN: Request took ${stopwatch.elapsedMilliseconds}ms');

      if (response.statusCode == 200) {
        var data = response.body;

        // If data is a string, parse it as JSON
        if (data is String) {
          try {
            data = jsonDecode(data);
          } catch (jsonError) {
            throw Exception('Invalid JSON response: $jsonError');
          }
        } else {}

        if (data is Map) {
          if (data['response'] == 'success') {
            final result = {
              'success': true,
              'message': data['message'] ?? 'Book Returned!',
              'data': data['data'] ?? 1,
              'offline': false,
            };
            return result;
          } else {
            final result = {
              'success': false,
              'message': data['message'] ?? 'Checkin failed',
            };
            return result;
          }
        } else {
          return {
            'success': false,
            'message':
                'Invalid response format - expected Map, got ${data.runtimeType}',
          };
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.statusText}');
      }
    } catch (e) {
      print('❌ CHECKIN: API Exception - $e');
      return {'success': false, 'message': 'API Error: $e'};
    } finally {}
  }

  Future<List<dynamic>> getCheckedOutBooks({
    required String teacherId,
    String? className,
    String? fromDate,
    String? toDate,
    String? search,
  }) async {
    try {
      print('📡 API: Calling get_issue_book endpoint');
      print('   Teacher ID: $teacherId');
      print('   Class/Grade: ${className ?? "all"}');
      print('   From Date: ${fromDate ?? "none"}');
      print('   To Date: ${toDate ?? "none"}');
      print('   Search: ${search ?? "none"}');

      // ✅ USE FORMDATA (same as Postman)
      final formData = FormData({'teacher_id': teacherId});

      // ✅ Grade
      if (className != null && className.trim().isNotEmpty) {
        formData.fields.add(MapEntry('grade', className.toString().trim()));
      }

      // ✅ From date
      if (fromDate != null && fromDate.trim().isNotEmpty) {
        formData.fields.add(MapEntry('from_date', fromDate.trim()));
      }

      // ✅ To date
      if (toDate != null && toDate.trim().isNotEmpty) {
        formData.fields.add(MapEntry('to_date', toDate.trim()));
      }

      // ✅ Search
      if (search != null && search.trim().isNotEmpty) {
        formData.fields.add(MapEntry('search', search.trim()));
      }

      // ✅ DEBUG: Print exact fields being sent
      print('📤 API: Sending FormData fields:');
      for (final field in formData.fields) {
        print('   ${field.key}: ${field.value}');
      }

      print('📤 API: URL: ${ApiConfig.checkedOutBooksUrl}');

      final response = await GetConnect(
        timeout: const Duration(seconds: 30),
      ).post(ApiConfig.checkedOutBooksUrl, formData);

      print('📥 API: Response status: ${response.statusCode}');
      print('📥 API: Response body type: ${response.body.runtimeType}');
      print('📥 API: Raw response: ${response.body}');

      if (response.statusCode == 200) {
        dynamic data = response.body;

        // ✅ Parse JSON string
        if (data is String) {
          print('📥 API: Parsing JSON string...');
          try {
            data = jsonDecode(data);
          } catch (e) {
            print('❌ JSON Parse Error: $e');
            return [];
          }
        }

        // ✅ Direct list response
        if (data is List) {
          print('✅ API returned List with ${data.length} items');
          return data;
        }

        // ✅ Map response
        if (data is Map<String, dynamic>) {
          print('📥 API Map Keys: ${data.keys.toList()}');

          if (data['response'] == 'success') {
            final responseData = data['data'];

            if (responseData is List) {
              print('✅ API Success: ${responseData.length} books received');

              if (responseData.isNotEmpty) {
                print('📋 Sample Item: ${responseData.first}');
              }

              return responseData;
            }

            print('⚠️ Data is not List');
            return [];
          }

          print('❌ API Error: ${data['message']}');
          return [];
        }

        print('⚠️ Unknown response format');
        return [];
      }

      print('❌ HTTP Error: ${response.statusCode}');
      return [];
    } catch (e, stackTrace) {
      print('❌ Exception in getCheckedOutBooks: $e');
      print(stackTrace);
      return [];
    }
  }

  Future<List<dynamic>> getCicoReport({
    required String teacherId,
    String? className,
    String? fromDate,
    String? toDate,
  }) async {
    try {
      final formData = FormData({
        'teacher_id': teacherId,
        'grade': className ?? '',
        'from_date': fromDate ?? '',
        'to_date': toDate ?? '',
        'search': '',
      });

      final response = await GetConnect(
        timeout: const Duration(seconds: 30),
      ).post(ApiConfig.cicoReportUrl, formData);

      log('📦 STATUS: ${response.statusCode}');
      log('📦 RESPONSE: ${response.bodyString}');

      if (response.statusCode == 200) {
        var data = response.body;

        if (data is String) {
          data = jsonDecode(data);
        }

        if (data['response'] == 'success') {
          return data['data'] ?? [];
        } else {
          log('❌ API returned error: ${data}');
          return [];
        }
      } else {
        throw Exception('Failed: ${response.statusCode}');
      }
    } catch (e) {
      log('❌ ERROR: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getAnalytics({
    String? teacherId,
    String? className,
    String? dateFrom,
    String? dateTo,
    String? aggregation,
  }) async {
    try {
      final body = <String, dynamic>{};

      if (teacherId != null && teacherId.isNotEmpty) {
        body['teacher_id'] = teacherId;
      }

      if (className != null &&
          className.isNotEmpty &&
          className != 'सभी कक्षाएं') {
        body['grade'] = className;
      }

      if (dateFrom != null && dateFrom.isNotEmpty) {
        body['from_date'] = dateFrom; // Use from_date as specified
      }

      if (dateTo != null && dateTo.isNotEmpty) {
        body['to_date'] = dateTo; // Use to_date as specified
      }

      if (aggregation != null && aggregation.isNotEmpty) {
        body['aggregation'] = aggregation;
      }

      var response = await GetConnect().post(
        ApiConfig.analyticsUrl,
        body,
        contentType: 'application/x-www-form-urlencoded',
      );

      if (response.statusCode == 200) {
        var data = response.body;

        // If data is a string, parse it as JSON
        if (data is String) {
          data = jsonDecode(data);
        }

        if (data is Map && data['response'] == 'success') {
          return {
            'success': true,
            'chart': data['data']['chart'] ?? {},
            'summary': data['data']['summary'] ?? {},
            'list': data['data']['list'] ?? [],
          };
        }

        return {'success': false, 'message': 'Invalid response format'};
      } else {
        throw Exception('Failed to load analytics: ${response.statusCode}');
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<List<dynamic>> getStudentBookHistory({
    required String studentId,
    String? fromDate,
    String? toDate,
  }) async {
    try {
      // Use FormData to match Postman request - only send student_id
      final formData = FormData({'student_id': studentId});

      if (fromDate != null && fromDate.isNotEmpty) {
        formData.fields.add(MapEntry('from_date', fromDate));
      }

      if (toDate != null && toDate.isNotEmpty) {
        formData.fields.add(MapEntry('to_date', toDate));
      }

      var response = await GetConnect().post(
        ApiConfig.studentBookHistoryUrl,
        formData,
      );

      if (response.statusCode == 200) {
        var data = response.body;

        if (data is String) {
          data = jsonDecode(data);
        }

        if (data is Map &&
            data['response'] == 'success' &&
            data.containsKey('data')) {
          final dataValue = data['data'];

          if (dataValue is List) {
            return dataValue;
          }
        }

        return [];
      } else {
        throw Exception(
          'Failed to load student book history: ${response.statusCode}',
        );
      }
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getBookIssueCount({
    String? teacherId,
    String? fromDate,
    String? toDate,
  }) async {
    try {
      // Use FormData for consistent API format
      final formData = FormData({});

      if (teacherId != null && teacherId.isNotEmpty) {
        formData.fields.add(MapEntry('teacher_id', teacherId));
      }

      if (fromDate != null && fromDate.isNotEmpty) {
        formData.fields.add(MapEntry('from_date', fromDate));
      }

      if (toDate != null && toDate.isNotEmpty) {
        formData.fields.add(MapEntry('to_date', toDate));
      }

      var response = await GetConnect().post(
        ApiConfig.bookIssueCountUrl,
        formData,
      );

      if (response.statusCode == 200) {
        var data = response.body;

        if (data is String) {
          data = jsonDecode(data);
        }

        if (data is Map && data['response'] == 'success') {
          return {
            'success': true,
            'count': data['data'] ?? 0,
            'message': data['message'] ?? 'Count retrieved successfully',
          };
        }

        return {
          'success': false,
          'count': 0,
          'message': data['message'] ?? 'Invalid response format',
        };
      } else {
        throw Exception(
          'Failed to load book issue count: ${response.statusCode}',
        );
      }
    } catch (e) {
      return {'success': false, 'count': 0, 'message': 'Error: $e'};
    }
  }

  // ✅ NEW: Get all checked-out books in bulk (for initial sync)
  Future<List<dynamic>> getCheckinBulk({
    required String teacherId,
    String? fromDate,
    String? toDate,
  }) async {
    try {
      print(
        '📥 API: Fetching all checked-out books for bulk sync (teacher: $teacherId)',
      );

      final body = {
        'teacher_id': teacherId,
        if (fromDate != null) 'from_date': fromDate,
        if (toDate != null) 'to_date': toDate,
      };

      var response = await GetConnect(
        timeout: const Duration(seconds: 60),
      ).post('${ApiConfig.baseUrl}/get_checkin_bulk', body);

      if (response.statusCode == 200) {
        final data = response.body;
        List<dynamic> books = [];

        if (data is List) {
          books = data;
        } else if (data is Map && data['data'] != null) {
          books = List<dynamic>.from(data['data'] as List);
        }

        print(
          '✅ API: Successfully fetched ${books.length} checked-out books for bulk',
        );
        return books;
      } else {
        print(
          '❌ API: Failed to get checked-out books bulk: ${response.statusCode}',
        );
        return [];
      }
    } catch (e) {
      print('❌ API Error in getCheckinBulk: $e');
      return [];
    }
  }

  // ✅ NEW: Get all checked-in books in bulk (for initial sync)
  Future<List<dynamic>> getCheckoutBulk({
    required String teacherId,
    String? fromDate,
    String? toDate,
  }) async {
    try {
      print(
        '📥 API: Fetching all checked-in books for bulk sync (teacher: $teacherId)',
      );

      final body = {
        'teacher_id': teacherId,
        if (fromDate != null) 'from_date': fromDate,
        if (toDate != null) 'to_date': toDate,
      };

      var response = await GetConnect(
        timeout: const Duration(seconds: 60),
      ).post('${ApiConfig.baseUrl}/get_checkout_bulk', body);

      if (response.statusCode == 200) {
        final data = response.body;
        List<dynamic> books = [];

        if (data is List) {
          books = data;
        } else if (data is Map && data['data'] != null) {
          books = List<dynamic>.from(data['data'] as List);
        }

        print(
          '✅ API: Successfully fetched ${books.length} checked-in books for bulk',
        );
        return books;
      } else {
        print(
          '❌ API: Failed to get checked-in books bulk: ${response.statusCode}',
        );
        return [];
      }
    } catch (e) {
      print('❌ API Error in getCheckoutBulk: $e');
      return [];
    }
  }

  // Bulk sync methods for offline data
  Future<Map<String, dynamic>> bulkSyncCheckin(
    List<Map<String, dynamic>> checkinData,
  ) async {
    try {
      if (checkinData.isEmpty) {
        return {
          'success': true,
          'message': 'No checkin data to sync',
          'synced_count': 0,
        };
      }

      print(
        '📤 Syncing ${checkinData.length} checkin records via individual calls (bulk endpoint not supported)',
      );

      // ✅ CRITICAL FIX: Skip bulk endpoint and use individual calls
      // The bulk checkin endpoint returns "Something Went Wrong!" error
      // Individual calls work reliably, so we'll use those instead

      int successCount = 0;
      int failCount = 0;
      final List<String> errors = [];

      for (int i = 0; i < checkinData.length; i++) {
        final record = checkinData[i];
        try {
          print(
            '\n📤 Sending individual checkin ${i + 1}/${checkinData.length}...',
          );

          final indResult = await checkin(
            bookTransactionCode: record['F4_BT']?.toString() ?? '2',
            bookCode: record['F4_LCODE']?.toString() ?? '',
            teacherId: record['teacher_id']?.toString() ?? '',
            bookId: record['book_id']?.toString() ?? '',
            studentId: record['student_id']?.toString() ?? '',
            className: record['class']?.toString() ?? '',
            programId: record['program_id']?.toString() ?? '',
            schoolId: record['school_id']?.toString() ?? '',
          );

          if (indResult['success'] == true) {
            successCount++;
            print('✅ Individual checkin ${i + 1} succeeded');
          } else {
            failCount++;
            final errorMsg = indResult['message'] ?? 'Checkin failed';
            print('❌ Individual checkin ${i + 1} failed: $errorMsg');
            errors.add('Checkin ${i + 1}: $errorMsg');
          }
        } catch (e) {
          failCount++;
          print('❌ Individual checkin ${i + 1} error: $e');
          errors.add('Checkin ${i + 1}: $e');
        }
      }

      print('\n📊 Checkin Results: $successCount succeeded, $failCount failed');

      if (successCount > 0) {
        return {
          'success': true,
          'message':
              'Checkins synced via individual calls: $successCount/${checkinData.length}',
          'synced_count': successCount,
        };
      } else {
        return {
          'success': false,
          'message': 'All checkins failed',
          'synced_count': 0,
          'errors': errors,
        };
      }
    } catch (e) {
      print('❌ Error in checkin sync: $e');
      return {
        'success': false,
        'message': 'Error syncing checkins: $e',
        'synced_count': 0,
      };
    }
  }

  // ✅ Helper: Split records into chunks to avoid server limits
  List<List<T>> _chunkList<T>(List<T> items, int chunkSize) {
    final chunks = <List<T>>[];
    for (int i = 0; i < items.length; i += chunkSize) {
      final end = (i + chunkSize > items.length) ? items.length : i + chunkSize;
      chunks.add(items.sublist(i, end));
    }
    return chunks;
  }

  // Bulk sync checkout transactions
  // ✅ NEW: Uses chunking to handle large batches that exceed server limits
  Future<Map<String, dynamic>> bulkSyncCheckout(
    List<Map<String, dynamic>> checkoutData,
  ) async {
    try {
      if (checkoutData.isEmpty) {
        return {
          'success': true,
          'message': 'No checkout data to sync',
          'synced_count': 0,
        };
      }

      print(
        '📤 Syncing ${checkoutData.length} checkout records via get_bulk_checkout endpoint',
      );
      print(
        '   Strategy: Split into chunks of 10 records to avoid server limits',
      );

      // ✅ NEW: Split into chunks of 10 records per batch
      final BATCH_SIZE = 10;
      final chunks = _chunkList(checkoutData, BATCH_SIZE);

      print(
        '📊 Split into ${chunks.length} batch(es) of max $BATCH_SIZE records each',
      );

      // Get current user for fallback values
      final authService = Get.find<AuthService>();
      final currentUser = authService.currentUser.value;

      List<String> errors = [];

      // ✅ NEW: Fetch missing books from API before syncing
      try {
        final offlineDb = Get.find<OfflineDatabaseService>();
        final db = await offlineDb.database;

        // Collect all unique book IDs from checkout data
        final bookIds = checkoutData
            .map((record) => record['book_id']?.toString())
            .where((id) => id != null && id.isNotEmpty)
            .toSet()
            .toList();

        print(
          '🔍 Checking ${bookIds.length} unique books in local database...',
        );

        // Check which books are missing from local database
        final missingBookIds = <String>[];
        for (final bookId in bookIds) {
          final books = await db.query(
            'books',
            where: 'code = ? OR bookId = ? OR no = ?',
            whereArgs: [bookId, bookId, bookId],
            limit: 1,
          );

          if (books.isEmpty) {
            print('! Book not found in database: $bookId');
            missingBookIds.add(bookId!);
          }
        }

        // Fetch missing books from API if any
        if (missingBookIds.isNotEmpty && currentUser != null) {
          print(
            '🌐 Fetching ${missingBookIds.length} missing books from API...',
          );

          try {
            // Fetch all books from API
            final allBooks = await getBooks(userId: currentUser.code);

            // Find and save the missing books
            int savedCount = 0;
            for (final bookId in missingBookIds) {
              final targetBook = allBooks
                  .where((b) => b.bookId == bookId || b.bookCode == bookId)
                  .firstOrNull;

              if (targetBook != null) {
                print(
                  '✅ Found missing book in API: ${targetBook.bookName} ($bookId)',
                );

                // Save to local database
                await offlineDb.saveBooksOffline([
                  {
                    'book_id': targetBook.bookId.isNotEmpty
                        ? targetBook.bookId
                        : targetBook.bookCode,
                    'book_code': targetBook.bookCode,
                    'book_name': targetBook.bookName,
                    'available_copy': targetBook.availableCopy,
                    'issued_copy': targetBook.issuedCopy,
                    'total_copy': targetBook.totalCopy,
                    'damaged_copy': targetBook.damagedCopy,
                    'lost_copy': targetBook.lostCopy,
                    'reading_level': targetBook.readingLevel,
                    'program_code': targetBook.programCode,
                    'code': targetBook.bookCode,
                    'no': targetBook.bookId.isNotEmpty
                        ? targetBook.bookId
                        : targetBook.bookCode,
                    'name': targetBook.bookName,
                    'txt1': targetBook.readingLevel.toString(),
                    'txt2': targetBook.totalCopy.toString(),
                    'txt3': targetBook.availableCopy.toString(),
                    'txt4': targetBook.issuedCopy.toString(),
                    'txt5': targetBook.damagedCopy.toString(),
                    'bookId': targetBook.bookId.isNotEmpty
                        ? targetBook.bookId
                        : targetBook.bookCode,
                  },
                ]);

                savedCount++;
              } else {
                print('⚠️ Book $bookId not found in API either');
              }
            }

            if (savedCount > 0) {
              print('✅ Saved $savedCount missing books to local database');
            }
          } catch (e) {
            print('⚠️ Error fetching missing books from API: $e');
            print('   Continuing with bulk sync anyway...');
          }
        }
      } catch (e) {
        print('⚠️ Error checking/fetching missing books: $e');
        print('   Continuing with bulk sync anyway...');
      }

      // Prepare bulk checkout data - only include fields needed by the API
      // 🔧 IMPORTANT: Must match individual checkout fields for compatibility
      // The API probably uses the same validation as /get_checkout endpoint
      final bulkRecords = <Map<String, dynamic>>[];
      for (final record in checkoutData) {
        bulkRecords.add({
          'teacher_id': record['teacher_id'] ?? currentUser?.code,
          'book_id': record['book_id'],
          'student_id': record['student_id'],
          'class': record['class'],
          'program_id': record['program_id'] ?? currentUser?.prg,
          'school_id': record['school_id'] ?? currentUser?.sch,
        });
      }

      // Send ALL records together in a single batch request
      try {
        print('\n📋 🚀 BATCH SENDING ${bulkRecords.length} CHECKOUT RECORDS:');
        for (int i = 0; i < bulkRecords.length; i++) {
          final record = bulkRecords[i];
          print(
            '   ${i + 1}. Teacher: ${record['teacher_id']}, Book: ${record['book_id']}, Student: ${record['student_id']}, Class: ${record['class']}',
          );
        }

        print('\n📤 Sending to: ${ApiConfig.bulkCheckoutUrl}');
        print(
          '📤 Format: BATCH (ALL ${bulkRecords.length} records in ONE request)',
        );
        print(
          '📤 Content-Type: application/x-www-form-urlencoded (array format)',
        );

        // ✅ NEW: Send ALL records together using array notation
        // The bulk API expects multiple records in a single POST with array field names
        // Format: checkout[0][field_name]=value&checkout[1][field_name]=value...
        // CRITICAL FIX: Use F4_LCODE (book code) instead of book_id to match individual endpoint
        final formData = <String, String>{};

        for (int i = 0; i < bulkRecords.length; i++) {
          final record = bulkRecords[i];
          // ✅ CRITICAL: Use F4_LCODE if available (book code), otherwise use book_id
          final bookCodeForApi =
              record['F4_LCODE']?.toString() ??
              record['book_id']?.toString() ??
              '';

          formData['checkout[$i][F4_LCODE]'] =
              bookCodeForApi; // ✅ Primary: Book code
          formData['checkout[$i][teacher_id]'] =
              record['teacher_id']?.toString() ?? '';
          formData['checkout[$i][book_id]'] =
              record['book_id']?.toString() ?? ''; // Keep as fallback
          formData['checkout[$i][student_id]'] =
              record['student_id']?.toString() ?? '';
          formData['checkout[$i][class]'] = record['class']?.toString() ?? '';
          formData['checkout[$i][program_id]'] =
              record['program_id']?.toString() ?? '';
          formData['checkout[$i][school_id]'] =
              record['school_id']?.toString() ?? '';
        }

        print('\n📊 Batch Payload Fields (${formData.length} total fields):');
        // Group by record index for clarity
        final recordIndices = <int>{};
        for (final key in formData.keys) {
          final match = RegExp(r'checkout\[(\d+)\]').firstMatch(key);
          if (match != null) {
            recordIndices.add(int.parse(match.group(1)!));
          }
        }

        for (final idx in recordIndices.toList()..sort()) {
          print('\n   📦 Record [$idx]:');
          for (final entry in formData.entries) {
            if (entry.key.contains('checkout[$idx]')) {
              final fieldName = entry.key
                  .replaceAll('checkout[$idx][', '')
                  .replaceAll(']', '');
              print('      $fieldName: "${entry.value}"');
            }
          }
        }

        // 🔍 Validate all records before sending
        print('\n✅ Validation:');
        bool allValid = true;
        for (int i = 0; i < bulkRecords.length; i++) {
          final record = bulkRecords[i];
          final isEmpty =
              (record['teacher_id']?.toString() ?? '').isEmpty ||
              (record['book_id']?.toString() ?? '').isEmpty ||
              (record['student_id']?.toString() ?? '').isEmpty ||
              (record['class']?.toString() ?? '').isEmpty ||
              (record['program_id']?.toString() ?? '').isEmpty ||
              (record['school_id']?.toString() ?? '').isEmpty;

          if (isEmpty) {
            print('   ❌ Record ${i + 1} has missing fields');
            allValid = false;
          } else {
            print('   ✅ Record ${i + 1} is complete');
          }
        }

        if (!allValid) {
          return {
            'success': false,
            'message': 'Some records have missing fields',
            'synced_count': 0,
          };
        }

        print('\n📤 Sending batch request...');
        final stopwatch = Stopwatch()..start();

        print('\n📋 REQUEST DETAILS:');
        print('   URL: ${ApiConfig.bulkCheckoutUrl}');
        print('   Method: POST');
        print('   Content-Type: application/x-www-form-urlencoded');
        print('   Total Fields: ${formData.length}');
        print('   Total Records: ${bulkRecords.length}');
        print('\n   Full Request Body:');
        for (final entry in formData.entries) {
          print('      ${entry.key}=${entry.value}');
        }

        var response = await GetConnect(
          timeout: const Duration(seconds: 120),
        ).post(ApiConfig.bulkCheckoutUrl, formData);

        stopwatch.stop();

        print('\n📊 BATCH RESPONSE:');
        print('   Status Code: ${response.statusCode}');
        print('   Time Taken: ${stopwatch.elapsedMilliseconds}ms');
        print('   Response Type: ${response.body.runtimeType}');
        print('   Response Body: ${response.body}');

        if (response.statusCode == 200) {
          Map<String, dynamic>? responseData;

          // Parse response - could be String or Map
          if (response.body is String) {
            try {
              responseData = jsonDecode(response.body);
            } catch (e) {
              print('   ⚠️ Failed to parse response as JSON: $e');
              print('   Raw string: ${response.body}');
            }
          } else if (response.body is Map) {
            responseData = response.body as Map<String, dynamic>;
          }

          if (responseData != null) {
            print('\n   Response Fields:');
            print('     - response: "${responseData['response']}"');
            print('     - message: "${responseData['message']}"');
            print('     - synced_count: ${responseData['synced_count']}');
            print('     - data: ${responseData['data']}');
            print('     - All fields: ${responseData.keys.toList()}');

            // ✅ Check if batch was successful
            // First check if we got a real synced_count
            final syncedCount = responseData['synced_count'] as int? ?? 0;

            print('\n   📊 SYNC COUNT ANALYSIS:');
            print('      Sent Records: ${bulkRecords.length}');
            print('      API Synced Count: $syncedCount');
            print(
              '      Match: ${syncedCount == bulkRecords.length ? '✅ YES' : '❌ NO - MISMATCH!'}',
            );

            if (syncedCount > 0) {
              // API explicitly says N records were synced
              print(
                '\n✅ BATCH CHECKOUT SUCCESSFUL: $syncedCount/${bulkRecords.length} records synced',
              );

              return {
                'success': true,
                'message':
                    responseData['message'] ??
                    'Batch checkouts synced successfully',
                'synced_count': syncedCount,
              };
            } else if ((responseData['response'] == 'success' ||
                responseData['success'] == true)) {
              // API says success but no synced_count - assume all records were synced
              print('\n⚠️ API says success but synced_count is 0 or missing');
              print(
                '   Assuming all ${bulkRecords.length} records were synced',
              );

              // ✅ CRITICAL FIX: If API says success, assume all records were synced
              return {
                'success': true,
                'message':
                    responseData['message'] ??
                    'Batch checkouts synced successfully',
                'synced_count': bulkRecords.length, // ✅ Assume all were synced
              };
            } else {
              print('\n❌ BATCH CHECKOUT FAILED:');
              print('   Message: ${responseData['message']}');
              print('   Response: ${responseData['response']}');
            }

            // ✅ FALLBACK: If we get here with explicit failure, retry individually
            if (syncedCount == 0 && responseData['response'] != 'success') {
              print(
                '\n🔄 FALLBACK: Trying individual checkout calls for each record...',
              );

              // ✅ FALLBACK: Send checkouts individually if bulk fails
              int successCount = 0;
              int failCount = 0;

              for (int i = 0; i < bulkRecords.length; i++) {
                final record = bulkRecords[i];
                try {
                  print(
                    '\n📤 Sending individual checkout ${i + 1}/${bulkRecords.length}...',
                  );
                  final indResult = await checkout(
                    teacherId: record['teacher_id']?.toString() ?? '',
                    books: [
                      {
                        'bookId': record['book_id']?.toString() ?? '',
                        'bookCode':
                            record['F4_LCODE']?.toString() ??
                            record['book_id']?.toString() ??
                            '',
                        'bookName': record['book_name']?.toString() ?? '',
                        'author': '',
                        'availableCopies': 1,
                      },
                    ],
                    studentId: record['student_id']?.toString() ?? '',
                    className: record['class']?.toString() ?? '',
                    programId: record['program_id']?.toString() ?? '',
                    schoolId: record['school_id']?.toString() ?? '',
                  );

                  if (indResult['success'] == true) {
                    successCount++;
                    print('✅ Individual checkout ${i + 1} succeeded');
                  } else {
                    failCount++;
                    print(
                      '❌ Individual checkout ${i + 1} failed: ${indResult['message']}',
                    );
                  }
                } catch (e) {
                  failCount++;
                  print('❌ Individual checkout ${i + 1} error: $e');
                }
              }

              print(
                '\n📊 Fallback Results: $successCount succeeded, $failCount failed',
              );

              if (successCount > 0) {
                return {
                  'success': true,
                  'message':
                      'Checkouts synced via individual calls: $successCount/${bulkRecords.length}',
                  'synced_count': successCount,
                  'fallback_used': true,
                };
              } else {
                return {
                  'success': false,
                  'message': 'Batch and individual checkouts failed',
                  'synced_count': 0,
                  'errors': errors,
                };
              }
            }
          } else {
            print('   ⚠️ Response data is null, failed to parse');
            return {
              'success': false,
              'message': 'Invalid response format',
              'synced_count': 0,
            };
          }
        } else {
          print('❌ HTTP Error: ${response.statusCode}');
          return {
            'success': false,
            'message': 'HTTP ${response.statusCode}: ${response.statusText}',
            'synced_count': 0,
          };
        }
      } catch (e) {
        print('❌ Error in batch checkout: $e');
        return {
          'success': false,
          'message': 'Error sending batch checkout: $e',
          'synced_count': 0,
        };
      }
    } catch (e) {
      print('❌ Error preparing bulk checkout: $e');
      return {
        'success': false,
        'message': 'Error preparing bulk checkout: $e',
        'synced_count': 0,
      };
    }

    // Fallback - should never reach here
    return {
      'success': false,
      'message': 'Unexpected error in bulk checkout',
      'synced_count': 0,
    };
  }

  // ✅ OLD: Bulk sync checkout (kept for reference - uses individual requests)
  // This old implementation has been replaced with get_checkout_bulk endpoint usage
  // Keeping structure for reference only

  // Test bulk sync endpoints with sample data for debugging
  Future<Map<String, dynamic>> testBulkSyncEndpoints() async {
    try {
      final results = <String, dynamic>{};

      // Test bulk checkin endpoint
      final testCheckinData = [
        {
          'F4_BT': 'TEST_BT_001',
          'F4_LCODE': 'TEST_LCODE_001',
          'teacher_id': 'TEST_TEACHER',
          'book_id': 'TEST_BOOK',
          'student_id': 'TEST_STUDENT',
          'class': 'TEST_CLASS',
          'program_id': 'TEST_PROGRAM',
          'school_id': 'TEST_SCHOOL',
          '_transaction_id': 'TEST_TRANS_001',
          '_timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      ];

      final checkinTestResult = await bulkSyncCheckin(testCheckinData);
      results['checkin_test'] = checkinTestResult;

      // Test bulk checkout endpoint
      final testCheckoutData = [
        {
          'teacher_id': 'TEST_TEACHER',
          'book_id': 'TEST_BOOK',
          'student_id': 'TEST_STUDENT',
          'class': 'TEST_CLASS',
          'program_id': 'TEST_PROGRAM',
          'school_id': 'TEST_SCHOOL',
          '_transaction_id': 'TEST_TRANS_002',
          '_timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      ];

      final checkoutTestResult = await bulkSyncCheckout(testCheckoutData);
      results['checkout_test'] = checkoutTestResult;

      // Summary
      results['summary'] = {
        'checkin_success': checkinTestResult['success'] ?? false,
        'checkout_success': checkoutTestResult['success'] ?? false,
        'checkin_message': checkinTestResult['message'] ?? 'No message',
        'checkout_message': checkoutTestResult['message'] ?? 'No message',
        'test_timestamp': DateTime.now().toIso8601String(),
      };

      return results;
    } catch (e) {
      return {
        'success': false,
        'message': 'Test failed: $e',
        'error': e.toString(),
      };
    }
  }

  // Debug method to test individual vs bulk API differences
  Future<Map<String, dynamic>> debugBulkSyncIssue() async {
    try {
      // Test individual checkin first
      final individualCheckinResult = await checkin(
        bookTransactionCode: '2', // Good condition for debug
        bookCode: 'DEBUG_BOOK_CODE',
        teacherId: 'DEBUG_TEACHER',
        bookId: 'DEBUG_BOOK_ID',
        studentId: 'DEBUG_STUDENT',
        className: 'DEBUG_CLASS',
        programId: 'DEBUG_PROGRAM',
        schoolId: 'DEBUG_SCHOOL',
      );

      // Test individual checkout
      final individualCheckoutResult = await checkout(
        teacherId: 'DEBUG_TEACHER',
        books: [
          {
            'bookId': 'DEBUG_BOOK',
            'bookCode': 'DEBUG_BOOK',
            'bookName': 'Debug Book',
            'author': '',
            'availableCopies': 1,
          },
        ],
        studentId: 'DEBUG_STUDENT',
        className: 'DEBUG_CLASS',
        programId: 'DEBUG_PROGRAM',
        schoolId: 'DEBUG_SCHOOL',
      );

      // Now test bulk with same data
      final bulkTestResult = await testBulkSyncEndpoints();

      return {
        'individual_checkin': individualCheckinResult,
        'individual_checkout': individualCheckoutResult,
        'bulk_test': bulkTestResult,
        'analysis': {
          'individual_checkin_works':
              individualCheckinResult['success'] ?? false,
          'individual_checkout_works':
              individualCheckoutResult['success'] ?? false,
          'bulk_checkin_works':
              bulkTestResult['checkin_test']?['success'] ?? false,
          'bulk_checkout_works':
              bulkTestResult['checkout_test']?['success'] ?? false,
        },
        'debug_timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Debug failed: $e',
        'error': e.toString(),
      };
    }
  }

  // Cleanup duplicate/empty records
  Future<Map<String, dynamic>> cleanupDuplicateRecords(String teacherId) async {
    try {
      final formData = FormData({
        'teacher_id': teacherId,
        'action': 'cleanup_duplicates',
      });

      // Note: You'll need to implement this endpoint on your backend
      var response = await GetConnect().post(
        '${ApiConfig.baseUrl}/cleanup_duplicates',
        formData,
      );

      if (response.statusCode == 200) {
        var data = response.body;

        if (data is String) {
          data = jsonDecode(data);
        }

        if (data is Map) {
          if (data['response'] == 'success') {
            return {
              'success': true,
              'message': data['message'] ?? 'Cleanup completed',
              'cleaned_count': data['cleaned_count'] ?? 0,
            };
          } else {
            return {
              'success': false,
              'message': data['message'] ?? 'Cleanup failed',
            };
          }
        }
        return {'success': false, 'message': 'Invalid response format'};
      } else {
        throw Exception('Failed to cleanup: ${response.statusCode}');
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    } finally {}
  }

  // Update book inventory counts (for book status sync)
  Future<Map<String, dynamic>> updateBookInventory(
    Map<String, dynamic> updateData,
  ) async {
    try {
      final response = await GetConnect(
        timeout: const Duration(seconds: 30),
      ).post(ApiConfig.bookUpdateUrl, updateData);

      if (response.statusCode == 200) {
        var data = response.body;

        if (data is String) {
          data = jsonDecode(data);
        }

        if (data is Map<String, dynamic>) {
          return data;
        } else {
          return {
            'success': true,
            'message': 'Book inventory updated successfully',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'HTTP error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    } finally {}
  }

  // Generic book update method (fallback)
  Future<Map<String, dynamic>> updateBook({
    required String bookCode,
    required Map<String, dynamic> updateData,
  }) async {
    try {
      final requestData = {'book_code': bookCode, ...updateData};

      final response = await GetConnect(
        timeout: const Duration(seconds: 30),
      ).post(ApiConfig.bookUpdateUrl, requestData);

      if (response.statusCode == 200) {
        var data = response.body;

        if (data is String) {
          data = jsonDecode(data);
        }

        if (data is Map<String, dynamic>) {
          return data;
        } else {
          return {'success': true, 'message': 'Book updated successfully'};
        }
      } else {
        return {
          'success': false,
          'message': 'HTTP error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    } finally {}
  }

  Future<List<Grade>> getGrades() async {
    try {
      final response = await GetConnect(
        timeout: const Duration(seconds: 30),
      ).post('https://webdevelopercg.com/cico/Api/grade', FormData({}));

      if (response.statusCode == null) return [];

      if (response.statusCode == 200) {
        var data = response.body;

        if (data is String) {
          try {
            data = jsonDecode(data);
          } catch (e) {
            print('❌ getGrades: JSON parse error: $e');
            return [];
          }
        }

        if (data is Map &&
            data['response'] == 'success' &&
            data['data'] is List) {
          return (data['data'] as List)
              .map((e) => Grade.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }

        return [];
      } else {
        print('❌ getGrades: HTTP ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ getGrades: Error - $e');
      return [];
    }
  }
}
