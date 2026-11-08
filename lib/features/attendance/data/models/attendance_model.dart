import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceRecord {
  final String studentId;
  final String studentName;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String method;
  final bool isLate;

  const AttendanceRecord({
    required this.studentId,
    required this.studentName,
    this.checkIn,
    this.checkOut,
    this.method = 'manual',
    this.isLate = false,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      studentId: json['studentId'] ?? '',
      studentName: json['studentName'] ?? '',
      checkIn: _parseTimestamp(json['checkIn']),
      checkOut: _parseTimestamp(json['checkOut']),
      method: json['method'] ?? 'manual',
      isLate: json['isLate'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'checkIn': checkIn?.toIso8601String(),
      'checkOut': checkOut?.toIso8601String(),
      'method': method,
      'isLate': isLate,
    };
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is DateTime) return value;
    return null;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'checkIn': checkIn,
      'checkOut': checkOut,
      'method': method,
      'isLate': isLate,
    };
  }
}

class AttendanceModel {
  final String date;
  final List<AttendanceRecord> records;
  final int totalPresent;
  final int totalAbsent;

  const AttendanceModel({
    required this.date,
    this.records = const [],
    this.totalPresent = 0,
    this.totalAbsent = 0,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    final recordsList = (json['records'] as List<dynamic>? ?? [])
        .map((r) => AttendanceRecord.fromJson(Map<String, dynamic>.from(r)))
        .toList();
    return AttendanceModel(
      date: json['date'] ?? '',
      records: recordsList,
      totalPresent: json['totalPresent'] ?? 0,
      totalAbsent: json['totalAbsent'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'records': records.map((r) => r.toJson()).toList(),
      'totalPresent': totalPresent,
      'totalAbsent': totalAbsent,
    };
  }

  factory AttendanceModel.empty(String date) {
    return AttendanceModel(date: date, records: [], totalPresent: 0, totalAbsent: 0);
  }

  factory AttendanceModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      return AttendanceModel(date: doc.id, records: [], totalPresent: 0, totalAbsent: 0);
    }
    final recordsList = (data['records'] as List<dynamic>? ?? [])
        .map((r) => AttendanceRecord.fromJson(Map<String, dynamic>.from(r)))
        .toList();
    return AttendanceModel(
      date: data['date'] ?? doc.id,
      records: recordsList,
      totalPresent: data['totalPresent'] ?? 0,
      totalAbsent: data['totalAbsent'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'date': date,
      'records': records.map((r) => r.toFirestore()).toList(),
      'totalPresent': totalPresent,
      'totalAbsent': totalAbsent,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
