import 'package:cloud_firestore/cloud_firestore.dart';

class BookTransactionModel {
  final String transactionId;
  final String bookId;
  final String bookTitle;
  final String studentId;
  final String studentName;
  final String action; // 'issued', 'returned'
  final DateTime? issueDate;
  final DateTime? returnDate;
  final DateTime? createdAt;

  const BookTransactionModel({
    required this.transactionId,
    required this.bookId,
    required this.bookTitle,
    required this.studentId,
    required this.studentName,
    required this.action,
    this.issueDate,
    this.returnDate,
    this.createdAt,
  });

  factory BookTransactionModel.fromJson(Map<String, dynamic> json) {
    return BookTransactionModel(
      transactionId: json['transactionId'] ?? '',
      bookId: json['bookId'] ?? '',
      bookTitle: json['bookTitle'] ?? '',
      studentId: json['studentId'] ?? '',
      studentName: json['studentName'] ?? '',
      action: json['action'] ?? 'issued',
      issueDate: _parseTimestamp(json['issueDate']),
      returnDate: _parseTimestamp(json['returnDate']),
      createdAt: _parseTimestamp(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transactionId': transactionId,
      'bookId': bookId,
      'bookTitle': bookTitle,
      'studentId': studentId,
      'studentName': studentName,
      'action': action,
      'issueDate': issueDate?.toIso8601String(),
      'returnDate': returnDate?.toIso8601String(),
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

  factory BookTransactionModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      return BookTransactionModel(transactionId: doc.id, bookId: '', bookTitle: '', studentId: '', studentName: '', action: 'issued');
    }
    return BookTransactionModel(
      transactionId: data['transactionId'] ?? doc.id,
      bookId: data['bookId'] ?? '',
      bookTitle: data['bookTitle'] ?? '',
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      action: data['action'] ?? 'issued',
      issueDate: _parseTimestamp(data['issueDate']),
      returnDate: _parseTimestamp(data['returnDate']),
      createdAt: _parseTimestamp(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'transactionId': transactionId,
      'bookId': bookId,
      'bookTitle': bookTitle,
      'studentId': studentId,
      'studentName': studentName,
      'action': action,
      'issueDate': issueDate,
      'returnDate': returnDate,
      'createdAt': createdAt,
    };
  }
}
