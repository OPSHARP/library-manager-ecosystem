import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../app/router.dart';
import '../../data/models/notification_model.dart';
import '../../presentation/providers/notification_provider.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../students/presentation/providers/student_provider.dart';

/// Notification category filter state
final notificationFilterProvider = StateProvider<String>((ref) => 'All');

/// Notifications Screen
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  static const _categories = ['All', 'Fee', 'Attendance', 'System', 'Promotional'];

  bool _selectionMode = false;
  final Set<String> _selected = {};

  void _toggleSelection(NotificationModel n) {
    setState(() {
      if (!_selected.add(n.notificationId)) {
        _selected.remove(n.notificationId);
      }
      if (_selected.isEmpty) _selectionMode = false;
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selected.clear();
    });
  }

  /// Owner approves a student's leave request (from a "Leave Request"
  /// notification). Server-side `approveLeaveRequest` marks the student left,
  /// releases the seat, clears the linkage so the student auto-leaves, and
  /// deletes the request.
  Future<void> _handleLeaveRequest(NotificationModel n) async {
    final uniqueId = n.data?['studentUniqueId']?.toString() ?? '';
    final body = n.body.isNotEmpty ? '${n.body}\n\n' : '';
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.surfaceColor,
        title: const Text('Leave Request'),
        content: Text(
            '${body}Approve this student\'s leave request? They will leave your library.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve Leave'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    try {
      await FirebaseFunctions.instance
          .httpsCallable('approveLeaveRequest')
          .call({'studentId': uniqueId});
      // Auto-delete the "Leave Request" notification once it is approved so
      // the bell does not keep stale unread entries around.
      try {
        await ref
            .read(notificationRepositoryProvider)
            .deleteNotification(n.notificationId);
      } catch (_) {
        // Best-effort — the approval already succeeded.
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Leave request approved. Student removed.')),
      );
      ref.invalidate(notificationsProvider);
      ref.invalidate(studentsStreamProvider);
    } catch (e) {
      if (!mounted) return;
      final msg = e is FirebaseFunctionsException
          ? (e.message ?? 'Please try again.')
          : 'Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not approve leave request. $msg')),
      );
    }
  }

  Future<bool?> _confirmDelete(int count) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(count == 1 ? 'Delete Notification' : 'Delete $count Notifications'),
        content: Text(
          count == 1
              ? 'This notification will be permanently deleted. Continue?'
              : 'These $count notifications will be permanently deleted. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSelected() async {
    final count = _selected.length;
    if (count == 0) return;
    final confirmed = await _confirmDelete(count);
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(notificationRepositoryProvider).deleteNotifications(_selected.toList());
      if (!mounted) return;
      setState(() {
        _selected.clear();
        _selectionMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count notification${count == 1 ? '' : 's'} deleted')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete notifications')),
        );
      }
    }
  }

  Future<void> _deleteOne(NotificationModel n) async {
    final confirmed = await _confirmDelete(1);
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(notificationRepositoryProvider).deleteNotification(n.notificationId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification deleted')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete notification')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final selectedCategory = ref.watch(notificationFilterProvider);

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
                      icon: Icon(
                        _selectionMode ? Icons.close_rounded : Icons.arrow_back_rounded,
                      ),
                      onPressed: _selectionMode ? _exitSelectionMode : () => context.pop(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectionMode ? 'Select notifications' : AppLocalizations.of(context)!.notifications,
                        style: AppTypography.headlineSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_selectionMode)
                      IconButton(
                        icon: const Icon(Icons.delete_forever_rounded),
                        color: _selected.isEmpty ? AppColors.textTertiary : AppColors.error,
                        tooltip: 'Delete selected',
                        onPressed: _selected.isEmpty ? null : _deleteSelected,
                      )
                    else ...[
                      TextButton(
                        onPressed: () => setState(() => _selectionMode = true),
                        child: Text('Select', style: AppTypography.labelMedium.copyWith(color: AppColors.primary)),
                      ),
                      TextButton(
                        onPressed: () {
                          ref.read(notificationRepositoryProvider).markAllAsRead();
                        },
                        child: Text('Mark all read', style: AppTypography.labelMedium.copyWith(color: AppColors.primary)),
                      ),
                    ],
                  ],
                ),
              ),
              // Category filter chips
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = selectedCategory == cat;
                    Color chipColor;
                    switch (cat) {
                      case 'Fee':
                        chipColor = AppColors.warning;
                        break;
                      case 'Attendance':
                        chipColor = AppColors.secondary;
                        break;
                      case 'System':
                        chipColor = AppColors.primary;
                        break;
                      case 'Promotional':
                        chipColor = AppColors.neonPurple;
                        break;
                      default:
                        chipColor = AppColors.primary;
                    }
                    return GestureDetector(
                      onTap: () => ref.read(notificationFilterProvider.notifier).state = cat,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: isSelected ? chipColor.withValues(alpha: 0.15) : context.cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? chipColor : context.borderColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            cat,
                            style: AppTypography.labelMedium.copyWith(
                              color: isSelected ? chipColor : context.textSecondaryColor,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: notificationsAsync.when(
                  data: (notifications) {
                    final filtered = selectedCategory == 'All'
                        ? notifications
                        : notifications.where((n) => n.category == selectedCategory.toLowerCase()).toList();
                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_none_rounded, size: 48, color: context.textTertiaryColor),
                            const SizedBox(height: 12),
                            Text('No notifications yet', style: AppTypography.bodyMedium.copyWith(color: context.textTertiaryColor)),
                          ],
                        ),
                      );
                    }
                    return RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () async {
                        ref.invalidate(notificationsProvider);
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final n = filtered[index];
                          return _NotificationTile(
                            notification: n,
                            selectionMode: _selectionMode,
                            selected: _selected.contains(n.notificationId),
                            onTap: () {
                              if (_selectionMode) {
                                _toggleSelection(n);
                                return;
                              }
                              // Mark read (best-effort, never throws).
                              final repo = ref.read(notificationRepositoryProvider);
                              if (!n.isRead) {
                                unawaited(
                                  repo.markAsRead(n.notificationId).catchError((Object _) {}),
                                );
                              }
                              // Join-request notifications open the accept/reject flow.
                              final isJoinRequest =
                                  n.title == 'New Join Request' ||
                                      (n.category == 'system' &&
                                          n.data?.containsKey('studentUid') == true);
                              final isLeaveRequest =
                                  n.category == 'leave_request' ||
                                      n.title == 'Leave Request';
                              if (isJoinRequest) {
                                context.push(AppRoutes.joinRequests);
                              } else if (isLeaveRequest) {
                                _handleLeaveRequest(n);
                              }
                            },
                            onDelete: _selectionMode ? null : () => _deleteOne(n),
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const SkeletonList(count: 5),
                  error: (e, _) => Center(child: Text('Error: $e', style: AppTypography.bodyMedium.copyWith(color: AppColors.error))),
                ),
              ),
              if (_selectionMode)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _selected.isEmpty ? null : _deleteSelected,
                        icon: const Icon(Icons.delete_outline_rounded, size: 20),
                        label: Text(
                          _selected.isEmpty
                              ? 'Select notifications'
                              : 'Delete Selected (${_selected.length})',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton(
              onPressed: () => context.push(AppRoutes.sendNotification),
              child: const Icon(Icons.send_rounded),
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool selectionMode;
  final bool selected;

  const _NotificationTile({
    required this.notification,
    this.onTap,
    this.onDelete,
    this.selectionMode = false,
    this.selected = false,
  });

  IconData _getIcon() {
    switch (notification.category) {
      case 'fee': return Icons.receipt_long_rounded;
      case 'attendance': return Icons.fact_check_rounded;
      case 'promotional': return Icons.campaign_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _getColor() {
    switch (notification.category) {
      case 'fee': return AppColors.warning;
      case 'attendance': return AppColors.secondary;
      case 'promotional': return AppColors.neonPurple;
      default: return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    final time = notification.createdAt != null ? Formatters.relativeDate(notification.createdAt!) : '';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : notification.isRead
                  ? context.cardBg
                  : context.cardBg.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(14),
          border: selected
              ? Border.all(color: AppColors.primary)
              : !notification.isRead
                  ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
                  : Border.all(color: context.borderColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            if (selectionMode) ...[
              Icon(
                selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.primary : context.textTertiaryColor,
              ),
              const SizedBox(width: 10),
            ],
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(_getIcon(), size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(notification.title, style: AppTypography.labelLarge, overflow: TextOverflow.ellipsis, maxLines: 1),
              const SizedBox(height: 2),
              Text(notification.body, style: AppTypography.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
            ])),
            const SizedBox(width: 8),
            Column(children: [
              Text(time, style: AppTypography.labelSmall),
              if (!notification.isRead && !selectionMode) ...[
                const SizedBox(height: 6),
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
              ],
            ]),
            if (!selectionMode && onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: context.textTertiaryColor,
                tooltip: 'Delete notification',
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}
