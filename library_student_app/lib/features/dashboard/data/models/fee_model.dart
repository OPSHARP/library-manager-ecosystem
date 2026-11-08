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
    required this.month,
    this.createdAt,
  });

  factory FeeModel.fromJson(Map<String, dynamic> json) {
    return FeeModel(
      feeId: json['feeId'] ?? '',
      studentId: json['studentId'] ?? '',
      studentName: json['studentName'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      dueDate: _parseDate(json['dueDate']),
      paidDate: _parseDate(json['paidDate']),
      status: json['status'] ?? 'pending',
      paymentMethod: json['paymentMethod'],
      transactionId: json['transactionId'],
      month: json['month'] ?? '',
      createdAt: _parseDate(json['createdAt']),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    return DateTime.tryParse(v.toString());
  }

  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending';
  bool get isOverdue => status == 'overdue';
}
