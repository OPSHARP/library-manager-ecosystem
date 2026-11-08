import 'package:cloud_firestore/cloud_firestore.dart';

class NoticeModel {
  final String noticeId;
  final String title;
  final String message;
  final String priority; // 'normal', 'important', 'urgent'
  final bool isActive;
  final DateTime createdAt;

  const NoticeModel({
    required this.noticeId,
    required this.title,
    required this.message,
    this.priority = 'normal',
    this.isActive = true,
    required this.createdAt,
  });

  factory NoticeModel.fromJson(Map<String, dynamic> json) {
    return NoticeModel(
      noticeId: json['noticeId'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      priority: json['priority'] ?? 'normal',
      isActive: json['isActive'] ?? true,
      createdAt: _parseTimestamp(json['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'noticeId': noticeId,
      'title': title,
      'message': message,
      'priority': priority,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory NoticeModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return NoticeModel(
      noticeId: data['noticeId'] ?? doc.id,
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      priority: data['priority'] ?? 'normal',
      isActive: data['isActive'] ?? true,
      createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'noticeId': noticeId,
      'title': title,
      'message': message,
      'priority': priority,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is DateTime) return value;
    return null;
  }
}

