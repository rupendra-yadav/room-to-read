enum BookStatus { red, orange, green }

class Book {
  // ===== Raw API fields =====
  final String programCode;
  final String bookId;
  final String bookCode;

  final String bookName; // fallback (can be "Not Available")
  final String bookRomanName; // English / Roman
  final String bookLocalName; // Hindi / Local

  final String authorName;

  final int totalCopy;
  final int availableCopy;
  final int issuedCopy;
  final int damagedCopy;
  final int lostCopy;
  final int returnedCopy;

  final bool isActive;
  final int readingLevel; // Add reading level property

  // ===== Constructor =====
  Book({
    required this.programCode,
    required this.bookId,
    required this.bookCode,
    required this.bookName,
    required this.bookRomanName,
    required this.bookLocalName,
    required this.authorName,
    required this.totalCopy,
    required this.availableCopy,
    required this.issuedCopy,
    required this.damagedCopy,
    required this.lostCopy,
    required this.returnedCopy,
    required this.isActive,
    required this.readingLevel,
  });

  // ===== UI Computed Properties =====

  /// Priority: Local → Roman → API name
  String get title {
    if (bookLocalName.isNotEmpty) return bookLocalName;
    if (bookRomanName.isNotEmpty) return bookRomanName;
    return bookName;
  }

  String get author => authorName;

  int get availableCopies => availableCopy;
  int get totalCopies => totalCopy;
  int get issuedCopies => issuedCopy;
  int get damagedCopies => damagedCopy;
  int get lostCopies => lostCopy;
  int get returnedCopies => returnedCopy;

  /// Status text for UI
  String get statusText => availableCopy > 0 ? 'उपलब्ध' : 'अनुपलब्ध';

  /// Color logic (simple + correct)
  BookStatus get statusColor {
    if (!isActive) return BookStatus.red;
    if (availableCopy == 0) return BookStatus.red;
    if (availableCopy < (totalCopy / 2)) return BookStatus.orange;
    return BookStatus.green;
  }

  // ===== JSON Mapper =====
  factory Book.fromJson(Map<String, dynamic> json) {
    // NOTE: API returns fields like: code, no, name, txt1-txt5, lname, etc.
    // We map these to M1_ naming convention used elsewhere

    return Book(
      // programCode
      programCode:
          json['program_code']?.toString() ??
          json['type']?.toString() ??
          json['M1_TYPE']?.toString() ??
          '',

      // bookId (numeric ID) - the unique identifier for the book
      // Priority: M1_CODE → book_id → code → no → ''
      bookId:
          json['M1_CODE']?.toString() ??
          json['book_id']?.toString() ??
          json['id']?.toString() ??
          json['code']?.toString() ??
          json['no']?.toString() ??
          '',

      // bookCode (book code like IN-LLP-...)
      // Priority: M1_NO → book_code → code → ''
      bookCode:
          json['M1_NO']?.toString() ??
          json['book_code']?.toString() ??
          json['code']?.toString() ??
          '',

      // bookName - try multiple field variations
      bookName:
          json['book_name']?.toString() ??
          json['M1_NAME']?.toString() ??
          json['name']?.toString() ??
          '',

      bookRomanName:
          json['book_roman_name']?.toString() ??
          json['M1_FNAME']?.toString() ??
          json['roman_name']?.toString() ??
          json['add1']?.toString() ??
          '',

      bookLocalName:
          json['book_local_name']?.toString() ??
          json['M1_LNAME']?.toString() ??
          json['local_name']?.toString() ??
          json['add2']?.toString() ??
          json['lname']?.toString() ??
          json['book_name']?.toString() ??
          json['M1_NAME']?.toString() ??
          json['name']?.toString() ??
          '',

      // Author name
      authorName:
          json['author_name']?.toString() ??
          json['M1_MNAME']?.toString() ??
          json['author']?.toString() ??
          json['lname']?.toString() ??
          '',

      // Copy counts - handle both naming conventions
      // txt1, txt2, txt3, txt4, txt5 are from raw API in order
      totalCopy: _toInt(json['total_copy'] ?? json['txt2'] ?? json['M1_TXT2']),
      availableCopy: _toInt(
        json['avail_copy'] ?? json['txt3'] ?? json['M1_TXT3'],
      ),
      issuedCopy: _toInt(json['issue_copy'] ?? json['txt4'] ?? json['M1_TXT4']),
      damagedCopy: _toInt(
        json['damage_copy'] ?? json['txt5'] ?? json['M1_TXT5'],
      ),
      lostCopy: _toInt(json['lost_copy'] ?? json['txt1'] ?? json['M1_TXT1']),
      returnedCopy: _toInt(json['return_copy']),

      // Active status
      isActive:
          json['is_active'] == true ||
          json['is_active']?.toString() == '1' ||
          json['M1_BT']?.toString().toLowerCase() != 'false',

      readingLevel: _toInt(json['reading_level'] ?? json['groupN']),
    );
  }

  // ===== Helper =====
  static int _toInt(dynamic value) {
    if (value == null || value.toString().toLowerCase() == 'null') return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }
}
