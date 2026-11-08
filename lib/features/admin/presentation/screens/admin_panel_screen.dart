import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../support/data/models/support_ticket.dart';
import '../../../support/presentation/providers/support_provider.dart';

class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = ['All', 'Open', 'Replied', 'Closed'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminSyncProvider);

    if (!isAdmin) {
      return Scaffold(
        body: Container(
          color: context.scaffoldBg,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () => context.pop(),
                      ),
                      const SizedBox(width: 8),
                      Text('Admin Panel',
                          style: AppTypography.headlineSmall),
                    ],
                  ),
                ),
                const Expanded(
                  child: Center(
                    child: Text('Access denied. Admin only.'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final ticketsAsync = ref.watch(allTicketsProvider);

    return Scaffold(
      body: Container(
        color: context.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              // App bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 8),
                    Text('Admin Panel',
                        style: AppTypography.headlineSmall),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.neonPurple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shield_rounded,
                              size: 14, color: AppColors.neonPurple),
                          const SizedBox(width: 4),
                          Text('Admin',
                              style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.neonPurple,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),

              // Tab bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: context.textSecondaryColor,
                  labelStyle: AppTypography.labelLarge.copyWith(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  dividerColor: Colors.transparent,
                  tabs: _tabs.map((t) => Tab(text: t)).toList(),
                ),
              ),
              const SizedBox(height: 12),

              // Ticket list
              Expanded(
                child: ticketsAsync.when(
                  data: (tickets) {
                    return TabBarView(
                      controller: _tabController,
                      children: _tabs.map((tab) {
                        final filtered = tab == 'All'
                            ? tickets
                            : tickets
                                .where((t) =>
                                    t.status == tab.toLowerCase())
                                .toList();

                        if (filtered.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox_rounded,
                                    size: 48,
                                    color: context.textTertiaryColor
                                        .withValues(alpha: 0.4)),
                                const SizedBox(height: 12),
                                Text('No tickets',
                                    style: AppTypography.bodyMedium.copyWith(
                                        color: context.textTertiaryColor)),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            return _AdminTicketCard(
                                ticket: filtered[index]);
                          },
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary),
                  ),
                  error: (e, _) => Center(
                    child: Text('Error: $e',
                        style: AppTypography.bodyMedium
                            .copyWith(color: AppColors.error)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminTicketCard extends ConsumerWidget {
  final SupportTicket ticket;

  const _AdminTicketCard({required this.ticket});

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

  Future<void> _closeTicket(WidgetRef ref) async {
    final repo = ref.read(supportRepositoryProvider);
    await repo.closeTicket(ticket.ticketId);
  }

  Future<void> _reopenTicket(WidgetRef ref) async {
    final repo = ref.read(supportRepositoryProvider);
    await repo.reopenTicket(ticket.ticketId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row: user info + status badge
                Row(
                  children: [
                    // User avatar
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.neonPurple, AppColors.neonBlue],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          ticket.userName.isNotEmpty
                              ? ticket.userName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Name + email
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ticket.userName,
                              style: AppTypography.labelLarge,
                              overflow: TextOverflow.ellipsis),
                          Text(ticket.userEmail,
                              style: AppTypography.bodySmall.copyWith(
                                   color: context.textTertiaryColor),
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _statusColor(context).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_statusLabel(),
                          style: AppTypography.badge
                              .copyWith(color: _statusColor(context))),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Subject
                Text(ticket.subject,
                    style: AppTypography.titleSmall,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),

                // Last message preview
                Text(
                  ticket.lastMessage.isNotEmpty
                      ? ticket.lastMessage
                      : 'No messages yet',
                  style: AppTypography.bodySmall.copyWith(
                      color: context.textSecondaryColor),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),

                // Bottom row: time + actions
                Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 14, color: context.textTertiaryColor),
                    const SizedBox(width: 4),
                    Text(_timeAgo(),
                        style: AppTypography.labelSmall
                            .copyWith(color: context.textTertiaryColor)),
                    const Spacer(),
                    // Close / Reopen buttons
                    if (ticket.status != 'closed')
                      _AdminActionButton(
                        label: 'Close',
                        icon: Icons.lock_outline_rounded,
                        color: AppColors.error,
                        onTap: () => _closeTicket(ref),
                      ),
                    if (ticket.status == 'closed')
                      _AdminActionButton(
                        label: 'Reopen',
                        icon: Icons.lock_open_rounded,
                        color: AppColors.success,
                        onTap: () => _reopenTicket(ref),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AdminActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: AppTypography.labelSmall
                    .copyWith(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
