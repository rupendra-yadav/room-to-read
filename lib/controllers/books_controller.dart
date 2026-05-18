import 'package:get/get.dart';
import 'package:room_to_read/models/book_model.dart';
import 'package:room_to_read/services/hybrid_api_service.dart';
import 'package:room_to_read/services/auth_service.dart';

class BooksController extends GetxController {
  late HybridApiService apiService;
  final AuthService _authService = Get.find<AuthService>();
  
  var books = <Book>[].obs;
  var filteredBooks = <Book>[].obs;
  var searchQuery = ''.obs;
  var isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    apiService = Get.find<HybridApiService>();
    loadBooks();
  }

  Future<void> loadBooks() async {
    try {
      isLoading.value = true;
      
      final currentUser = _authService.currentUser.value;
      if (currentUser == null) {
        print('No user logged in');
        Get.snackbar('Error', 'Please login first');
        return;
      }

      // Fetch books using hybrid service with userId to get book_deploy endpoint
      final bookList = await apiService.getBooks(userId: currentUser.code);
      print('Books loaded for teacher ${currentUser.code}: ${bookList.length} items');
      
      books.value = bookList;
      
      print('Books set: ${books.length} items');
      filteredBooks.value = books;
    } catch (e) {
      print('Error in loadBooks: $e');
      Get.snackbar('Error', 'Failed to load books: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void searchBooks(String query) {
    searchQuery.value = query;
    if (query.isEmpty) {
      filteredBooks.value = books;
    } else {
      filteredBooks.value = books
          .where((book) =>
              book.bookName.toLowerCase().contains(query.toLowerCase()) ||
              book.bookCode.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
  }
}
