import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/support_ticket.dart';
import '../../data/models/ticket_message.dart';
import '../../data/repositories/support_repository.dart';

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository();
});

/// Stream of the current user's tickets.
final userTicketsProvider =
    StreamProvider.family<List<SupportTicket>, String>((ref, userId) {
  final repo = ref.watch(supportRepositoryProvider);
  return repo.getUserTickets(userId);
});

/// Stream of ALL tickets (admin view).
final allTicketsProvider = StreamProvider<List<SupportTicket>>((ref) {
  final repo = ref.watch(supportRepositoryProvider);
  return repo.getAllTickets();
});

/// Stream of messages for a specific ticket.
final ticketMessagesProvider =
    StreamProvider.family<List<TicketMessage>, String>((ref, ticketId) {
  final repo = ref.watch(supportRepositoryProvider);
  return repo.getTicketMessages(ticketId);
});
