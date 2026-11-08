import 'package:cloud_firestore/cloud_firestore.dart';

class StaffModel {
  final String staffId;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String shift;
  final bool isActive;
  final DateTime? createdAt;

  const StaffModel({
    required this.staffId,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.shift = 'full_day',
    this.isActive = true,
    this.createdAt,
  });

  factory StaffModel.fromJson(Map<String, dynamic> json) {
    return StaffModel(
      staffId: json['staffId'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? '',
      shift: json['shift'] ?? 'full_day',
      isActive: json['isActive'] ?? true,
      createdAt: _parseTimestamp(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'staffId': staffId,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'shift': shift,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory StaffModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      return StaffModel(staffId: doc.id, name: '', email: '', phone: '', role: '');
    }
    return StaffModel(
      staffId: data['staffId'] ?? doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? '',
      shift: data['shift'] ?? 'full_day',
      isActive: data['isActive'] ?? true,
      createdAt: _parseTimestamp(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'staffId': staffId,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'shift': shift,
      'isActive': isActive,
      'createdAt': createdAt,
    };
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is DateTime) return value;
    return null;
  }

  String get roleDisplayName {
    switch (role) {
      case 'reception_manager': return 'Reception Manager';
      case 'attendance_manager': return 'Attendance Manager';
      case 'fee_collection': return 'Fee Collection';
      default: return role;
    }
  }

  String get shiftDisplayName {
    switch (shift) {
      case 'morning': return 'Morning (6AM-2PM)';
      case 'afternoon': return 'Afternoon (2PM-10PM)';
      case 'night': return 'Night (10PM-6AM)';
      case 'full_day': return 'Full Day';
      default: return shift;
    }
  }

  String get shiftShortName {
    switch (shift) {
      case 'morning': return 'MORNING';
      case 'afternoon': return 'AFTERNOON';
      case 'night': return 'NIGHT';
      case 'full_day': return 'FULL DAY';
      default: return shift.toUpperCase();
    }
  }

  StaffModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? role,
    String? shift,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return StaffModel(
      staffId: staffId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      shift: shift ?? this.shift,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
