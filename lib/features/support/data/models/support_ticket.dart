import 'package:cloud_firestore/cloud_firestore.dart';

class SupportTicket {
  final String ticketId;
  final String userId;
  final String userName;
  final String userEmail;
  final String subject;
  final String status; // 'open', 'replied', 'closed'
  final DateTime? createdAt;
  final DateTime? lastMessageAt;
  final String lastMessage;

  const SupportTicket({
    required this.ticketId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.subject,
    this.status = 'open',
    this.createdAt,
    this.lastMessageAt,
    this.lastMessage = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'subject': subject,
      'status': status,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'lastMessageAt': lastMessageAt != null
          ? Timestamp.fromDate(lastMessageAt!)
          : FieldValue.serverTimestamp(),
      'lastMessage': lastMessage,
    };
  }

  factory SupportTicket.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SupportTicket(
      ticketId: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'] ?? '',
      subject: data['subject'] ?? '',
      status: data['status'] ?? 'open',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      lastMessage: data['lastMessage'] ?? '',
    );
  }

  SupportTicket copyWith({
    String? status,
    DateTime? lastMessageAt,
    String? lastMessage,
  }) {
    return SupportTicket(
      ticketId: ticketId,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      subject: subject,
      status: status ?? this.status,
      createdAt: createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessage: lastMessage ?? this.lastMessage,
    );
  }
}
