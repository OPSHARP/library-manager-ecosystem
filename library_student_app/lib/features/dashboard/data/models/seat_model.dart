import 'package:cloud_firestore/cloud_firestore.dart';

class ShiftAssignment {
  final String studentId;
  final String studentName;
  final DateTime? renewalDate;

  const ShiftAssignment({
    required this.studentId,
    required this.studentName,
    this.renewalDate,
  });

  factory ShiftAssignment.fromJson(Map<String, dynamic> json) {
    return ShiftAssignment(
      studentId: json['studentId'] ?? '',
      studentName: json['studentName'] ?? '',
      renewalDate: _parseDate(json['renewalDate']),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    return DateTime.tryParse(v.toString());
  }
}

class SeatReservation {
  final String reservedBy;
  final String reservedByName;
  final DateTime reservedFrom;
  final DateTime reservedUntil;

  const SeatReservation({
    required this.reservedBy,
    required this.reservedByName,
    required this.reservedFrom,
    required this.reservedUntil,
  });

  factory SeatReservation.fromJson(Map<String, dynamic> json) {
    return SeatReservation(
      reservedBy: json['reservedBy'] ?? '',
      reservedByName: json['reservedByName'] ?? '',
      reservedFrom: _parseDate(json['reservedFrom']) ?? DateTime.now(),
      reservedUntil: _parseDate(json['reservedUntil']) ?? DateTime.now(),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    return DateTime.tryParse(v.toString());
  }
}

class SeatModel {
  final String seatId;
  final String seatNumber;
  final String category;
  final String status;
  final String? assignedStudentId;
  final String? assignedStudentName;
  final double price;
  final int row;
  final int column;
  final DateTime? renewalDate;
  final SeatReservation? reservation;
  final Map<String, ShiftAssignment>? shifts;

  const SeatModel({
    required this.seatId,
    required this.seatNumber,
    this.category = 'Normal',
    this.status = 'available',
    this.assignedStudentId,
    this.assignedStudentName,
    this.price = 0,
    this.row = 0,
    this.column = 0,
    this.renewalDate,
    this.reservation,
    this.shifts,
  });

  factory SeatModel.fromJson(Map<String, dynamic> json) {
    Map<String, ShiftAssignment>? parsedShifts;
    if (json['shifts'] is Map) {
      parsedShifts = (json['shifts'] as Map).map(
        (k, v) => MapEntry(
          k.toString(),
          ShiftAssignment.fromJson(Map<String, dynamic>.from(v as Map)),
        ),
      );
    }

    return SeatModel(
      seatId: json['seatId'] ?? '',
      seatNumber: json['seatNumber'] ?? '',
      category: json['category'] ?? 'Normal',
      status: json['status'] ?? 'available',
      assignedStudentId: json['assignedStudentId'],
      assignedStudentName: json['assignedStudentName'],
      price: (json['price'] ?? 0).toDouble(),
      row: json['row'] ?? 0,
      column: json['column'] ?? 0,
      renewalDate: _parseDate(json['renewalDate']),
      reservation: json['reservation'] != null
          ? SeatReservation.fromJson(Map<String, dynamic>.from(json['reservation']))
          : null,
      shifts: parsedShifts,
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    return DateTime.tryParse(v.toString());
  }

  bool get isAvailable => status == 'available';
  bool get isOccupied => status == 'occupied';
  bool get isReserved => status == 'reserved';

  bool isShiftAvailable(String shift) {
    if (status == 'maintenance' || status == 'reserved') return false;
    if (assignedStudentId != null && assignedStudentId!.isNotEmpty) return false;
    if (shifts == null || shifts!.isEmpty) return true;
    final isFullDayRequest = shift.toLowerCase().contains('full');
    if (isFullDayRequest) return shifts!.isEmpty;
    final hasFullDayOccupied = shifts!.keys.any((k) => k.toLowerCase().contains('full'));
    if (hasFullDayOccupied) return false;
    return !shifts!.keys.any((k) =>
        k.toLowerCase().contains(shift.toLowerCase()) ||
        shift.toLowerCase().contains(k.toLowerCase()));
  }
}
