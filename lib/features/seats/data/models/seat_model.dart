import 'package:cloud_firestore/cloud_firestore.dart';

/// Assignment of a seat to a student for a specific shift.
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
      renewalDate: SeatModel._parseTimestamp(json['renewalDate']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'renewalDate': renewalDate?.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'renewalDate': renewalDate,
    };
  }
}

/// Reservation details attached to a seat when it is reserved.
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
      reservedFrom: _parseTimestamp(json['reservedFrom']) ?? DateTime.now(),
      reservedUntil: _parseTimestamp(json['reservedUntil']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reservedBy': reservedBy,
      'reservedByName': reservedByName,
      'reservedFrom': reservedFrom.toIso8601String(),
      'reservedUntil': reservedUntil.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'reservedBy': reservedBy,
      'reservedByName': reservedByName,
      'reservedFrom': reservedFrom,
      'reservedUntil': reservedUntil,
    };
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is DateTime) return value;
    return null;
  }

  SeatReservation copyWith({
    String? reservedBy,
    String? reservedByName,
    DateTime? reservedFrom,
    DateTime? reservedUntil,
  }) {
    return SeatReservation(
      reservedBy: reservedBy ?? this.reservedBy,
      reservedByName: reservedByName ?? this.reservedByName,
      reservedFrom: reservedFrom ?? this.reservedFrom,
      reservedUntil: reservedUntil ?? this.reservedUntil,
    );
  }
}

class SeatModel {
  static const _sentinel = Object();

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
  final DateTime? createdAt;
  final SeatReservation? reservation;
  /// Shift-wise student assignments: {'morning': ShiftAssignment, 'evening': ShiftAssignment, etc.}
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
    this.createdAt,
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
      renewalDate: _parseTimestamp(json['renewalDate']),
      createdAt: _parseTimestamp(json['createdAt']),
      reservation: json['reservation'] != null
          ? SeatReservation.fromJson(
              Map<String, dynamic>.from(json['reservation']))
          : null,
      shifts: parsedShifts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'seatId': seatId,
      'seatNumber': seatNumber,
      'category': category,
      'status': status,
      'assignedStudentId': assignedStudentId,
      'assignedStudentName': assignedStudentName,
      'price': price,
      'row': row,
      'column': column,
      'renewalDate': renewalDate?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'reservation': reservation?.toJson(),
      'shifts': shifts?.map((k, v) => MapEntry(k, v.toJson())),
    };
  }

  factory SeatModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      return SeatModel(seatId: doc.id, seatNumber: '');
    }

    Map<String, ShiftAssignment>? parsedShifts;
    if (data['shifts'] is Map) {
      parsedShifts = (data['shifts'] as Map).map(
        (k, v) => MapEntry(
          k.toString(),
          ShiftAssignment(
            studentId: v['studentId'] ?? '',
            studentName: v['studentName'] ?? '',
            renewalDate: _parseTimestamp(v['renewalDate']),
          ),
        ),
      );
    }

    return SeatModel(
      seatId: data['seatId'] ?? doc.id,
      seatNumber: data['seatNumber'] ?? '',
      category: data['category'] ?? 'Normal',
      status: data['status'] ?? 'available',
      assignedStudentId: data['assignedStudentId'],
      assignedStudentName: data['assignedStudentName'],
      price: (data['price'] ?? 0).toDouble(),
      row: data['row'] ?? 0,
      column: data['column'] ?? 0,
      renewalDate: _parseTimestamp(data['renewalDate']),
      createdAt: _parseTimestamp(data['createdAt']),
      reservation: data['reservation'] != null
          ? SeatReservation(
              reservedBy: data['reservation']['reservedBy'] ?? '',
              reservedByName: data['reservation']['reservedByName'] ?? '',
              reservedFrom: SeatReservation._parseTimestamp(
                      data['reservation']['reservedFrom']) ??
                  DateTime.now(),
              reservedUntil: SeatReservation._parseTimestamp(
                      data['reservation']['reservedUntil']) ??
                  DateTime.now(),
            )
          : null,
      shifts: parsedShifts,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'seatId': seatId,
      'seatNumber': seatNumber,
      'category': category,
      'status': status,
      'assignedStudentId': assignedStudentId,
      'assignedStudentName': assignedStudentName,
      'price': price,
      'row': row,
      'column': column,
      'renewalDate': renewalDate,
      'createdAt': createdAt,
      'reservation': reservation?.toFirestore(),
      'shifts': shifts?.map((k, v) => MapEntry(k, v.toFirestore())),
    };
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is DateTime) return value;
    return null;
  }

  /// Check whether a particular shift is available for this seat.
  bool isShiftAvailable(String shift) {
    if (status == 'maintenance' || status == 'reserved') return false;
    // If full-seat is booked
    if (assignedStudentId != null && assignedStudentId!.isNotEmpty) {
      return false;
    }
    if (shifts == null || shifts!.isEmpty) return true;
    final isFullDayRequest = shift.toLowerCase().contains('full');
    if (isFullDayRequest) return shifts!.isEmpty;
    final hasFullDayOccupied = shifts!.keys.any((k) => k.toLowerCase().contains('full'));
    if (hasFullDayOccupied) return false;
    return !shifts!.keys.any((k) =>
        k.toLowerCase().contains(shift.toLowerCase()) ||
        shift.toLowerCase().contains(k.toLowerCase()));
  }

  /// Get student assignment for a shift
  ShiftAssignment? getShiftAssignment(String shift) {
    if (shifts != null && shifts!.containsKey(shift)) {
      return shifts![shift];
    }
    if (assignedStudentId != null && assignedStudentId!.isNotEmpty) {
      return ShiftAssignment(
        studentId: assignedStudentId!,
        studentName: assignedStudentName ?? '',
        renewalDate: renewalDate,
      );
    }
    return null;
  }

  /// Summary badge text of shifts booked (e.g. "Morning, Evening")
  String get activeShiftsSummary {
    if (shifts != null && shifts!.isNotEmpty) {
      return shifts!.keys.map((k) => _formatShiftName(k)).join(', ');
    }
    if (assignedStudentId != null && assignedStudentId!.isNotEmpty) {
      return 'Full Day';
    }
    return 'Available';
  }

  static String _formatShiftName(String shift) {
    switch (shift.toLowerCase()) {
      case 'morning':
        return 'Morning';
      case 'evening':
        return 'Evening';
      case 'night':
        return 'Night';
      case 'full_day':
        return 'Full Day';
      default:
        return shift;
    }
  }

  SeatModel copyWith({
    String? seatId,
    String? seatNumber,
    String? category,
    String? status,
    Object? assignedStudentId = _sentinel,
    Object? assignedStudentName = _sentinel,
    double? price,
    int? row,
    int? column,
    Object? renewalDate = _sentinel,
    DateTime? createdAt,
    Object? reservation = _sentinel,
    Object? shifts = _sentinel,
  }) {
    return SeatModel(
      seatId: seatId ?? this.seatId,
      seatNumber: seatNumber ?? this.seatNumber,
      category: category ?? this.category,
      status: status ?? this.status,
      assignedStudentId: assignedStudentId == _sentinel ? this.assignedStudentId : assignedStudentId as String?,
      assignedStudentName: assignedStudentName == _sentinel ? this.assignedStudentName : assignedStudentName as String?,
      price: price ?? this.price,
      row: row ?? this.row,
      column: column ?? this.column,
      renewalDate: renewalDate == _sentinel ? this.renewalDate : renewalDate as DateTime?,
      createdAt: createdAt ?? this.createdAt,
      reservation: reservation == _sentinel ? this.reservation : reservation as SeatReservation?,
      shifts: shifts == _sentinel ? this.shifts : shifts as Map<String, ShiftAssignment>?,
    );
  }
}
