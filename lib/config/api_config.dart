class ApiConfig {
  static const String baseUrl = 'https://webdevelopercg.com/cico/Api';
  static const String loginEndpoint = '/login';
  static const String userDetailsEndpoint = '/user_details';
  static const String studentEndpoint = '/student';
  static const String classEndpoint = '/class';
  static const String studentDetailsEndpoint = '/student_details';
  static const String bookEndpoint = '/book';
  static const String bookDeployEndpoint = '/book_deploy';
  static const String bookDetailsEndpoint = '/book_details';
  static const String bookDeployDetailsEndpoint = '/book_deploy_details';
  static const String updateReadingLevelEndpoint = '/update_reading_level';
  static const String checkoutEndpoint = '/get_checkout';
  static const String checkinEndpoint = '/get_checkin';
  static const String checkedOutBooksEndpoint = '/get_book_issue'; 
  static const String bookIssueCountEndpoint = '/get_book_issue_count';
  static const String cicoReportEndpoint = '/get_book_issue_report';
  static const String analyticsEndpoint = '/get_analytics';
  static const String studentBookHistoryEndpoint = '/get_student_wise_book_history';
  
  // Bulk sync endpoints - Updated to match your exact API URLs
  static const String bulkCheckinEndpoint = '/get_checkin_bulk';
  static const String bulkCheckoutEndpoint = '/get_checkout_bulk';
  
  // Book update endpoint for inventory management
  static const String bookUpdateEndpoint = '/update_book_inventory';
  
  static String get loginUrl => '$baseUrl$loginEndpoint';
  static String get userDetailsUrl => '$baseUrl$userDetailsEndpoint';
  static String get studentUrl => '$baseUrl$studentEndpoint';
  static String get classUrl => '$baseUrl$classEndpoint';
  static String get studentDetailsUrl => '$baseUrl$studentDetailsEndpoint';
  static String get bookUrl => '$baseUrl$bookEndpoint';
  static String get bookDeployUrl => '$baseUrl$bookDeployEndpoint';
  static String get bookDetailsUrl => '$baseUrl$bookDetailsEndpoint';
  static String get bookDeployDetailsUrl => '$baseUrl$bookDeployDetailsEndpoint';
  static String get updateReadingLevelUrl => '$baseUrl$updateReadingLevelEndpoint';
  static String get checkoutUrl => '$baseUrl$checkoutEndpoint';
  static String get checkinUrl => '$baseUrl$checkinEndpoint';
  static String get checkedOutBooksUrl => '$baseUrl$checkedOutBooksEndpoint';
  static String get bookIssueCountUrl => '$baseUrl$bookIssueCountEndpoint';
  static String get cicoReportUrl => '$baseUrl$cicoReportEndpoint';
  static String get analyticsUrl => '$baseUrl$analyticsEndpoint';
  static String get studentBookHistoryUrl => '$baseUrl$studentBookHistoryEndpoint';
  
  // Bulk sync URLs
  static String get bulkCheckinUrl => '$baseUrl$bulkCheckinEndpoint';
  static String get bulkCheckoutUrl => '$baseUrl$bulkCheckoutEndpoint';
  
  // Book update URL
  static String get bookUpdateUrl => '$baseUrl$bookUpdateEndpoint';
}
