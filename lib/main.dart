import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:room_to_read/bindings/analysis_binding.dart';
import 'package:room_to_read/bindings/analytics_filter_binding.dart';
import 'package:room_to_read/bindings/book_binding.dart';
import 'package:room_to_read/bindings/checkin_binding.dart';
import 'package:room_to_read/bindings/checkout_binding.dart';
import 'package:room_to_read/bindings/home_binding.dart';
import 'package:room_to_read/bindings/login_binding.dart';
import 'package:room_to_read/bindings/offline_sync_binding.dart';
import 'package:room_to_read/bindings/profile_binding.dart';
import 'package:room_to_read/bindings/report_binding.dart';
import 'package:room_to_read/bindings/student_binding.dart';
import 'package:room_to_read/config/theme.dart';
import 'package:room_to_read/services/api_service.dart';
import 'package:room_to_read/services/auth_service.dart';
import 'package:room_to_read/services/connectivity_service.dart';
import 'package:room_to_read/services/data_preloader_service.dart';
import 'package:room_to_read/services/hybrid_api_service.dart';
import 'package:room_to_read/services/offline_database_service.dart';
import 'package:room_to_read/services/offline_sync_service.dart';
import 'package:room_to_read/services/enhanced_offline_service.dart';
import 'package:room_to_read/views/analysis_page.dart';
import 'package:room_to_read/views/analytics_filter_page.dart';
import 'package:room_to_read/views/books_list_page.dart';
import 'package:room_to_read/views/checkin_page.dart';
import 'package:room_to_read/views/checkout_page.dart';
import 'package:room_to_read/views/cico_report_page.dart';
import 'package:room_to_read/views/home_page.dart';
import 'package:room_to_read/views/login_page.dart';
import 'package:room_to_read/views/offline_sync_page.dart';
import 'package:room_to_read/views/profile_page.dart';
import 'package:room_to_read/views/splash_page.dart';
import 'package:room_to_read/views/students_list_page.dart';

void main() async {
  print('🚀 App starting...');
  WidgetsFlutterBinding.ensureInitialized();
  print('✅ Flutter binding initialized');

  // Enable detailed HTTP logging for debugging
  print('🔍 Enabling HTTP request logging...');

  try {
    // Initialize core services
    await Get.putAsync(() => AuthService().init());
    print('✅ AuthService initialized');

    // Initialize offline services
    final offlineDbService = Get.put(OfflineDatabaseService());
    // Ensure database is initialized by accessing it
    await offlineDbService.database;
    print('✅ OfflineDatabaseService initialized');

    Get.put(ConnectivityService());
    print('✅ ConnectivityService initialized');

    Get.put(ApiService());
    print('✅ ApiService initialized');

    // Initialize Enhanced Offline Service before HybridApiService
    Get.put(EnhancedOfflineService());
    print('✅ EnhancedOfflineService initialized');

    Get.put(HybridApiService());
    print('✅ HybridApiService initialized');

    Get.put(OfflineSyncService());
    print('✅ OfflineSyncService initialized');

    Get.put(DataPreloaderService());
    print('✅ DataPreloaderService initialized');

    // Offline sync service is ready for manual sync calls
    print('✅ OfflineSyncService ready');
  } catch (e) {
    print('❌ Error initializing services: $e');
    // Initialize with default values if there's an error
    try {
      Get.put(AuthService());
      await Get.find<AuthService>().init();
    } catch (authError) {
      print('❌ Error initializing AuthService fallback: $authError');
      Get.put(AuthService());
    }

    try {
      Get.put(OfflineDatabaseService());
      await Get.find<OfflineDatabaseService>().database;
    } catch (dbError) {
      print('❌ Error initializing OfflineDatabaseService fallback: $dbError');
      Get.put(OfflineDatabaseService());
    }

    Get.put(ConnectivityService());
    Get.put(ApiService());
    Get.put(EnhancedOfflineService());
    Get.put(HybridApiService());
    Get.put(OfflineSyncService());
    Get.put(DataPreloaderService());
  }

  print('🎯 Running app...');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Room To Read',
      theme: AppTheme.lightTheme,
      initialRoute: '/splash',
      debugShowCheckedModeBanner: false,
      getPages: [
        GetPage(name: '/splash', page: () => const SplashPage()),
        GetPage(
          name: '/login',
          page: () => const LoginPage(),
          binding: LoginBinding(),
        ),
        GetPage(
          name: '/',
          page: () => const HomePage(),
          binding: HomeBinding(),
        ),
        GetPage(
          name: '/profile',
          page: () => const ProfilePage(),
          binding: ProfileBinding(),
        ),
        GetPage(
          name: '/books',
          page: () => const BooksListPage(),
          binding: BookBinding(),
        ),
        GetPage(
          name: '/students',
          page: () => const StudentsListPage(),
          binding: StudentBinding(),
        ),
        GetPage(
          name: '/cico-report',
          page: () => const CicoReportPage(),
          binding: ReportBinding(),
        ),
        GetPage(
          name: '/checkout',
          page: () => CheckoutPage(),
          binding: CheckoutBinding(),
        ),
        GetPage(
          name: '/checkin',
          page: () => const CheckinPage(),
          binding: CheckinBinding(),
        ),
        GetPage(
          name: '/analysis-filter',
          page: () => const AnalyticsFilterPage(),
          binding: AnalyticsFilterBinding(),
        ),
        GetPage(
          name: '/analysis',
          page: () => const AnalysisPage(),
          binding: AnalysisBinding(),
        ),
        GetPage(
          name: '/offline-sync',
          page: () => const OfflineSyncPage(),
          binding: OfflineSyncBinding(),
        ),
      ],
    );
  }
}
