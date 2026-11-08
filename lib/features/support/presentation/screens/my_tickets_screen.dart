import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../app/router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/support_ticket.dart';
import '../providers/support_provider.dart';

class MyTicketsScreen extends ConsumerWidget {
  const MyTicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return Scaffold(
        body: Container(
          color: context.scaffoldBg,
          child: const Center(child: Text('Not logged in')),
        ),
      );
    }

    final ticketsAsync = ref.watch(userTicketsProvider(user.uid));

    return Scaffold(
      body: Container(
        color: context.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 8),
                    Text('My Tickets', style: AppTypography.headlineSmall),
                  ],
                ),
              ),
              Expanded(
                child: ticketsAsync.when(
                  data: (tickets) {
                    if (tickets.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_rounded,
                              size: 64,
                              color: context.textTertiaryColor.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No tickets yet',
                              style: AppTypography.titleMedium.copyWith(
                                color: context.textTertiaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap + to submit a support ticket',
                              style: AppTypography.bodySmall.copyWith(
                                color: context.textTertiaryColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: tickets.length,
                      itemBuilder: (context, index) {
                        return _TicketCard(ticket: tickets[index]);
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                  error: (e, _) => Center(
                    child: Text(
                      'Error loading tickets: $e',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => context.push(AppRoutes.createTicket),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final SupportTicket ticket;

  const _TicketCard({required this.ticket});

  Color _statusColor(BuildContext context) {
    switch (ticket.status) {
      case 'open':
        return AppColors.success;
      case 'replied':
        return AppColors.info;
      case 'closed':
        return context.textTertiaryColor;
      default:
        return context.textTertiaryColor;
    }
  }

  String _statusLabel() {
    switch (ticket.status) {
      case 'open':
        return 'Open';
      case 'replied':
        return 'Replied';
      case 'closed':
        return 'Closed';
      default:
        return ticket.status;
    }
  }

  String _timeAgo() {
    if (ticket.lastMessageAt == null) return '';
    final diff = DateTime.now().difference(ticket.lastMessageAt!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(ticket.lastMessageAt!);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/support/ticket/${ticket.ticketId}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Subject and preview
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ticket.subject,
                              style: AppTypography.labelLarge,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor(context).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _statusLabel(),
                              style: AppTypography.badge.copyWith(
                                color: _statusColor(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ticket.lastMessage.isNotEmpty
                            ? ticket.lastMessage
                            : 'No messages yet',
                        style: AppTypography.bodySmall.copyWith(
                          color: context.textSecondaryColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _timeAgo(),
                        style: AppTypography.labelSmall.copyWith(
                          color: context.textTertiaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.textTertiaryColor,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
