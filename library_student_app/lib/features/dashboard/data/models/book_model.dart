import 'package:cloud_firestore/cloud_firestore.dart';

class BookModel {
  final String bookId;
  final String title;
  final String author;
  final String? isbn;
  final String? category;
  final String? rackNumber;
  final int totalCopies;
  final int availableCopies;
  final String? studentId;
  final String? studentName;
  final DateTime? issueDate;
  final DateTime? returnDate;
  final String status;
  final DateTime? createdAt;

  const BookModel({
    required this.bookId,
    required this.title,
    this.author = '',
    this.isbn,
    this.category,
    this.rackNumber,
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
      category: json['category'],
      rackNumber: json['rackNumber'],
      totalCopies: json['totalCopies'] is int
          ? json['totalCopies'] as int
          : int.tryParse('${json['totalCopies'] ?? 1}') ?? 1,
      availableCopies: json['availableCopies'] is int
          ? json['availableCopies'] as int
          : int.tryParse('${json['availableCopies'] ?? 1}') ?? 1,
      studentId: json['studentId'],
      studentName: json['studentName'],
      issueDate: _parseDate(json['issueDate']),
      returnDate: _parseDate(json['returnDate']),
      status: json['status'] ?? 'available',
      createdAt: _parseDate(json['createdAt']),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    return DateTime.tryParse(v.toString());
  }

  bool get isIssued => status == 'issued';
  bool get isReturned => status == 'returned';
}
