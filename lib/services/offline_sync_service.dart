import 'dart:convert';
import 'package:get/get.dart';
import 'package:room_to_read/services/api_service.dart';
import 'package:room_to_read/services/auth_service.dart';
import 'package:room_to_read/services/connectivity_service.dart';
import 'package:room_to_read/services/offline_database_service.dart';
import 'package:room_to_read/controllers/book_controller.dart';
import 'package:room_to_read/controllers/checkin_controller.dart';
import 'package:room_to_read/controllers/home_controller.dart';

class OfflineSyncService extends GetxService {
  final ApiService _apiService = Get.find<ApiService>();
  final ConnectivityService _connectivityService =
      Get.find<ConnectivityService>();
  final OfflineDatabaseService _offlineDb = Get.find<OfflineDatabaseService>();

  final RxBool isSyncing = false.obs;
  final RxInt syncProgress = 0.obs;
  final RxInt totalSyncItems = 0.obs;
  final RxString syncStatus = ''.obs;
  final Rx<DateTime?> lastSyncCompletedAt = Rx<DateTime?>(null);

  bool get didSyncJustComplete {
    if (lastSyncCompletedAt.value == null) return false;
    final diff = DateTime.now().difference(lastSyncCompletedAt.value!);
    return diff.inSeconds < 5;
  }

  /// Main sync method that handles all pending transactions and downloads fresh data
  Future<Map<String, dynamic>> syncAllOfflineData() async {
    if (!_connectivityService.isOnline.value) {
      return {'success': false, 'message': 'इंटरनेट कनेक्शन नहीं है'};
    }

    if (isSyncing.value) {
      print('⚠️ Sync already in progress, waiting for completion...');
      int waitCount = 0;
      while (isSyncing.value && waitCount < 30) {
        await Future.delayed(Duration(seconds: 1));
        waitCount++;
      }

      if (isSyncing.value) {
        print('❌ Sync timeout - forcing reset');
        isSyncing.value = false;
      }
    }

    isSyncing.value = true;
    syncProgress.value = 0;
    syncStatus.value = 'ऑफलाइन सिंक शुरू हो रहा है...';

    try {
      int totalSuccessCount = 0;
      int totalFailureCount = 0;
      List<String> errors = [];
      List<String> syncedItems = [];

      final authService = Get.find<AuthService>();
      final currentUser = authService.currentUser.value;
      if (currentUser == null) {
        return {'success': false, 'message': 'उपयोगकर्ता लॉगिन नहीं है'};
      }

      print(
        '🚀 Starting comprehensive offline sync for user: ${currentUser.code}',
      );

      // Get pending transactions before starting
      final pendingTransactions = await _offlineDb
          .getPendingOfflineTransactions();
      print('📊 Found ${pendingTransactions.length} pending transactions');
      for (int i = 0; i < pendingTransactions.length; i++) {
        final t = pendingTransactions[i];
        print(
          '   [$i] ${t['transaction_type']}: ${t['book_code']} → ${t['student_name']} (sync_status: ${t['sync_status']})',
        );
      }

      // Step 1: Clean up duplicates
      syncStatus.value = 'डुप्लिकेट ट्रांजैक्शन साफ हो रहे हैं...';
      syncProgress.value = 10;

      // Step 2: Sync pending transactions
      if (pendingTransactions.isNotEmpty) {
        syncStatus.value = 'पेंडिंग ट्रांजैक्शन सिंक हो रहे हैं...';
        final pendingResult = await syncAllPendingOfflineTransactions();

        // ✅ CRITICAL: Check successCount > 0, not just success flag
        if (pendingResult['success'] == true &&
            (pendingResult['successCount'] as int? ?? 0) > 0) {
          totalSuccessCount += (pendingResult['successCount'] as int?) ?? 0;
          if (pendingResult['syncedItems'] != null) {
            syncedItems.addAll(List<String>.from(pendingResult['syncedItems']));
          }

          // ✅ CRITICAL: After successful sync, DELETE checked-in books completely from the database
          // When a book is checked in, it's no longer issued, so it should not appear in the checkin list at all
          print('🔄 Processing completed check-in transactions for removal...');
          final db = await _offlineDb.database;
          final allCheckins = await db.query(
            'offline_transactions_enhanced',
            where: 'transaction_type = ?',
            whereArgs: ['checkin'],
          );

          print('   Found ${allCheckins.length} total checkin transactions');

          // Filter for synced checkins (sync_status = 1 or 2)
          final completedCheckins = allCheckins
              .where(
                (t) =>
                    (t['sync_status'] as int?) == 1 ||
                    (t['sync_status'] as int?) == 2,
              )
              .toList();

          print(
            '   Found ${completedCheckins.length} completed/synced checkins to process',
          );

          for (final transaction in completedCheckins) {
            try {
              final bookCode = (transaction['book_code'] as String?) ?? '';
              final transactionId =
                  (transaction['transaction_id'] as String?) ?? '';
              final studentId = (transaction['student_id'] as String?) ?? '';
              final teacherId = (transaction['teacher_id'] as String?) ?? '';

              // ✅ IMPORTANT: DELETE the book completely from checked_out_books
              // The book is no longer issued, so it shouldn't exist in this table
              // CRITICAL FIX: Delete ONLY THIS STUDENT'S checkout, not all checkouts of that book
              if (bookCode.isNotEmpty &&
                  studentId.isNotEmpty &&
                  teacherId.isNotEmpty) {
                // PRIMARY: Delete by bookCode + studentId + teacherId (specific to this student's checkout)
                final deleted = await db.delete(
                  'checked_out_books',
                  where: 'bookCode = ? AND studentId = ? AND teacherId = ?',
                  whereArgs: [bookCode, studentId, teacherId],
                );

                if (deleted > 0) {
                  print(
                    '✅ DELETED $deleted checked-in book(s) from database for bookCode: $bookCode (student: $studentId)',
                  );
                } else {
                  print(
                    '⚠️ No books found to delete for bookCode: $bookCode, student: $studentId, teacher: $teacherId',
                  );
                }
              } else if (bookCode.isNotEmpty) {
                // FALLBACK: If student info not available, use transactionId
                print(
                  '⚠️ Student/Teacher info not available, attempting delete by bookCode only as fallback',
                );
                final deleted = await db.delete(
                  'checked_out_books',
                  where: 'bookCode = ?',
                  whereArgs: [bookCode],
                );

                if (deleted > 0) {
                  print(
                    '✅ DELETED $deleted checked-in book(s) from database using bookCode fallback: $bookCode',
                  );
                }
              }

              // Also try deletion by transactionId as secondary fallback
              if (transactionId.isNotEmpty) {
                final deletedById = await db.delete(
                  'checked_out_books',
                  where: 'transactionId = ?',
                  whereArgs: [transactionId],
                );

                if (deletedById > 0) {
                  print(
                    '✅ DELETED $deletedById checked-in book(s) using transactionId: $transactionId',
                  );
                }
              }
            } catch (e) {
              print('⚠️ Error processing check-in transaction: $e');
            }
          }
        } else {
          final successCount = (pendingResult['successCount'] as int?) ?? 0;
          final failureCount = (pendingResult['failureCount'] as int?) ?? 0;
          totalFailureCount += failureCount;
          errors.add(
            'पेंडिंग ट्रांजैक्शन: ${pendingResult['message']} ($successCount सफल, $failureCount असफल)',
          );
        }
      }
      syncProgress.value = 40;

      // Step 3: Download fresh data
      syncStatus.value = 'नया डेटा डाउनलोड हो रहा है...';
      final downloadResult = await _downloadAndCacheFreshData(currentUser.code);
      if (downloadResult['success'] == true) {
        totalSuccessCount += (downloadResult['totalItems'] as int?) ?? 0;
        syncedItems.add('${downloadResult['totalItems']} नए रिकॉर्ड डाउनलोड');
      } else {
        errors.add('डेटा डाउनलोड: ${downloadResult['message']}');
      }
      syncProgress.value = 100;

      syncStatus.value = 'ऑफलाइन सिंक पूरा हुआ';

      totalSuccessCount += await _syncPendingReadingLevels();

      // ✅ Mark sync as completed for listeners
      if (totalSuccessCount > 0) {
        lastSyncCompletedAt.value = DateTime.now();
        print('🎯 Sync completed successfully - updating signal');

        // ✅ NEW: Cleanup checked_out_books for synced checkins
        // This ensures books don't reappear after sync
        try {
          print(
            '🧹 Cleanup: Removing synced checked-in books from checked_out_books table...',
          );
          final db = await _offlineDb.database;

          // Find all books that have SYNCED checkins and delete them from checked_out_books
          final syncedCheckins = await db.query(
            'offline_transactions_enhanced',
            where:
                'transaction_type = ? AND sync_status = 1 AND teacher_id = ?',
            whereArgs: ['checkin', currentUser.code],
          );

          int cleanupCount = 0;
          for (final checkin in syncedCheckins) {
            final bookCode = checkin['book_code'];
            final studentId = checkin['student_id'];
            final teacherId = checkin['teacher_id'];

            if (bookCode != null && studentId != null && teacherId != null) {
              final deleted = await db.delete(
                'checked_out_books',
                where: 'bookCode = ? AND studentId = ? AND teacherId = ?',
                whereArgs: [bookCode, studentId, teacherId],
              );

              if (deleted > 0) {
                cleanupCount += deleted;
                print(
                  '✅ Cleaned up $deleted checked-out book(s): $bookCode (student: $studentId)',
                );
              }
            }
          }

          if (cleanupCount > 0) {
            print('✅ Cleanup complete: removed $cleanupCount books');
          }
        } catch (e) {
          print('⚠️ Error during cleanup: $e');
        }

        // ✅ NEW: Force UI refresh by triggering controller updates
        try {
          // Refresh home controller if available
          if (Get.isRegistered<HomeController>()) {
            final homeController = Get.find<HomeController>();
            print('🔄 Triggering home controller refresh...');
            await homeController.fetchBookIssueCounts();
            print('✅ Home controller refreshed');
          }

          // Refresh book controller if available
          if (Get.isRegistered<BookController>()) {
            final bookController = Get.find<BookController>();
            print('🔄 Triggering book controller refresh...');
            await bookController.loadBooks();
          }

          // Refresh checkin controller if available
          if (Get.isRegistered<CheckinController>()) {
            final checkinController = Get.find<CheckinController>();
            print('🔄 Triggering checkin controller refresh...');
            await checkinController.fetchCheckedOutBooks();
          }

          print('✅ UI controllers refreshed after sync');
        } catch (e) {
          print('⚠️ Error refreshing UI controllers: $e');
        }
      }

      final message = syncedItems.isNotEmpty
          ? 'सिंक पूरा: ${syncedItems.join(', ')}'
          : 'कोई नया डेटा नहीं मिला';

      return {
        'success': totalSuccessCount > 0 || errors.isEmpty,
        'message': message,
        'successCount': totalSuccessCount,
        'failureCount': totalFailureCount,
        'errors': errors,
        'syncedItems': syncedItems,
      };
    } catch (e) {
      print('❌ Error during offline sync: $e');
      syncStatus.value = 'सिंक में त्रुटि';
      return {'success': false, 'message': 'सिंक में त्रुटि: $e'};
    } finally {
      isSyncing.value = false;
      syncProgress.value = 0;
      totalSyncItems.value = 0;
      print('🏁 Offline sync completed - flag reset');
    }
  }

  /// Sync all pending offline transactions (both checkout and checkin)
  Future<Map<String, dynamic>> syncAllPendingOfflineTransactions() async {
    try {
      int totalSuccessCount = 0;
      int totalFailureCount = 0;
      List<String> errors = [];
      List<String> syncedItems = [];

      final authService = Get.find<AuthService>();
      final currentUser = authService.currentUser.value;

      if (currentUser == null) {
        return {
          'success': false,
          'message': 'उपयोगकर्ता लॉगिन नहीं है',
          'successCount': 0,
          'failureCount': 0,
        };
      }

      print('🧹 Starting sync of pending offline transactions...');

      // Get pending transactions
      final pendingTransactions = await _offlineDb
          .getPendingOfflineTransactions();

      if (pendingTransactions.isEmpty) {
        return {
          'success': true,
          'message': 'कोई पेंडिंग ट्रांजैक्शन नहीं मिला',
          'successCount': 0,
          'failureCount': 0,
          'syncedItems': [],
        };
      }

      print('🔄 Syncing ${pendingTransactions.length} offline transactions');

      // Group transactions by type
      final checkoutTransactions = pendingTransactions
          .where((t) => t['transaction_type'] == 'checkout')
          .toList();
      final checkinTransactions = pendingTransactions
          .where((t) => t['transaction_type'] == 'checkin')
          .toList();

      // ✅ NEW: Sync checkouts in batches to handle API limits
      // Some APIs have limits on how many transactions they can process at once
      if (checkoutTransactions.isNotEmpty) {
        syncStatus.value = 'चेकआउट ट्रांजैक्शन बल्क सिंक हो रहे हैं...';
        try {
          print(
            '\n🔍 Checkout Transactions to sync: ${checkoutTransactions.length} total',
          );
          for (int i = 0; i < checkoutTransactions.length; i++) {
            final t = checkoutTransactions[i];
            print(
              '   [$i] ID: ${t['transaction_id']}, Book: ${t['book_code']}, Student: ${t['student_name']} (Status: ${t['sync_status']})',
            );
          }

          // ✅ NEW: Process in batches of 3 to avoid API limits
          const int batchSize = 3;
          int batchNumber = 0;

          for (int i = 0; i < checkoutTransactions.length; i += batchSize) {
            batchNumber++;
            final endIndex = (i + batchSize < checkoutTransactions.length)
                ? i + batchSize
                : checkoutTransactions.length;
            final batch = checkoutTransactions.sublist(i, endIndex);

            print(
              '\n📦 Processing checkout batch $batchNumber: ${batch.length} transactions (${i + 1}-$endIndex of ${checkoutTransactions.length})',
            );

            print(
              '\n   🔄 Syncing batch $batchNumber checkout transactions...',
            );
            final bulkResult = await _syncBulkCheckoutTransactions(batch);

            print('\n   📊 Batch $batchNumber checkout sync result:');
            print('      Success: ${bulkResult['success']}');
            print('      Synced Count: ${bulkResult['synced_count']}');
            print('      Message: ${bulkResult['message']}');

            // ✅ CRITICAL: Only mark as synced if success AND synced_count > 0
            if (bulkResult['success'] == true &&
                (bulkResult['synced_count'] as num? ?? 0) > 0) {
              final syncedCount = (bulkResult['synced_count'] as num).toInt();
              final sentTransactionIds =
                  (bulkResult['sent_transaction_ids'] as List<dynamic>?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  <String>[];

              totalSuccessCount += syncedCount;
              syncedItems.add('$syncedCount चेकआउट (बैच $batchNumber)');

              print('\n   📊 Batch $batchNumber checkout sync result:');
              print('      Batch size: ${batch.length}');
              print('      Sent to API: ${sentTransactionIds.length}');
              print('      API returned synced_count: $syncedCount');

              // ✅ CRITICAL FIX: Only mark the ACTUAL sent transactions that were synced
              if (sentTransactionIds.isNotEmpty) {
                print('      Marking transactions as synced:');
                for (
                  int j = 0;
                  j < syncedCount && j < sentTransactionIds.length;
                  j++
                ) {
                  final transactionId = sentTransactionIds[j];
                  await _offlineDb.markOfflineTransactionSynced(transactionId);
                  print('         ✅ Marked: $transactionId');
                }
              }

              // Log which ones are still pending
              if (syncedCount < sentTransactionIds.length) {
                print('\n      Still pending (will retry next sync):');
                for (int j = syncedCount; j < sentTransactionIds.length; j++) {
                  print('         ⏳ ${sentTransactionIds[j]}');
                }
              }

              print(
                '✅ Batch $batchNumber complete: $syncedCount of ${sentTransactionIds.length} sent transactions synced',
              );
            } else {
              final failureCount = batch.length;
              totalFailureCount += failureCount;
              final errorMsg = bulkResult['message'] ?? 'Checkout sync failed';
              print(
                '❌ Batch $batchNumber checkout not synced: $errorMsg (0 of $failureCount records)',
              );
              print('   Full result: ${bulkResult.toString()}');
              errors.add('चेकआउट बैच $batchNumber: $errorMsg');
            }

            // Add small delay between batches to avoid overwhelming the API
            if (i + batchSize < checkoutTransactions.length) {
              await Future.delayed(Duration(milliseconds: 500));
            }
          }
        } catch (e) {
          print('❌ Bulk checkout sync failed: $e');
          errors.add('चेकआउट सिंक: $e');
          totalFailureCount += checkoutTransactions.length;
        }
      }

      // A book checked out AND checked in entirely offline (same session,
      // before either synced) has no real server-assigned F4_LCODE to link
      // the checkin to — saveOfflineCheckout() stores the book's own code
      // as a placeholder there instead, since no transaction row exists
      // yet. Now that the checkouts above have (hopefully) synced and been
      // assigned real IDs, patch any pending checkin's stored F4_LCODE with
      // the real value before it gets synced, so its F4_STAT link is
      // correct.
      if (checkoutTransactions.isNotEmpty && checkinTransactions.isNotEmpty) {
        await _backfillCheckinLcodesFromServer(checkinTransactions);
      }

      // ✅ NEW: Sync checkins in batches to handle API limits
      if (checkinTransactions.isNotEmpty) {
        syncStatus.value = 'चेकइन ट्रांजैक्शन बल्क सिंक हो रहे हैं...';
        try {
          print(
            '\n🔍 Checkin Transactions to sync: ${checkinTransactions.length} total',
          );
          for (int i = 0; i < checkinTransactions.length; i++) {
            final t = checkinTransactions[i];
            print(
              '   [$i] ID: ${t['transaction_id']}, Book: ${t['book_code']}, Student: ${t['student_name']} (Status: ${t['sync_status']})',
            );
          }

          // ✅ NEW: Process in batches of 3 to avoid API limits
          const int batchSize = 3;
          int batchNumber = 0;

          for (int i = 0; i < checkinTransactions.length; i += batchSize) {
            batchNumber++;
            final endIndex = (i + batchSize < checkinTransactions.length)
                ? i + batchSize
                : checkinTransactions.length;
            final batch = checkinTransactions.sublist(i, endIndex);

            print(
              '\n📦 Processing checkin batch $batchNumber: ${batch.length} transactions (${i + 1}-$endIndex of ${checkinTransactions.length})',
            );

            final bulkResult = await _syncBulkCheckinTransactions(batch);
            // ✅ CRITICAL: Only mark as synced if success AND synced_count > 0
            if (bulkResult['success'] == true &&
                (bulkResult['synced_count'] as num? ?? 0) > 0) {
              final syncedCount = (bulkResult['synced_count'] as num).toInt();
              final sentTransactionIds =
                  (bulkResult['sent_transaction_ids'] as List<dynamic>?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  <String>[];

              totalSuccessCount += syncedCount;
              syncedItems.add('$syncedCount चेकइन (बैच $batchNumber)');

              print('\n   📊 Batch $batchNumber checkin sync result:');
              print('      Batch size: ${batch.length}');
              print('      Sent to API: ${sentTransactionIds.length}');
              print('      API returned synced_count: $syncedCount');

              // ✅ CRITICAL FIX: Only mark the ACTUAL sent transactions that were synced
              if (sentTransactionIds.isNotEmpty) {
                for (
                  int j = 0;
                  j < syncedCount && j < sentTransactionIds.length;
                  j++
                ) {
                  final transactionId = sentTransactionIds[j];
                  // Find the transaction in batch to get full data
                  final transaction = batch.firstWhere(
                    (t) => t['transaction_id'] == transactionId,
                    orElse: () => {},
                  );
                  if (transaction.isNotEmpty) {
                    await _markCheckinSyncedAndUpdateBooks(transaction);
                    print('   ✅ Marked as synced: $transactionId');
                  }
                }
              }

              // Log which ones are still pending
              if (syncedCount < sentTransactionIds.length) {
                print('\n      Still pending (will retry next sync):');
                for (int j = syncedCount; j < sentTransactionIds.length; j++) {
                  print('         ⏳ ${sentTransactionIds[j]}');
                }
              }

              print(
                '✅ Batch $batchNumber complete: $syncedCount of ${sentTransactionIds.length} sent transactions synced',
              );
            } else {
              final failureCount = batch.length;
              totalFailureCount += failureCount;
              final errorMsg = bulkResult['message'] ?? 'Checkin sync failed';
              print(
                '❌ Batch $batchNumber checkin not synced: $errorMsg (0 of $failureCount records)',
              );
              errors.add('चेकइन बैच $batchNumber: $errorMsg');
            }

            // Add small delay between batches to avoid overwhelming the API
            if (i + batchSize < checkinTransactions.length) {
              await Future.delayed(Duration(milliseconds: 500));
            }
          }
        } catch (e) {
          print('❌ Checkin sync failed: $e');
          errors.add('चेकइन सिंक: $e');
          totalFailureCount += checkinTransactions.length;
        }
      }

      // The quick "बल्क सिंक" button used to only push checkout/checkin
      // transactions — a reading-level edit made offline would stay
      // "pending" forever unless the user happened to run the full
      // "ऑफलाइन सिंक" flow instead, and a student with a stray pending
      // update permanently shadows their real server value (see
      // HybridApiService.getStudents()'s merge logic).
      totalSuccessCount += await _syncPendingReadingLevels();

      // Screens (e.g. the check-in page) listen to lastSyncCompletedAt to
      // know when to refresh — without this, the "बल्क सिंक" button never
      // triggered that refresh, unlike the full offline-sync flow.
      if (totalSuccessCount > 0) {
        lastSyncCompletedAt.value = DateTime.now();
      }

      return {
        'success': totalSuccessCount > 0,
        'successCount': totalSuccessCount,
        'failureCount': totalFailureCount,
        'errors': errors,
        'syncedItems': syncedItems,
      };
    } catch (e) {
      print('❌ Error syncing offline transactions: $e');
      return {
        'success': false,
        'message': 'ऑफलाइन ट्रांजैक्शन सिंक में त्रुटि: $e',
        'successCount': 0,
        'failureCount': 0,
      };
    }
  }

  /// Pushes any not-yet-synced reading-level edits to the server and marks
  /// them synced. Returns the number successfully pushed.
  Future<int> _syncPendingReadingLevels() async {
    var synced = 0;
    final pendingLevels = await _offlineDb.getPendingReadingLevelUpdates();
    for (final u in pendingLevels) {
      try {
        final r = await _apiService.updateReadingLevel(
          u['student_code'],
          u['new_level'],
        );
        if (r['success'] == true) {
          await _offlineDb.markReadingLevelUpdateSynced(u['id']);
          synced++;
        }
      } catch (_) {}
    }
    return synced;
  }

  /// ✅ NEW: Mark check-in as synced and update checked_out_books table
  Future<void> _markCheckinSyncedAndUpdateBooks(
    Map<String, dynamic> transaction,
  ) async {
    try {
      final transactionId = transaction['transaction_id'];
      // `transaction` is a raw offline_transactions_enhanced row, whose
      // column is `book_code` — F4_LCODE only exists inside that table's
      // JSON raw_data column, so reading it directly here always yielded ''
      // and silently no-opped every delete below.
      final bookCode = transaction['book_code'] ?? '';
      final studentId = transaction['student_id'] ?? '';
      final teacherId = transaction['teacher_id'] ?? '';
      final db = await _offlineDb.database;

      print('🔄 Marking check-in as synced: $transactionId');

      // Strategy 1: Mark in offline_transactions_enhanced by transaction_id
      final updated1 = await db.update(
        'offline_transactions_enhanced',
        {'sync_status': 1},
        where: 'transaction_id = ?',
        whereArgs: [transactionId],
      );

      if (updated1 > 0) {
        print('✅ Updated offline_transactions_enhanced: $transactionId');
      }

      // Strategy 2: Mark in offline_transactions (legacy) by id
      final updated2 = await db.update(
        'offline_transactions',
        {'synced': 1},
        where: 'id = ?',
        whereArgs: [transactionId],
      );

      if (updated2 > 0) {
        print('✅ Updated offline_transactions (legacy): $transactionId');
      }

      // ✅ CRITICAL FIX: Mark the ORIGINAL checkout transaction as consumed
      // When a book is checked in, the original checkout transaction should be marked as consumed (sync_status=2)
      // This prevents the system from recreating the book from the old checkout transaction
      if (bookCode.isNotEmpty && studentId.isNotEmpty && teacherId.isNotEmpty) {
        final consumedCheckouts = await db.update(
          'offline_transactions_enhanced',
          {'sync_status': 2}, // Mark as consumed
          where:
              'transaction_type = ? AND book_code = ? AND student_id = ? AND teacher_id = ? AND sync_status = 0',
          whereArgs: ['checkout', bookCode, studentId, teacherId],
        );

        if (consumedCheckouts > 0) {
          print(
            '✅ MARKED original checkout as consumed: bookCode=$bookCode, student=$studentId, $consumedCheckouts rows',
          );
        } else {
          print(
            '⚠️ No pending checkout found to mark as consumed for bookCode: $bookCode, student: $studentId',
          );
        }
      }

      // Strategy 3: DELETE checked_out_books after successful checkin sync
      // After a book is checked in and synced, it's no longer issued
      // So we should remove it from the checked_out_books list
      // CRITICAL FIX: Delete ONLY THIS STUDENT'S checkout, not all checkouts of that book
      if (bookCode.isNotEmpty && studentId.isNotEmpty && teacherId.isNotEmpty) {
        final deleted = await db.delete(
          'checked_out_books',
          where: 'bookCode = ? AND studentId = ? AND teacherId = ?',
          whereArgs: [bookCode, studentId, teacherId],
        );

        if (deleted > 0) {
          print(
            '🗑️ DELETED checked_out_books for bookCode: $bookCode (student: $studentId, $deleted rows)',
          );
        } else {
          print(
            '⚠️ No books found to delete for bookCode: $bookCode, student: $studentId, teacher: $teacherId',
          );
        }
      } else if (bookCode.isNotEmpty) {
        // FALLBACK: If student info not available, use transactionId
        print(
          '⚠️ Student/Teacher info not available in transaction, attempting delete by bookCode only',
        );
        final deleted = await db.delete(
          'checked_out_books',
          where: 'bookCode = ?',
          whereArgs: [bookCode],
        );

        if (deleted > 0) {
          print(
            '🗑️ DELETED checked_out_books for book code: $bookCode ($deleted rows)',
          );
        }
      }

      // Strategy 4: Also try delete by transactionId
      if (transactionId != null && transactionId.isNotEmpty) {
        final deleted2 = await db.delete(
          'checked_out_books',
          where: 'transactionId = ?',
          whereArgs: [transactionId],
        );

        if (deleted2 > 0) {
          print(
            '🗑️ DELETED checked_out_books by transactionId: $transactionId',
          );
        }
      }

      print('✅ Successfully updated database after check-in sync');
    } catch (e) {
      print('❌ Error marking check-in as synced: $e');
    }
  }

  /// Bulk sync checkout transactions
  Future<Map<String, dynamic>> _syncBulkCheckoutTransactions(
    List<Map<String, dynamic>> checkoutTransactions,
  ) async {
    try {
      print(
        '🚀 Starting bulk checkout sync for ${checkoutTransactions.length} transactions',
      );

      final checkoutRecords = <Map<String, dynamic>>[];
      final sentTransactionIds =
          <String>[]; // ✅ Track which transactions are actually sent

      print('\n📋 ========== PREPARING CHECKOUT RECORDS ==========');
      for (final transaction in checkoutTransactions) {
        try {
          final rawData = transaction['raw_data'] as String?;
          if (rawData != null) {
            final data = jsonDecode(rawData);
            // ✅ Use numeric ID for bulk checkout API (stored in 'book_id')
            // F4_LCODE is the M1_CODE/book code (for reference only)
            var bookIdForSync =
                data['book_id']?.toString() ?? ''; // Numeric ID for API

            print('\n   📦 Transaction: ${transaction['transaction_id']}');
            print('      Raw Data: $rawData');

            // ✅ HEALING: If ID looks synthetic (non-numeric), try to resolve it from local DB
            if (int.tryParse(bookIdForSync) == null) {
              print(
                '      ⚠️ Detected synthetic/invalid book ID: $bookIdForSync. Attempting to resolve...',
              );
              try {
                final db = await _offlineDb.database;
                final bookCode = data['F4_LCODE']?.toString() ?? '';

                // Try by code first
                if (bookCode.isNotEmpty) {
                  final books = await db.query(
                    'books',
                    where: 'code = ?',
                    whereArgs: [bookCode],
                    limit: 1,
                  );
                  if (books.isNotEmpty) {
                    final resolvedId = books.first['bookId']?.toString();
                    if (resolvedId != null &&
                        int.tryParse(resolvedId) != null) {
                      bookIdForSync = resolvedId;
                      print(
                        '      ✅ Resolved to numeric ID from DB using code: $bookIdForSync',
                      );
                    }
                  }
                }

                // If still invalid, try by name (fallback)
                if (int.tryParse(bookIdForSync) == null) {
                  // final bookName = data['book_name']?.toString() ?? '';
                  // Clean up synthetic name format if present (e.g. remove _index suffix)
                  // This is "best effort" - booking by name is not yet implemented
                }
              } catch (e) {
                print('      ❌ Error resolving book ID: $e');
              }
            }

            print(
              '      📊 Final Values: book_id=$bookIdForSync, F4_LCODE=${data['F4_LCODE']}, student_id=${data['student_id']}, teacher_id=${data['teacher_id']}',
            );

            checkoutRecords.add({
              // ✅ CRITICAL FIX: Include F4_LCODE (book code) for API compatibility
              'F4_LCODE': data['F4_LCODE'], // ✅ Book code (M1_CODE)
              'teacher_id': data['teacher_id'],
              'book_id': bookIdForSync, // ✅ NUMERIC ID (fallback)
              'student_id': data['student_id'],
              'class': data['class'],
              'program_id': data['program_id'],
              'school_id': data['school_id'],
              'M1_GROUP': data['school_id'], // ✅ NEW: School ID as M1_GROUP
              'M1GROUP1': data['program_id'], // ✅ NEW: Program ID as M1GROUP1
            });
            // ✅ CRITICAL: Track which transaction is being sent
            sentTransactionIds.add(transaction['transaction_id'] as String);
          } else {
            print(
              '      ⚠️ Skipping transaction ${transaction['transaction_id']} - null raw_data',
            );
          }
        } catch (e) {
          print('      ⚠️ Failed to parse checkout transaction: $e');
        }
      }

      print('===================================================\n');

      if (checkoutRecords.isEmpty) {
        print('⚠️ No valid checkout records to send to API');
        return {'success': true, 'synced_count': 0, 'sent_transaction_ids': []};
      }

      print(
        '📤 Sending ${checkoutRecords.length} checkout records (${sentTransactionIds.length} tracked)',
      );
      // Log each record being sent
      for (int i = 0; i < checkoutRecords.length; i++) {
        final record = checkoutRecords[i];
        final transId = sentTransactionIds[i];
        print(
          '   [$i] Transaction: $transId → Book: ${record['book_id']}, Student: ${record['student_id']}',
        );
      }

      final result = await _apiService.bulkSyncCheckout(checkoutRecords);

      print('🔄 API Response for bulk checkout sync:');
      print('   success: ${result['success']}');
      print('   synced_count: ${result['synced_count']}');
      print('   message: ${result['message']}');
      print('   Full response: ${result.toString()}');

      return {
        'success': result['success'] == true || result['synced_count'] != null,
        'synced_count': result['synced_count'] ?? checkoutRecords.length,
        'message': result['message'] ?? 'Checkout sync completed',
        'sent_transaction_ids':
            sentTransactionIds, // ✅ Return the actual transaction IDs that were sent
      };
    } catch (e) {
      print('❌ Error in bulk checkout sync: $e');
      return {'success': false, 'message': 'Bulk checkout sync error: $e'};
    }
  }

  /// Patches pending checkin transactions' stored F4_LCODE with the real,
  /// server-assigned value for the matching checkout, now that offline
  /// checkouts synced above have a genuine transaction row. Matches by
  /// book_id + student_id (the same fields `checked_out_books` caching
  /// already keys on) per teacher.
  Future<void> _backfillCheckinLcodesFromServer(
    List<Map<String, dynamic>> checkinTransactions,
  ) async {
    try {
      final db = await _offlineDb.database;
      final teacherIds = checkinTransactions
          .map((t) => t['teacher_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      for (final teacherId in teacherIds) {
        List<dynamic> serverBooks;
        try {
          serverBooks = await _apiService.getCheckedOutBooks(
            teacherId: teacherId,
          );
        } catch (e) {
          print(
            '⚠️ Could not fetch checked-out books to backfill F4_LCODE for teacher $teacherId: $e',
          );
          continue;
        }

        for (final t in checkinTransactions) {
          if (t['teacher_id']?.toString() != teacherId) continue;
          final rawDataStr = t['raw_data'] as String?;
          if (rawDataStr == null) continue;

          Map<String, dynamic> data;
          try {
            data = jsonDecode(rawDataStr) as Map<String, dynamic>;
          } catch (_) {
            continue;
          }

          final bookId = data['book_id']?.toString() ?? '';
          final studentId = data['student_id']?.toString() ?? '';
          if (bookId.isEmpty || studentId.isEmpty) continue;

          final match = serverBooks
              .cast<Map>()
              .where(
                (b) =>
                    (b['bookId']?.toString() ?? '') == bookId &&
                    (b['studentId']?.toString() ?? '') == studentId,
              )
              .firstOrNull;

          final realLcode = match?['F4_LCODE']?.toString();
          if (match == null || realLcode == null || realLcode.isEmpty) {
            continue;
          }
          if (data['F4_LCODE']?.toString() == realLcode) {
            continue; // already correct
          }

          data['F4_LCODE'] = realLcode;
          final updatedRawData = jsonEncode(data);
          await db.update(
            'offline_transactions_enhanced',
            {'raw_data': updatedRawData},
            where: 'transaction_id = ?',
            whereArgs: [t['transaction_id']],
          );
          // Also patch the in-memory transaction, since this same sync pass
          // reads `checkinTransactions` (built before this backfill ran) to
          // push checkins right after this — without this, the DB update
          // above would only take effect on a *future* sync attempt, after
          // this pass had already sent the stale F4_LCODE and marked the
          // checkin as synced.
          t['raw_data'] = updatedRawData;
          print(
            '✅ Backfilled real F4_LCODE=$realLcode for pending checkin ${t['transaction_id']}',
          );
        }
      }
    } catch (e) {
      print('❌ Error backfilling checkin F4_LCODE values: $e');
    }
  }

  /// Bulk sync checkin transactions
  Future<Map<String, dynamic>> _syncBulkCheckinTransactions(
    List<Map<String, dynamic>> checkinTransactions,
  ) async {
    try {
      print(
        '🚀 Starting bulk checkin sync for ${checkinTransactions.length} transactions',
      );

      final checkinRecords = <Map<String, dynamic>>[];
      final sentTransactionIds =
          <String>[]; // ✅ Track which transactions are actually sent

      for (final transaction in checkinTransactions) {
        try {
          final transactionId = transaction['transaction_id'] as String;
          final rawData = transaction['raw_data'] as String?;

          print('\n📋 ========== PROCESSING CHECKIN TRANSACTION ==========');
          print('   Transaction ID: $transactionId');
          print('   Raw Data Present: ${rawData != null}');

          if (rawData != null) {
            final data = jsonDecode(rawData);

            // ✅ Debug: Log all fields from raw_data
            print('   📊 Raw Data Fields:');
            print('      F4_BT: ${data['F4_BT']}');
            print('      F4_LCODE: ${data['F4_LCODE']}');
            print('      teacher_id: ${data['teacher_id']}');
            print('      book_id: ${data['book_id']}');
            print('      student_id: ${data['student_id']}');
            print('      class: ${data['class']}');
            print('      program_id: ${data['program_id']}');
            print('      school_id: ${data['school_id']}');

            // ✅ Use numeric ID and M1_CODE from stored data
            // book_id: NUMERIC ID (needed by bulk API)
            // F4_LCODE: M1_CODE (book code)
            final bookIdForSync = data['book_id']; // Numeric ID
            final m1CodeForSync = data['F4_LCODE']; // M1_CODE
            final teacherId = data['teacher_id'];
            final studentId = data['student_id'];
            final className = data['class'];
            final programId = data['program_id'];
            final schoolId = data['school_id'];
            final f4Bt = data['F4_BT'] ?? '2';

            print('   ✅ Extracted Values:');
            print('      bookIdForSync: $bookIdForSync (numeric ID)');
            print('      m1CodeForSync: $m1CodeForSync (M1_CODE)');
            print('      teacherId: $teacherId');
            print('      studentId: $studentId');
            print('      className: $className');
            print('      programId: $programId');
            print('      schoolId: $schoolId');
            print('      f4Bt: $f4Bt');

            final checkinRecord = {
              'F4_BT': f4Bt,
              'F4_LCODE': m1CodeForSync, // M1_CODE for checkin API
              'teacher_id': teacherId,
              'book_id': bookIdForSync, // ✅ NUMERIC ID (needed by bulk API)
              'student_id': studentId,
              'class': className,
              'program_id': programId,
              'school_id': schoolId,
              'M1_GROUP': schoolId, // ✅ NEW: School ID as M1_GROUP
              'M1GROUP1': programId, // ✅ NEW: Program ID as M1GROUP1
            };

            print('   📤 Final Checkin Record:');
            checkinRecord.forEach((key, value) {
              print('      $key: $value');
            });

            checkinRecords.add(checkinRecord);
            // ✅ CRITICAL: Track which transaction is being sent
            sentTransactionIds.add(transactionId);
            print('   ✅ Record added to batch');
          } else {
            print('⚠️ Skipping transaction $transactionId - null raw_data');
          }
          print('===================================================\n');
        } catch (e) {
          print('⚠️ Failed to parse checkin transaction: $e');
          print('   Transaction ID: ${transaction['transaction_id']}');
        }
      }

      if (checkinRecords.isEmpty) {
        print('⚠️ No valid checkin records to send to API');
        return {'success': true, 'synced_count': 0, 'sent_transaction_ids': []};
      }

      print('\n📊 ========== BULK CHECKIN BATCH SUMMARY ==========');
      print('   Total Records: ${checkinRecords.length}');
      print('   Tracked Transaction IDs: ${sentTransactionIds.length}');
      print('   Records to Send:');

      // Log each record being sent
      for (int i = 0; i < checkinRecords.length; i++) {
        final record = checkinRecords[i];
        final transId = sentTransactionIds[i];
        print('\n   [$i] Transaction: $transId');
        print('       F4_BT: ${record['F4_BT']}');
        print('       F4_LCODE: ${record['F4_LCODE']}');
        print('       book_id: ${record['book_id']}');
        print('       student_id: ${record['student_id']}');
        print('       teacher_id: ${record['teacher_id']}');
        print('       class: ${record['class']}');
        print('       program_id: ${record['program_id']}');
        print('       school_id: ${record['school_id']}');
        print('       M1_GROUP: ${record['M1_GROUP']}');
        print('       M1GROUP1: ${record['M1GROUP1']}');
      }
      print('===================================================\n');

      print('📤 Sending ${checkinRecords.length} checkin records to API...');
      final result = await _apiService.bulkSyncCheckin(checkinRecords);

      print('\n✅ ========== BULK CHECKIN API RESPONSE ==========');
      print('   Success: ${result['success']}');
      print('   Synced Count: ${result['synced_count']}');
      print('   Message: ${result['message']}');
      print('   Full Response: ${result.toString()}');
      print('===================================================\n');

      return {
        'success': result['success'] == true || result['synced_count'] != null,
        'synced_count': result['synced_count'] ?? checkinRecords.length,
        'message': result['message'] ?? 'Checkin sync completed',
        'sent_transaction_ids':
            sentTransactionIds, // ✅ Return the actual transaction IDs that were sent
      };
    } catch (e) {
      print('❌ Error in bulk checkin sync: $e');
      return {'success': false, 'message': 'Bulk checkin sync error: $e'};
    }
  }

  /// Download fresh data from server and cache it locally
  Future<Map<String, dynamic>> _downloadAndCacheFreshData(String userId) async {
    try {
      int totalItems = 0;

      // Download students
      syncStatus.value = 'छात्र डेटा डाउनलोड हो रहा है...';
      final students = await _apiService.getStudents(group1: userId);
      if (students.isNotEmpty) {
        final db = await _offlineDb.database;
        final localRows = await db.query('students');
        final localMap = {for (var r in localRows) r['code']: r};

        await _offlineDb.saveStudentsOffline(
          students.map((s) {
            final code = s['M1_CODE']?.toString() ?? '';
            final local = localMap[code];
            return {
              'id': code,
              'code': code,
              'name': s['M1_NAME']?.toString() ?? '',
              // M1_OPP is the confirmed grade field (see Student.fromJson);
              // M1_GROUP2N isn't even a real column in the backend schema,
              // so using it as the only source here left className empty
              // for every student downloaded through this full-sync path.
              'className':
                  (s['M1_OPP']?.toString().isNotEmpty == true
                      ? s['M1_OPP'].toString()
                      : s['M1_GROUP2N']?.toString()) ??
                  '',
              'readingLevel':
                  local?['readingLevel'] ??
                  int.tryParse(s['M1_TXT2']?.toString() ?? '') ??
                  0,
              'currentLevel':
                  local?['currentLevel'] ??
                  int.tryParse(s['M1_TXT2']?.toString() ?? '') ??
                  0,
              'previousLevel':
                  local?['previousLevel'] ??
                  int.tryParse(s['M1_TXT1']?.toString() ?? '') ??
                  0,
              'booksIssued': 0,
              'lastUpdated': DateTime.now().toIso8601String(),
              'teacherId': s['M1_GROUP2']?.toString() ?? '',
              'rawData': jsonEncode(s),
            };
          }).toList(),
        );
        totalItems += students.length;
      }

      // Download books
      syncStatus.value = 'किताब डेटा डाउनलोड हो रहा है...';
      final books = await _apiService.getBooks(userId: userId);
      if (books.isNotEmpty) {
        await _offlineDb.saveBooksOffline(
          books
              .map(
                (b) => {
                  'bookId':
                      b['M1_CODE']?.toString() ?? '', // Numeric ID (M1_CODE)
                  'book_id':
                      b['M1_CODE']?.toString() ?? '', // Numeric ID (M1_CODE)
                  'code': b['M1_NO']?.toString() ?? '', // Book code (M1_NO)
                  'no': b['M1_CODE']?.toString() ?? '', // Numeric ID backup
                  'name': b['M1_NAME']?.toString() ?? '',
                  'txt1': b['M1_TXT1']?.toString() ?? '0',
                  'txt2': b['M1_TXT2']?.toString() ?? '0',
                  'txt3': b['M1_TXT3']?.toString() ?? '0',
                  'txt4': b['M1_TXT4']?.toString() ?? '0',
                  'txt5': b['M1_TXT5']?.toString() ?? '0',
                  'lname': b['M1_LNAME']?.toString() ?? '',
                  'groupN': b['M1_GROUPN']?.toString() ?? '',
                  'rawData': jsonEncode(b),
                },
              )
              .toList(),
        );
        totalItems += books.length;
      }

      // Download checked out books (these should be marked as synced since they come from API)
      syncStatus.value = 'जारी किताबों का डेटा डाउनलोड हो रहा है...';
      final checkedOutBooks = await _apiService.getCheckedOutBooks(
        teacherId: userId,
      );
      if (checkedOutBooks.isNotEmpty) {
        await _offlineDb.saveCheckedOutBooksOffline(
          checkedOutBooks.cast<Map<String, dynamic>>(),
          teacherId: userId,
        );
        totalItems += checkedOutBooks.length;
      }

      return {
        'success': true,
        'message': 'सभी डेटा सफलतापूर्वक डाउनलोड हुआ',
        'totalItems': totalItems,
      };
    } catch (e) {
      print('❌ Error downloading fresh data: $e');
      return {'success': false, 'message': 'डेटा डाउनलोड में त्रुटि: $e'};
    }
  }

  /// Bulk sync offline transactions only (without downloading fresh data)
  Future<Map<String, dynamic>> bulkSyncOfflineTransactions() async {
    if (!_connectivityService.isOnline.value) {
      return {'success': false, 'message': 'इंटरनेट कनेक्शन नहीं है'};
    }

    if (isSyncing.value) {
      return {'success': false, 'message': 'सिंक पहले से चल रहा है'};
    }

    isSyncing.value = true;
    syncProgress.value = 0;

    try {
      final stats = await getSyncStats();
      final pendingCount = stats['pendingTransactions'] ?? 0;

      if (pendingCount == 0) {
        return {
          'success': true,
          'message': 'कोई पेंडिंग ट्रांजैक्शन नहीं मिला',
          'successCount': 0,
          'failureCount': 0,
        };
      }

      syncStatus.value = 'बल्क सिंक शुरू हो रहा है...';
      syncProgress.value = 50;

      final result = await syncAllPendingOfflineTransactions();

      syncProgress.value = 100;
      syncStatus.value = 'बल्क सिंक पूरा हुआ';

      // Mark sync completion
      if (result['success'] == true) {
        lastSyncCompletedAt.value = DateTime.now();
      }

      return result;
    } catch (e) {
      print('❌ Error in bulk sync: $e');
      return {'success': false, 'message': 'बल्क सिंक में त्रुटि: $e'};
    } finally {
      isSyncing.value = false;
      syncProgress.value = 0;
    }
  }

  /// Download fresh data method
  Future<Map<String, dynamic>> downloadFreshData({
    String? teacherId,
    String? userId,
  }) async {
    if (!_connectivityService.isOnline.value) {
      return {'success': false, 'message': 'इंटरनेट कनेक्शन नहीं है'};
    }

    try {
      return await _downloadAndCacheFreshData(userId ?? teacherId ?? '');
    } catch (e) {
      return {'success': false, 'message': 'डेटा डाउनलोड में त्रुटि: $e'};
    }
  }

  /// Get sync statistics
  Future<Map<String, dynamic>> getSyncStats() async {
    final offlineStats = await _offlineDb.getOfflineStats();
    final pendingItems = await _offlineDb.getPendingSyncItems();

    return {
      'offlineStudents': offlineStats['students'],
      'offlineBooks': offlineStats['books'],
      'offlineClasses': offlineStats['classes'],
      'checkedOutBooks': offlineStats['checkedOutBooks'],
      'pendingTransactions': offlineStats['pendingTransactions'],
      'pendingSyncItems': pendingItems.length,
      'pendingReadingLevelUpdates': offlineStats['pendingReadingLevelUpdates'],
      'isOnline': _connectivityService.isOnline.value,
      'connectionType': _connectivityService.connectionType.value,
    };
  }

  /// Check if sync is in progress
  bool get isSyncInProgress => isSyncing.value;

  /// Reset sync flag for recovery
  void resetSyncFlag() {
    print('🔄 Force resetting sync flag');
    isSyncing.value = false;
    syncStatus.value = 'निष्क्रिय';
  }
}
