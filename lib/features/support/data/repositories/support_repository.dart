import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/support_ticket.dart';
import '../models/ticket_message.dart';

class SupportRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ticketsCol =>
      _firestore.collection('support_tickets');

  /// Create a new support ticket with the first message.
  Future<String> createTicket({
    required String userId,
    required String userName,
    required String userEmail,
    required String subject,
    required String firstMessage,
  }) async {
    final now = DateTime.now();
    final ticketRef = _ticketsCol.doc();
    final ticketData = SupportTicket(
      ticketId: ticketRef.id,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      subject: subject,
      status: 'open',
      createdAt: now,
      lastMessageAt: now,
      lastMessage: firstMessage,
    ).toMap();

    await ticketRef.set(ticketData);

    final msgRef = ticketRef.collection('messages').doc();
    final msgData = {
      'senderId': userId,
      'senderName': userName,
      'senderEmail': userEmail,
      'text': firstMessage,
      'timestamp': FieldValue.serverTimestamp(),
      'isAdmin': false,
    };
    await msgRef.set(msgData);

    return ticketRef.id;
  }

  /// Stream of tickets for a specific user, ordered by lastMessageAt descending.
  Stream<List<SupportTicket>> getUserTickets(String userId) {
    return _ticketsCol
        .where('userId', isEqualTo: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SupportTicket.fromDoc(doc)).toList());
  }

  /// Stream of ALL tickets (admin), ordered by lastMessageAt descending.
  Stream<List<SupportTicket>> getAllTickets() {
    return _ticketsCol
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SupportTicket.fromDoc(doc)).toList());
  }

  /// Stream of messages for a specific ticket, ordered by timestamp.
  Stream<List<TicketMessage>> getTicketMessages(String ticketId) {
    return _ticketsCol
        .doc(ticketId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => TicketMessage.fromDoc(doc)).toList());
  }

  /// Send a message in a ticket. Updates the ticket's lastMessage, lastMessageAt,
  /// and status (admin reply -> 'replied', user reply on closed -> 'open').
  Future<void> sendMessage({
    required String ticketId,
    required String senderId,
    required String senderName,
    required String senderEmail,
    required String text,
    required bool isAdmin,
  }) async {
    final ticketRef = _ticketsCol.doc(ticketId);
    final msgRef = ticketRef.collection('messages').doc();

    final msgData = {
      'senderId': senderId,
      'senderName': senderName,
      'senderEmail': senderEmail,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'isAdmin': isAdmin,
    };
    await msgRef.set(msgData);

    // Build the update map
    final updateMap = <String, dynamic>{
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
    };

    // If admin replies, set status to 'replied'
    if (isAdmin) {
      updateMap['status'] = 'replied';
    }

    await ticketRef.update(updateMap);
  }

  /// Close a ticket.
  Future<void> closeTicket(String ticketId) async {
    await _ticketsCol.doc(ticketId).update({'status': 'closed'});
  }

  /// Reopen a ticket.
  Future<void> reopenTicket(String ticketId) async {
    await _ticketsCol.doc(ticketId).update({'status': 'open'});
  }
}
