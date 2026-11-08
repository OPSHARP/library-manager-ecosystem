import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseModel {
  final String expenseId;
  final String title;
  final double amount;
  final String category;
  final DateTime date;
  final String? notes;
  final String paymentMethod;
  final DateTime? createdAt;

  const ExpenseModel({
    required this.expenseId,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.notes,
    this.paymentMethod = 'Cash',
    this.createdAt,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      expenseId: json['expenseId'] ?? '',
      title: json['title'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      category: json['category'] ?? 'Other',
      date: _parseTimestamp(json['date']) ?? DateTime.now(),
      notes: json['notes'],
      paymentMethod: json['paymentMethod'] ?? 'Cash',
      createdAt: _parseTimestamp(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'expenseId': expenseId,
      'title': title,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'notes': notes,
      'paymentMethod': paymentMethod,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory ExpenseModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ExpenseModel(
      expenseId: data['expenseId'] ?? doc.id,
      title: data['title'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      category: data['category'] ?? 'Other',
      date: _parseTimestamp(data['date']) ?? DateTime.now(),
      notes: data['notes'],
      paymentMethod: data['paymentMethod'] ?? 'Cash',
      createdAt: _parseTimestamp(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'expenseId': expenseId,
      'title': title,
      'amount': amount,
      'category': category,
      'date': Timestamp.fromDate(date),
      'notes': notes,
      'paymentMethod': paymentMethod,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is DateTime) return value;
    return null;
  }

  ExpenseModel copyWith({
    String? expenseId,
    String? title,
    double? amount,
    String? category,
    DateTime? date,
    String? notes,
    String? paymentMethod,
    DateTime? createdAt,
  }) {
    return ExpenseModel(
      expenseId: expenseId ?? this.expenseId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

