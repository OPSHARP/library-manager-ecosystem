import 'package:cloud_firestore/cloud_firestore.dart';

class StudentPortalSession {
  final String studentId;
  final String studentName;
  final String? assignedSeatId;
  final String? assignedSeatNumber;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String feeStatus; // 'paid', 'due', 'overdue'
  final DateTime? feeDueDate;

  const StudentPortalSession({
    required this.studentId,
    required this.studentName,
    this.assignedSeatId,
    this.assignedSeatNumber,
    this.checkInTime,
    this.checkOutTime,
    this.feeStatus = 'paid',
    this.feeDueDate,
  });

  bool get isCheckedIn => checkInTime != null && checkOutTime == null;

  factory StudentPortalSession.fromFirestore(Map<String, dynamic> data) {
    return StudentPortalSession(
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? 'Student',
      assignedSeatId: data['assignedSeatId'],
      assignedSeatNumber: data['assignedSeatNumber'],
      checkInTime: data['checkInTime'] != null
          ? (data['checkInTime'] as Timestamp).toDate()
          : null,
      checkOutTime: data['checkOutTime'] != null
          ? (data['checkOutTime'] as Timestamp).toDate()
          : null,
      feeStatus: data['feeStatus'] ?? 'paid',
      feeDueDate: data['feeDueDate'] != null
          ? (data['feeDueDate'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'assignedSeatId': assignedSeatId,
      'assignedSeatNumber': assignedSeatNumber,
      'checkInTime': checkInTime != null ? Timestamp.fromDate(checkInTime!) : null,
      'checkOutTime': checkOutTime != null ? Timestamp.fromDate(checkOutTime!) : null,
      'feeStatus': feeStatus,
      'feeDueDate': feeDueDate != null ? Timestamp.fromDate(feeDueDate!) : null,
    };
  }
}
