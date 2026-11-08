import 'package:cloud_firestore/cloud_firestore.dart';

class TicketMessage {
  final String messageId;
  final String senderId;
  final String senderName;
  final String senderEmail;
  final String text;
  final DateTime? timestamp;
  final bool isAdmin;

  const TicketMessage({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.senderEmail,
    required this.text,
    this.timestamp,
    this.isAdmin = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderEmail': senderEmail,
      'text': text,
      'timestamp': timestamp ?? FieldValue.serverTimestamp(),
      'isAdmin': isAdmin,
    };
  }

  factory TicketMessage.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TicketMessage(
      messageId: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderEmail: data['senderEmail'] ?? '',
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
      isAdmin: data['isAdmin'] ?? false,
    );
  }
}
