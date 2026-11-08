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
      checkIn: _parseDate(json['checkIn']),
      checkOut: _parseDate(json['checkOut']),
      method: json['method'] ?? 'manual',
      isLate: json['isLate'] ?? false,
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    return DateTime.tryParse(v.toString());
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

  factory AttendanceModel.fromJson(Map<String, dynamic> json, {String? forStudentId}) {
    var rawList = json['records'] as List<dynamic>? ?? [];
    if (forStudentId != null && forStudentId.isNotEmpty) {
      rawList = rawList.where((r) => r is Map && r['studentId'] == forStudentId).toList();
    }
    final recordsList = rawList
        .map((r) => AttendanceRecord.fromJson(Map<String, dynamic>.from(r)))
        .toList();
    return AttendanceModel(
      date: json['date'] ?? '',
      records: recordsList,
      totalPresent: json['totalPresent'] ?? 0,
      totalAbsent: json['totalAbsent'] ?? 0,
    );
  }
}
