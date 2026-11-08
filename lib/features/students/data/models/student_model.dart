import 'package:cloud_firestore/cloud_firestore.dart';

class StudentModel {
  final String studentId;
  final String uniqueId;
  final String name;
  final String phone;
  final String? parentPhone;
  final String? address;
  final String? idProofUrl;
  final String? photoUrl;
  final String? seatId;
  final String? seatNumber;
  final DateTime? joiningDate;
  final DateTime? leaveDate;
  final String feePlan;
  final double feeAmount;
  final String feeStatus;
  final DateTime? nextDueDate;
  final bool isActive;
  final String status; // 'enrolled', 'active', 'suspended', 'graduated', 'alumni'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const StudentModel({
    required this.studentId,
    this.uniqueId = '',
    required this.name,
    required this.phone,
    this.parentPhone,
    this.address,
    this.idProofUrl,
    this.photoUrl,
    this.seatId,
    this.seatNumber,
    this.joiningDate,
    this.leaveDate,
    this.feePlan = 'Monthly',
    this.feeAmount = 0,
    this.feeStatus = 'pending',
    this.nextDueDate,
    this.isActive = true,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      studentId: json['studentId'] ?? '',
      uniqueId: json['uniqueId'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      parentPhone: json['parentPhone'],
      address: json['address'],
      idProofUrl: json['idProofUrl'],
      photoUrl: json['photoUrl'],
      seatId: json['seatId'],
      seatNumber: json['seatNumber'],
      joiningDate: _parseTimestamp(json['joiningDate']),
      leaveDate: _parseTimestamp(json['leaveDate']),
      feePlan: json['feePlan'] ?? 'Monthly',
      feeAmount: (json['feeAmount'] ?? 0).toDouble(),
      feeStatus: json['feeStatus'] ?? 'pending',
      nextDueDate: _parseTimestamp(json['nextDueDate']),
      isActive: json['isActive'] ?? true,
      status: json['status'] ?? 'active',
      createdAt: _parseTimestamp(json['createdAt']),
      updatedAt: _parseTimestamp(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'uniqueId': uniqueId,
      'name': name,
      'phone': phone,
      'parentPhone': parentPhone,
      'address': address,
      'idProofUrl': idProofUrl,
      'photoUrl': photoUrl,
      'seatId': seatId,
      'seatNumber': seatNumber,
      'joiningDate': joiningDate?.toIso8601String(),
      'leaveDate': leaveDate?.toIso8601String(),
      'feePlan': feePlan,
      'feeAmount': feeAmount,
      'feeStatus': feeStatus,
      'nextDueDate': nextDueDate?.toIso8601String(),
      'isActive': isActive,
      'status': status,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory StudentModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      return StudentModel(studentId: doc.id, name: '', phone: '');
    }
    return StudentModel(
      studentId: data['studentId'] ?? doc.id,
      uniqueId: data['uniqueId'] ?? '',
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      parentPhone: data['parentPhone'],
      address: data['address'],
      idProofUrl: data['idProofUrl'],
      photoUrl: data['photoUrl'],
      seatId: data['seatId'],
      seatNumber: data['seatNumber'],
      joiningDate: _parseTimestamp(data['joiningDate']),
      leaveDate: _parseTimestamp(data['leaveDate']),
      feePlan: data['feePlan'] ?? 'Monthly',
      feeAmount: (data['feeAmount'] ?? 0).toDouble(),
      feeStatus: data['feeStatus'] ?? 'pending',
      nextDueDate: _parseTimestamp(data['nextDueDate']),
      isActive: data['isActive'] ?? true,
      status: data['status'] ?? 'active',
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'studentId': studentId,
      'uniqueId': uniqueId,
      'name': name,
      'phone': phone,
      'parentPhone': parentPhone,
      'address': address,
      'idProofUrl': idProofUrl,
      'photoUrl': photoUrl,
      'seatId': seatId,
      'seatNumber': seatNumber,
      'joiningDate': joiningDate != null ? Timestamp.fromDate(joiningDate!) : null,
      'leaveDate': leaveDate != null ? Timestamp.fromDate(leaveDate!) : null,
      'feePlan': feePlan,
      'feeAmount': feeAmount,
      'feeStatus': feeStatus,
      'nextDueDate': nextDueDate != null ? Timestamp.fromDate(nextDueDate!) : null,
      'isActive': isActive,
      'status': status,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is DateTime) return value;
    return null;
  }

  static const _sentinel = Object();

  StudentModel copyWith({
    String? studentId,
    String? uniqueId,
    String? name,
    String? phone,
    Object? parentPhone = _sentinel,
    Object? address = _sentinel,
    Object? idProofUrl = _sentinel,
    Object? photoUrl = _sentinel,
    Object? seatId = _sentinel,
    Object? seatNumber = _sentinel,
    Object? joiningDate = _sentinel,
    Object? leaveDate = _sentinel,
    String? feePlan,
    double? feeAmount,
    String? feeStatus,
    Object? nextDueDate = _sentinel,
    bool? isActive,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudentModel(
      studentId: studentId ?? this.studentId,
      uniqueId: uniqueId ?? this.uniqueId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      parentPhone: parentPhone == _sentinel ? this.parentPhone : parentPhone as String?,
      address: address == _sentinel ? this.address : address as String?,
      idProofUrl: idProofUrl == _sentinel ? this.idProofUrl : idProofUrl as String?,
      photoUrl: photoUrl == _sentinel ? this.photoUrl : photoUrl as String?,
      seatId: seatId == _sentinel ? this.seatId : seatId as String?,
      seatNumber: seatNumber == _sentinel ? this.seatNumber : seatNumber as String?,
      joiningDate: joiningDate == _sentinel ? this.joiningDate : joiningDate as DateTime?,
      leaveDate: leaveDate == _sentinel ? this.leaveDate : leaveDate as DateTime?,
      feePlan: feePlan ?? this.feePlan,
      feeAmount: feeAmount ?? this.feeAmount,
      feeStatus: feeStatus ?? this.feeStatus,
      nextDueDate: nextDueDate == _sentinel ? this.nextDueDate : nextDueDate as DateTime?,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
