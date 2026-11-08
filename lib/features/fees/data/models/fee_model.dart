import 'package:cloud_firestore/cloud_firestore.dart';

class FeeModel {
  final String feeId;
  final String studentId;
  final String studentName;
  final double amount;
  final DateTime? dueDate;
  final DateTime? paidDate;
  final String status;
  final String? paymentMethod;
  final String? transactionId;
  final String? receiptUrl;
  final String month;
  final DateTime? createdAt;

  const FeeModel({
    required this.feeId,
    required this.studentId,
    required this.studentName,
    required this.amount,
    this.dueDate,
    this.paidDate,
    this.status = 'pending',
    this.paymentMethod,
    this.transactionId,
    this.receiptUrl,
    required this.month,
    this.createdAt,
  });

  factory FeeModel.fromJson(Map<String, dynamic> json) {
    return FeeModel(
      feeId: json['feeId'] ?? '',
      studentId: json['studentId'] ?? '',
      studentName: json['studentName'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      dueDate: _parseTimestamp(json['dueDate']),
      paidDate: _parseTimestamp(json['paidDate']),
      status: json['status'] ?? 'pending',
      paymentMethod: json['paymentMethod'],
      transactionId: json['transactionId'],
      receiptUrl: json['receiptUrl'],
      month: json['month'] ?? '',
      createdAt: _parseTimestamp(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'feeId': feeId,
      'studentId': studentId,
      'studentName': studentName,
      'amount': amount,
      'dueDate': dueDate?.toIso8601String(),
      'paidDate': paidDate?.toIso8601String(),
      'status': status,
      'paymentMethod': paymentMethod,
      'transactionId': transactionId,
      'receiptUrl': receiptUrl,
      'month': month,
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

  factory FeeModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      return FeeModel(feeId: doc.id, studentId: '', studentName: '', amount: 0, month: '');
    }
    return FeeModel(
      feeId: (data['feeId']?.toString().isEmpty ?? true) ? doc.id : data['feeId'],
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      dueDate: _parseTimestamp(data['dueDate']),
      paidDate: _parseTimestamp(data['paidDate']),
      status: data['status'] ?? 'pending',
      paymentMethod: data['paymentMethod'],
      transactionId: data['transactionId'],
      receiptUrl: data['receiptUrl'],
      month: data['month'] ?? '',
      createdAt: _parseTimestamp(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'feeId': feeId,
      'studentId': studentId,
      'studentName': studentName,
      'amount': amount,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'paidDate': paidDate != null ? Timestamp.fromDate(paidDate!) : null,
      'status': status,
      'paymentMethod': paymentMethod,
      'transactionId': transactionId,
      'receiptUrl': receiptUrl,
      'month': month,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }

  FeeModel copyWith({
    String? status,
    String? paymentMethod,
    String? transactionId,
    String? receiptUrl,
    DateTime? paidDate,
  }) {
    return FeeModel(
      feeId: feeId,
      studentId: studentId,
      studentName: studentName,
      amount: amount,
      dueDate: dueDate,
      paidDate: paidDate ?? this.paidDate,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionId: transactionId ?? this.transactionId,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      month: month,
      createdAt: createdAt,
    );
  }
}
