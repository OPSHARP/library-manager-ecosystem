import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/extensions.dart';
import '../auth/presentation/providers/auth_provider.dart';

final studentNotificationsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final auth = ref.watch(authProvider);
  final ownerUid = auth.ownerUid;
  final studentId = auth.studentUniqueId;
  if (ownerUid == null || studentId == null) {
    return Stream.value([]);
  }
  final fs = FirestoreService(ownerUid);
  return fs.streamStudentNotifications(studentId).map((snapshot) {
    return snapshot.docs.map((doc) => doc.data()).toList();
  });
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(studentNotificationsProvider);
  return notifications.valueOrNull?.where((n) => n['isRead'] != true).length ?? 0;
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(studentNotificationsProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.floatingBar,
        middle: const Text('Notifications'),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: notifications.when(
                loading: () => const Center(
                  child: CupertinoActivityIndicator(color: AppColors.systemBlue),
                ),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        CupertinoIcons.cloud_bolt,
                        size: 48,
                        color: AppColors.tertiaryLabel,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$e',
                        style: const TextStyle(
                          color: AppColors.secondaryLabel,
                        ),
                      ),
                    ],
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return const EmptyState(
                      icon: CupertinoIcons.bell,
                      title: 'No Notifications',
                      subtitle: 'You\'ll see library announcements here',
                    );
                  }
                  final sorted = List<Map<String, dynamic>>.from(items);
                  sorted.sort((a, b) {
                    final da = a['createdAt'];
                    final db = b['createdAt'];
                    if (da is DateTime && db is DateTime) return db.compareTo(da);
                    return 0;
                  });
                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: sorted.length,
                    itemBuilder: (_, i) =>
                        _buildNotificationTile(context, ref, sorted[i]),
                  );
                },
              ),
            ),
                      ],
        ),
      ),
    );
  }

  Future<void> _markRead(
      BuildContext context, WidgetRef ref, Map<String, dynamic> notif) async {
    if (notif['isRead'] == true) return;
    final auth = ref.read(authProvider);
    final ownerUid = auth.ownerUid;
    final studentId = auth.studentUniqueId;
    final notificationId =
        notif['id'] as String? ?? notif['notificationId'] as String?;
    if (ownerUid == null || studentId == null || notificationId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerUid)
          .collection('students')
          .doc(studentId)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (_) {
      // Non-critical: failing to mark read should not break the UI.
    }
  }

  Widget _buildNotificationTile(
      BuildContext context, WidgetRef ref, Map<String, dynamic> notif) {
    final title = notif['title'] as String? ?? '';
    final body = notif['body'] as String? ?? '';
    final isRead = notif['isRead'] == true;
    final category = notif['category'] as String? ?? 'system';
    final createdAt = notif['createdAt'];
    IconData icon;
    Color iconColor;
    switch (category) {
      case 'fee':
        icon = CupertinoIcons.money_dollar_circle;
        iconColor = AppColors.warning;
        break;
      case 'attendance':
        icon = CupertinoIcons.calendar;
        iconColor = AppColors.systemBlue;
        break;
      case 'promotional':
        icon = CupertinoIcons.speaker_3;
        iconColor = AppColors.systemPink;
        break;
      default:
        icon = CupertinoIcons.bell;
        iconColor = AppColors.systemBlue;
    }

    String timeAgo = '';
    if (createdAt is DateTime) {
      final diff = DateTime.now().difference(createdAt);
      if (diff.inMinutes < 1) {
        timeAgo = 'Just now';
      } else if (diff.inMinutes < 60) {
        timeAgo = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        timeAgo = '${diff.inHours}h ago';
      } else if (diff.inDays < 7) {
        timeAgo = '${diff.inDays}d ago';
      } else {
        timeAgo = createdAt.formatDate();
      }
    }

    return GestureDetector(
      onTap: () => _markRead(context, ref, notif),
      behavior: HitTestBehavior.opaque,
      child: GlassContainer(
        margin: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: AppColors.label,
                            fontSize: 15,
                            fontWeight:
                                isRead ? FontWeight.w500 : FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.systemBlue,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: const TextStyle(
                      color: AppColors.secondaryLabel,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  if (timeAgo.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      timeAgo,
                      style: const TextStyle(
                        color: AppColors.tertiaryLabel,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
