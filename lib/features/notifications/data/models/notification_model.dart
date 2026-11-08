import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String notificationId;
  final String title;
  final String body;
  final String category;
  final bool isRead;
  final Map<String, dynamic>? data;
  final DateTime? createdAt;

  const NotificationModel({
    required this.notificationId,
    required this.title,
    required this.body,
    this.category = 'system',
    this.isRead = false,
    this.data,
    this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      notificationId: json['notificationId'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      category: json['category'] ?? 'system',
      isRead: json['isRead'] ?? false,
      data: json['data'] is Map ? Map<String, dynamic>.from(json['data'] as Map) : null,
      createdAt: _parseTimestamp(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notificationId': notificationId,
      'title': title,
      'body': body,
      'category': category,
      'isRead': isRead,
      'data': data,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is DateTime) return value;
    return null;
  }

  factory NotificationModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      return NotificationModel(notificationId: doc.id, title: '', body: '');
    }
    return NotificationModel(
      notificationId: data['notificationId'] ?? doc.id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      category: data['category'] ?? 'system',
      isRead: data['isRead'] ?? false,
      data: data['data'] is Map ? Map<String, dynamic>.from(data['data'] as Map) : null,
      createdAt: _parseTimestamp(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'notificationId': notificationId,
      'title': title,
      'body': body,
      'category': category,
      'isRead': isRead,
      'data': data,
      'createdAt': createdAt,
    };
  }

  NotificationModel copyWith({
    String? title,
    String? body,
    String? category,
    bool? isRead,
    Map<String, dynamic>? data,
  }) {
    return NotificationModel(
      notificationId: notificationId,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
      createdAt: createdAt,
    );
  }
}
