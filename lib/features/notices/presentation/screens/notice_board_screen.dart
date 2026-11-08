import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../data/models/notice_model.dart';
import '../providers/notice_provider.dart';

class NoticeBoardScreen extends ConsumerWidget {
  const NoticeBoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noticesAsync = ref.watch(noticesStreamProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 8),
                  Text('Notice Board', style: AppTypography.headlineSmall),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 28),
                    color: AppColors.primary,
                    onPressed: () => _showAddNoticeDialog(context, ref),
                  ),
                ],
              ),
            ),

            Expanded(
              child: noticesAsync.when(
                data: (notices) {
                  if (notices.isEmpty) {
                    return const EmptyState(
                      icon: Icons.campaign_outlined,
                      title: 'No Notices Posted',
                      subtitle: 'Post announcements for your library students by tapping + above',
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: notices.length,
                    itemBuilder: (context, idx) {
                      final notice = notices[idx];
                      return _NoticeCard(
                        notice: notice,
                        onDelete: () => _confirmDelete(context, ref, notice),
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddNoticeDialog(context, ref),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.campaign_rounded, color: Colors.white),
        label: const Text('Post Notice', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showAddNoticeDialog(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    String priority = 'normal';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('New Library Notice', style: AppTypography.titleMedium),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                style: AppTypography.bodyMedium,
                decoration: InputDecoration(
                  labelText: 'Notice Title',
                  hintText: 'e.g. Library Closed this Sunday, Extended Hours',
                  filled: true,
                  fillColor: context.surfaceColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageCtrl,
                maxLines: 4,
                style: AppTypography.bodyMedium,
                decoration: InputDecoration(
                  labelText: 'Notice Message',
                  hintText: 'Type your message for all library students...',
                  filled: true,
                  fillColor: context.surfaceColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: priority,
                decoration: InputDecoration(
                  labelText: 'Priority / Tag',
                  filled: true,
                  fillColor: context.surfaceColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                dropdownColor: context.cardBg,
                items: const [
                  DropdownMenuItem(value: 'normal', child: Text('Normal Notice')),
                  DropdownMenuItem(value: 'important', child: Text('Important Update')),
                  DropdownMenuItem(value: 'urgent', child: Text('Urgent Alert')),
                ],
                onChanged: (v) {
                  if (v != null) setSheetState(() => priority = v);
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final title = titleCtrl.text.trim();
                    final message = messageCtrl.text.trim();
                    if (title.isEmpty || message.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill in both title and message')),
                      );
                      return;
                    }

                    Navigator.pop(ctx);
                    await ref.read(noticeRepositoryProvider).addNotice(
                          title: title,
                          message: message,
                          priority: priority,
                        );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Notice posted successfully')),
                      );
                    }
                  },
                  child: const Text('Publish Notice', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, NoticeModel notice) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        title: const Text('Delete Notice?'),
        content: Text('Remove "${notice.title}" from the notice board?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(noticeRepositoryProvider).deleteNotice(notice.noticeId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final NoticeModel notice;
  final VoidCallback onDelete;

  const _NoticeCard({required this.notice, required this.onDelete});

  Color _priorityColor() {
    switch (notice.priority.toLowerCase()) {
      case 'urgent':
        return AppColors.error;
      case 'important':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor();
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(notice.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  notice.priority.toUpperCase(),
                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              Text(
                dateStr,
                style: AppTypography.bodySmall.copyWith(color: context.textTertiaryColor, fontSize: 11),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(notice.title, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            notice.message,
            style: AppTypography.bodyMedium.copyWith(color: context.textSecondaryColor, height: 1.4),
          ),
        ],
      ),
    );
  }
}

