import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityModel {
  final String id;
  final String type; // student_added, fee_collected, attendance_marked, seat_changed, staff_added, book_issued
  final String description;
  final DateTime? timestamp;
  final String? relatedId;

  const ActivityModel({
    required this.id,
    required this.type,
    required this.description,
    this.timestamp,
    this.relatedId,
  });

  factory ActivityModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ActivityModel(
      id: doc.id,
      type: data['type'] ?? '',
      description: data['description'] ?? '',
      timestamp: _parseTimestamp(data['timestamp']),
      relatedId: data['relatedId'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'description': description,
      'timestamp': timestamp ?? FieldValue.serverTimestamp(),
      'relatedId': relatedId,
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
