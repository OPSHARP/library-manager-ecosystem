import 'package:cloud_firestore/cloud_firestore.dart';

class StudentModel {
  final String studentId;
  final String name;
  final String phone;
  final String? parentPhone;
  final String? address;
  final String? photoUrl;
  final String? seatId;
  final String? seatNumber;
  final DateTime? joiningDate;
  final String feePlan;
  final double feeAmount;
  final String feeStatus;
  final DateTime? nextDueDate;
  final bool isActive;
  final String status;
  final DateTime? createdAt;

  const StudentModel({
    required this.studentId,
    required this.name,
    required this.phone,
    this.parentPhone,
    this.address,
    this.photoUrl,
    this.seatId,
    this.seatNumber,
    this.joiningDate,
    this.feePlan = 'Monthly',
    this.feeAmount = 0,
    this.feeStatus = 'pending',
    this.nextDueDate,
    this.isActive = true,
    this.status = 'active',
    this.createdAt,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      studentId: json['studentId'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      parentPhone: json['parentPhone'],
      address: json['address'],
      photoUrl: json['photoUrl'],
      seatId: json['seatId'],
      seatNumber: json['seatNumber'],
      joiningDate: _parseDate(json['joiningDate']),
      feePlan: json['feePlan'] ?? 'Monthly',
      feeAmount: (json['feeAmount'] ?? 0).toDouble(),
      feeStatus: json['feeStatus'] ?? 'pending',
      nextDueDate: _parseDate(json['nextDueDate']),
      isActive: json['isActive'] ?? true,
      status: json['status'] ?? 'active',
      createdAt: _parseDate(json['createdAt']),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    return DateTime.tryParse(v.toString());
  }

  String get feeStatusDisplay {
    switch (feeStatus) {
      case 'paid': return 'Paid';
      case 'overdue': return 'Overdue';
      default: return 'Pending';
    }
  }
}
