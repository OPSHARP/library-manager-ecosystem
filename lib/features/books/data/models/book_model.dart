import 'package:cloud_firestore/cloud_firestore.dart';

class BookModel {
  static const _sentinel = Object();

  final String bookId;
  final String title;
  final String author;
  final String? isbn;
  final String? publisher;
  final String? category;
  final String? rackNumber;
  final int? publishedYear;
  final String? language;
  final int? pages;
  final int totalCopies;
  final int availableCopies;
  final String? studentId;
  final String? studentName;
  final DateTime? issueDate;
  final DateTime? returnDate;
  final String status; // 'available', 'issued', 'returned'
  final DateTime? createdAt;

  const BookModel({
    required this.bookId,
    required this.title,
    this.author = '',
    this.isbn,
    this.publisher,
    this.category,
    this.rackNumber,
    this.publishedYear,
    this.language,
    this.pages,
    this.totalCopies = 1,
    this.availableCopies = 1,
    this.studentId,
    this.studentName,
    this.issueDate,
    this.returnDate,
    this.status = 'available',
    this.createdAt,
  });

  factory BookModel.fromJson(Map<String, dynamic> json) {
    return BookModel(
      bookId: json['bookId'] ?? '',
      title: json['title'] ?? '',
      author: json['author'] ?? '',
      isbn: json['isbn'],
      publisher: json['publisher'],
      category: json['category'],
      rackNumber: json['rackNumber'],
      publishedYear: json['publishedYear'] is int ? json['publishedYear'] as int? : int.tryParse('${json['publishedYear'] ?? ''}'),
      language: json['language'],
      pages: json['pages'] is int ? json['pages'] as int? : int.tryParse('${json['pages'] ?? ''}'),
      totalCopies: json['totalCopies'] is int ? json['totalCopies'] as int : int.tryParse('${json['totalCopies'] ?? 1}') ?? 1,
      availableCopies: json['availableCopies'] is int ? json['availableCopies'] as int : int.tryParse('${json['availableCopies'] ?? 1}') ?? 1,
      studentId: json['studentId'],
      studentName: json['studentName'],
      issueDate: _parseTimestamp(json['issueDate']),
      returnDate: _parseTimestamp(json['returnDate']),
      status: json['status'] ?? 'available',
      createdAt: _parseTimestamp(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bookId': bookId,
      'title': title,
      'author': author,
      'isbn': isbn,
      'publisher': publisher,
      'category': category,
      'rackNumber': rackNumber,
      'publishedYear': publishedYear,
      'language': language,
      'pages': pages,
      'totalCopies': totalCopies,
      'availableCopies': availableCopies,
      'studentId': studentId,
      'studentName': studentName,
      'issueDate': issueDate?.toIso8601String(),
      'returnDate': returnDate?.toIso8601String(),
      'status': status,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is DateTime) return value;
    return null;
  }

  factory BookModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      return BookModel(bookId: doc.id, title: '');
    }
    return BookModel(
      bookId: data['bookId'] ?? doc.id,
      title: data['title'] ?? '',
      author: data['author'] ?? '',
      isbn: data['isbn'],
      publisher: data['publisher'],
      category: data['category'],
      rackNumber: data['rackNumber'],
      publishedYear: data['publishedYear'] is int ? data['publishedYear'] as int? : int.tryParse('${data['publishedYear'] ?? ''}'),
      language: data['language'],
      pages: data['pages'] is int ? data['pages'] as int? : int.tryParse('${data['pages'] ?? ''}'),
      totalCopies: data['totalCopies'] is int ? data['totalCopies'] as int : int.tryParse('${data['totalCopies'] ?? 1}') ?? 1,
      availableCopies: data['availableCopies'] is int ? data['availableCopies'] as int : int.tryParse('${data['availableCopies'] ?? 1}') ?? 1,
      studentId: data['studentId'],
      studentName: data['studentName'],
      issueDate: _parseTimestamp(data['issueDate']),
      returnDate: _parseTimestamp(data['returnDate']),
      status: data['status'] ?? 'available',
      createdAt: _parseTimestamp(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'bookId': bookId,
      'title': title,
      'author': author,
      'isbn': isbn,
      'publisher': publisher,
      'category': category,
      'rackNumber': rackNumber,
      'publishedYear': publishedYear,
      'language': language,
      'pages': pages,
      'totalCopies': totalCopies,
      'availableCopies': availableCopies,
      'studentId': studentId,
      'studentName': studentName,
      'issueDate': issueDate,
      'returnDate': returnDate,
      'status': status,
      'createdAt': createdAt,
    };
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'author': author,
        'category': category,
        'isbn': isbn,
        'status': status,
        'totalCopies': totalCopies,
        'availableCopies': availableCopies,
        'studentName': studentName,
      };

  static List<Map<String, dynamic>> booksToMap(List<BookModel> books) =>
      books.map((b) => b.toMap()).toList();

  BookModel copyWith({
    String? title,
    String? author,
    Object? isbn = _sentinel,
    Object? publisher = _sentinel,
    Object? category = _sentinel,
    Object? rackNumber = _sentinel,
    Object? publishedYear = _sentinel,
    Object? language = _sentinel,
    Object? pages = _sentinel,
    int? totalCopies,
    int? availableCopies,
    Object? studentId = _sentinel,
    Object? studentName = _sentinel,
    Object? issueDate = _sentinel,
    Object? returnDate = _sentinel,
    String? status,
    DateTime? createdAt,
  }) {
    return BookModel(
      bookId: bookId,
      title: title ?? this.title,
      author: author ?? this.author,
      isbn: isbn == _sentinel ? this.isbn : isbn as String?,
      publisher: publisher == _sentinel ? this.publisher : publisher as String?,
      category: category == _sentinel ? this.category : category as String?,
      rackNumber: rackNumber == _sentinel ? this.rackNumber : rackNumber as String?,
      publishedYear: publishedYear == _sentinel ? this.publishedYear : publishedYear as int?,
      language: language == _sentinel ? this.language : language as String?,
      pages: pages == _sentinel ? this.pages : pages as int?,
      totalCopies: totalCopies ?? this.totalCopies,
      availableCopies: availableCopies ?? this.availableCopies,
      studentId: studentId == _sentinel ? this.studentId : studentId as String?,
      studentName: studentName == _sentinel ? this.studentName : studentName as String?,
      issueDate: issueDate == _sentinel ? this.issueDate : issueDate as DateTime?,
      returnDate: returnDate == _sentinel ? this.returnDate : returnDate as DateTime?,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
