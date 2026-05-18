import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:room_to_read/models/book_model.dart' as book_model;
import 'package:room_to_read/services/hybrid_api_service.dart';
import 'package:room_to_read/services/auth_service.dart';
import 'package:room_to_read/services/connectivity_service.dart';
import 'package:room_to_read/services/offline_database_service.dart';
import 'package:room_to_read/services/api_service.dart';
import 'package:room_to_read/config/api_config.dart';

class BookController extends GetxController {
  late HybridApiService apiService;
  final AuthService _authService = Get.find<AuthService>();

  var books = <book_model.Book>[].obs;
  var filteredBooks = <book_model.Book>[].obs;
  var searchQuery = ''.obs;
  var sortBy = 'नाम'.obs; // Default sort by name
  var isLoading = false.obs;

  final sortOptions = ['नाम', 'रीडिंग लेवल', 'उपलब्ध प्रतियां'];

  @override
  void onInit() {
    super.onInit();
    apiService = Get.find<HybridApiService>();

    // Run system diagnostic
    checkSystemStatus();

    // Test API connection
    testApiConnection();

    loadBooks();
  }

  Future<void> loadBooks() async {
    try {
      isLoading.value = true;
      print('🔄 Starting to load books...');

      // Clear existing data to force fresh load
      books.clear();
      filteredBooks.clear();

      final currentUser = _authService.currentUser.value;
      if (currentUser == null) {
        print('❌ No user logged in');
        Get.snackbar('Error', 'कृपया पहले लॉगिन करें');
        return;
      }

      print('✅ Current user: ${currentUser.name} (${currentUser.code})');

      // Check connectivity status
      final connectivityService = Get.find<ConnectivityService>();
      final isOnline = connectivityService.isOnline.value;
      print('📶 Connection status: ${isOnline ? "Online" : "Offline"}');

      // Fetch books using hybrid service with user_id to get book_deploy endpoint
      print('📚 Fetching books for teacher: ${currentUser.code}');
      final bookList = await apiService.getBooks(userId: currentUser.code);
      print(
        '✅ Books loaded for teacher ${currentUser.code}: ${bookList.length} items',
      );

      // Always set the books, even if empty
      books.value = bookList;

      if (bookList.isEmpty) {
        print('⚠️ No books returned from hybrid API');

        // Show appropriate message based on connection status
        if (isOnline) {
          Get.snackbar(
            'जानकारी',
            'सर्वर से कोई किताब नहीं मिली। कृपया "डेटा डाउनलोड करें" बटन दबाएं।',
            duration: const Duration(seconds: 5),
          );
        } else {
          // Check if there's any data in offline storage
          final offlineDb = Get.find<OfflineDatabaseService>();
          final offlineBooks = await offlineDb.getBooksOffline();

          if (offlineBooks.isEmpty) {
            Get.snackbar(
              'ऑफलाइन मोड',
              'कोई ऑफलाइन डेटा नहीं मिला। पहले ऑनलाइन होकर "डेटा डाउनलोड करें" बटन दबाएं।',
              duration: const Duration(seconds: 5),
            );
          } else {
            // This shouldn't happen - hybrid API should have returned these books
            print(
              '⚠️ WARNING: Offline DB has ${offlineBooks.length} books but hybrid API returned 0',
            );
            print('   This indicates a problem in HybridApiService.getBooks()');
            Get.snackbar(
              'ऑफलाइन मोड',
              'आप ऑफलाइन हैं लेकिन ${offlineBooks.length} किताबें स्थानीय रूप से उपलब्ध हैं।',
              duration: const Duration(seconds: 3),
            );
          }
        }
      } else {
        print('✅ Books loaded from hybrid API: ${books.length} items');
        print('   Sample books:');
        for (int i = 0; i < (bookList.length > 3 ? 3 : bookList.length); i++) {
          final book = bookList[i];
          print(
            '   ✓ Book ${i + 1}: ${book.title} (Code: ${book.bookCode}, ID: ${book.bookId})',
          );
        }
      }

      // Debug: Print first few books with detailed copy information
      if (books.isNotEmpty) {
        for (int i = 0; i < (books.length > 3 ? 3 : books.length); i++) {
          final book = books[i];
          print('📖 Book ${i + 1}: ${book.title} by ${book.author}');
          print(
            '   Total: ${book.totalCopies}, Available: ${book.availableCopies}, Issued: ${book.issuedCopies}',
          );
        }
      }

      applyFiltersAndSort();
    } catch (e) {
      print('❌ Error in loadBooks: $e');
      Get.snackbar(
        'त्रुटि',
        'किताबें लोड करने में समस्या: ${e.toString()}',
        duration: const Duration(seconds: 5),
      );
    } finally {
      isLoading.value = false;
    }
  }

  // Method to force refresh data by clearing cache
  Future<void> forceRefresh() async {
    try {
      // Clear offline cache
      final offlineDb = Get.find<OfflineDatabaseService>();
      await offlineDb.clearBooksCache();

      // Reload books
      await loadBooks();

      Get.snackbar(
        'सफल',
        'डेटा रीफ्रेश हो गया',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('❌ Error in forceRefresh: $e');
      Get.snackbar('त्रुटि', 'रीफ्रेश करने में समस्या: $e');
    }
  }

  // Method to manually download and cache data
  Future<void> downloadAndCacheData() async {
    try {
      isLoading.value = true;
      print('🔄 Manually downloading and caching data...');

      final currentUser = _authService.currentUser.value;
      if (currentUser == null) {
        Get.snackbar('Error', 'कृपया पहले लॉगिन करें');
        return;
      }

      // Check connectivity
      final connectivityService = Get.find<ConnectivityService>();
      if (!connectivityService.isOnline.value) {
        Get.snackbar('ऑफलाइन', 'डेटा डाउनलोड के लिए इंटरनेट कनेक्शन चाहिए');
        return;
      }

      // Use the hybrid service's new download method
      final result = await apiService.downloadAllDataForOffline();

      if (result['success'] == true) {
        // Reload books from offline storage to verify
        await loadBooks();

        Get.snackbar(
          'सफल',
          result['message'] ?? 'डेटा डाउनलोड हो गया',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      } else {
        Get.snackbar(
          'त्रुटि',
          result['message'] ?? 'डेटा डाउनलोड में समस्या',
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      print('❌ Error in downloadAndCacheData: $e');
      Get.snackbar('त्रुटि', 'डेटा डाउनलोड में समस्या: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void searchBooks(String query) {
    print('🔍 searchBooks called with query: "$query"');
    print('   Current books count: ${books.length}');
    print('   Current search query: "${searchQuery.value}"');

    searchQuery.value = query;

    // Always apply filters, don't wait for load
    if (books.isEmpty && query.isNotEmpty) {
      print('⚠️ Books list is empty but search query provided ("$query")');
      print('   Attempting to reload books...');

      // Reload in background without blocking UI
      loadBooks()
          .then((_) {
            print('✅ Books reloaded after search. New count: ${books.length}');
            applyFiltersAndSort();
          })
          .catchError((e) {
            print('❌ Error reloading books: $e');
            applyFiltersAndSort(); // Apply filters even if load failed
          });
    } else {
      print('   Applying filters for query: "$query"');
      applyFiltersAndSort();
    }
  }

  void setSortBy(String sort) {
    sortBy.value = sort;
    applyFiltersAndSort();
  }

  void applyFiltersAndSort() {
    var result = books.toList();

    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      result = result
          .where(
            (book) =>
                book.title.toLowerCase().contains(query) ||
                book.bookRomanName.toLowerCase().contains(query) ||
                book.bookLocalName.toLowerCase().contains(query) ||
                book.author.toLowerCase().contains(query) ||
                book.bookCode.toLowerCase().contains(query) ||
                book.bookId.toLowerCase().contains(query),
          )
          .toList();
    }

    switch (sortBy.value) {
      case 'रीडिंग लेवल':
        result.sort((a, b) => a.readingLevel.compareTo(b.readingLevel));
        break;
      case 'उपलब्ध प्रतियां':
        result.sort((a, b) => b.availableCopies.compareTo(a.availableCopies));
        break;
      case 'नाम':
      default:
        result.sort((a, b) => a.title.compareTo(b.title));
        break;
    }

    filteredBooks.value = result;
  }

  // Test method to verify API connectivity
  Future<void> testApiConnection() async {
    print('🧪 === API CONNECTION TEST ===');

    try {
      final currentUser = _authService.currentUser.value;
      if (currentUser == null) {
        print('❌ Cannot test API - no user logged in');
        return;
      }

      print('🔄 Testing direct API call...');
      final apiService = Get.find<ApiService>();

      // Test without user_id first
      print('📞 Testing general books endpoint...');
      final generalBooks = await apiService.getBooks();
      print('✅ General books API: ${generalBooks.length} books');

      // Test with user_id
      print('📞 Testing user-specific books endpoint...');
      final userBooks = await apiService.getBooks(userId: currentUser.code);
      print('✅ User-specific books API: ${userBooks.length} books');

      if (userBooks.isNotEmpty) {
        print('📖 Sample book: ${userBooks.first}');
      }
    } catch (e) {
      print('❌ API Test Failed: $e');
    }

    print('🧪 === END API TEST ===');
  }

  Future<void> checkSystemStatus() async {
    print('🔍 === SYSTEM DIAGNOSTIC ===');

    // Check user authentication
    final currentUser = _authService.currentUser.value;
    print(
      '👤 User Status: ${currentUser != null ? "Logged in as ${currentUser.name} (${currentUser.code})" : "Not logged in"}',
    );

    // Check connectivity
    final connectivityService = Get.find<ConnectivityService>();
    print(
      '📶 Connectivity: ${connectivityService.isOnline.value ? "Online" : "Offline"}',
    );
    print('🌐 Connection Type: ${connectivityService.connectionType.value}');

    // Check offline database
    final offlineDb = Get.find<OfflineDatabaseService>();
    try {
      final offlineBooks = await offlineDb.getBooksOffline();
      print('📱 Offline Books: ${offlineBooks.length} books stored');
    } catch (e) {
      print('❌ Offline Database Error: $e');
    }

    // Check API endpoints
    print('🔗 API Endpoints:');
    print('   Book URL: ${ApiConfig.bookUrl}');
    print('   Book Deploy URL: ${ApiConfig.bookDeployUrl}');

    print('🔍 === END DIAGNOSTIC ===');
  }
}
