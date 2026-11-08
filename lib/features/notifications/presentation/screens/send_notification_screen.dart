import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../../../core/utils/extensions.dart';
import '../providers/notification_provider.dart';
import '../../../students/presentation/providers/student_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';

/// Send Notification Screen
class SendNotificationScreen extends ConsumerStatefulWidget {
  /// Optional pre-selected student IDs (e.g. opened from a student's profile).
  final List<String>? initialStudentIds;

  const SendNotificationScreen({super.key, this.initialStudentIds});

  @override
  ConsumerState<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends ConsumerState<SendNotificationScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  late String _recipientType;
  String _category = 'system';
  bool _isLoading = false;
  late final Set<String> _selectedStudentIds;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialStudentIds ?? const [];
    _recipientType = initial.isNotEmpty ? 'specific' : 'all';
    _selectedStudentIds = Set<String>.from(initial);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendNotification() async {
    if (_titleController.text.trim().isEmpty || _messageController.text.trim().isEmpty) {
      context.showError('Please fill in title and message');
      return;
    }

    final libraryId = ref.read(libraryIdProvider);
    if (libraryId == null) {
      context.showError('No library configured');
      return;
    }

    if (_recipientType == 'specific' && _selectedStudentIds.isEmpty) {
      context.showError('Please select at least one student');
      return;
    }

    setState(() => _isLoading = true);
    final repo = ref.read(notificationRepositoryProvider);
    try {
      await repo.sendNotificationToStudent(
        title: _titleController.text.trim(),
        body: _messageController.text.trim(),
        category: _category,
        targetStudentIds: _recipientType == 'specific'
            ? _selectedStudentIds.toList()
            : null,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        context.showError('Failed to send: $e');
      }
      return;
    }

    if (mounted) {
      setState(() => _isLoading = false);
      context.showSuccess('Notification sent successfully');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
                    const SizedBox(width: 8),
                    Text('Send Notification', style: AppTypography.headlineSmall),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

                      // Recipient selection
                      Text('Send To', style: AppTypography.titleMedium),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _RecipientChip(
                            icon: Icons.people_rounded,
                            label: 'All Students',
                            isSelected: _recipientType == 'all',
                            onTap: () => setState(() {
                              _recipientType = 'all';
                              _selectedStudentIds.clear();
                            }),
                          ),
                          const SizedBox(width: 10),
                          _RecipientChip(
                            icon: Icons.person_search_rounded,
                            label: 'Specific',
                            isSelected: _recipientType == 'specific',
                            onTap: () => setState(() => _recipientType = 'specific'),
                          ),
                          const SizedBox(width: 10),
                          _RecipientChip(
                            icon: Icons.group_rounded,
                            label: 'Group',
                            isSelected: _recipientType == 'group',
                            onTap: () => setState(() {
                              _recipientType = 'group';
                              _selectedStudentIds.clear();
                            }),
                          ),
                        ],
                      ),
                      if (_recipientType == 'specific') ...[
                        const SizedBox(height: 16),
                        _StudentMultiSelect(
                          selectedIds: _selectedStudentIds,
                          onChanged: (ids) => setState(() {
                            _selectedStudentIds.clear();
                            _selectedStudentIds.addAll(ids);
                          }),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Category
                      Text('Category', style: AppTypography.titleMedium),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10, runSpacing: 10,
                        children: [
                          _categoryChip('Fee', 'fee', AppColors.warning),
                          _categoryChip('Attendance', 'attendance', AppColors.secondary),
                          _categoryChip('System', 'system', AppColors.primary),
                          _categoryChip('Promotional', 'promotional', AppColors.neonPurple),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Message
                      GlassContainer(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Title', style: AppTypography.labelLarge),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _titleController,
                              decoration: const InputDecoration(
                                hintText: 'Notification title',
                                prefixIcon: Icon(Icons.title_rounded),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text('Message', style: AppTypography.labelLarge),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _messageController,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                hintText: 'Write your message...',
                                prefixIcon: Padding(
                                  padding: EdgeInsets.only(bottom: 64),
                                  child: Icon(Icons.message_rounded),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      NeonButton(
                        text: 'Send Notification',
                        onPressed: _sendNotification,
                        isLoading: _isLoading,
                        width: double.infinity,
                        icon: Icons.send_rounded,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryChip(String label, String value, Color color) {
    final isSelected = _category == value;
    return GestureDetector(
      onTap: () => setState(() => _category = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : context.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : context.borderColor.withValues(alpha: 0.3),
          ),
        ),
        child: Text(label, style: AppTypography.labelMedium.copyWith(
          color: isSelected ? color : context.textSecondaryColor,
        )),
      ),
    );
  }
}

class _RecipientChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _RecipientChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : context.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : context.borderColor.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 24, color: isSelected ? AppColors.primary : context.textTertiaryColor),
              const SizedBox(height: 6),
              Text(label, style: AppTypography.labelSmall.copyWith(
                color: isSelected ? AppColors.primary : context.textSecondaryColor,
              )),
            ],
          ),
        ),
      ),
    );
  }
}

/// Multi-select student picker widget for targeting specific students.
class _StudentMultiSelect extends ConsumerWidget {
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;

  const _StudentMultiSelect({
    required this.selectedIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(studentsProvider);

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_search_rounded, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Select Students', style: AppTypography.labelLarge),
              const Spacer(),
              if (selectedIds.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${selectedIds.length} selected',
                    style: AppTypography.labelSmall.copyWith(color: AppColors.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          studentsAsync.when(
            data: (students) {
              if (students.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No students available',
                    style: AppTypography.bodySmall.copyWith(color: context.textTertiaryColor),
                  ),
                );
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    final isSelected = selectedIds.contains(student.studentId);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            final ids = Set<String>.from(selectedIds);
                            if (isSelected) {
                              ids.remove(student.studentId);
                            } else {
                              ids.add(student.studentId);
                            }
                            onChanged(ids);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: isSelected
                                  ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primary : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isSelected ? AppColors.primary : context.borderColor,
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppColors.secondary.withValues(alpha: 0.15),
                                  child: Text(
                                    student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                                    style: AppTypography.labelMedium.copyWith(color: AppColors.secondary),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(student.name, style: AppTypography.labelMedium),
                                      if (student.seatNumber != null)
                                        Text(
                                          'Seat: ${student.seatNumber}',
                                          style: AppTypography.labelSmall.copyWith(fontSize: 10),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Text('Error loading students: $e',
                style: AppTypography.bodySmall.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
