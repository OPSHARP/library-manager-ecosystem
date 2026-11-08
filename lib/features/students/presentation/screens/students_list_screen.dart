import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/search_bar_widget.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../../app/router.dart';
import '../../data/models/student_model.dart';
import '../../presentation/providers/student_provider.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/utils/extensions.dart';
import '../../../attendance/data/repositories/attendance_repository.dart';
import '../../../books/presentation/providers/book_provider.dart';
import '../../../fees/presentation/providers/fee_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class StudentsListScreen extends ConsumerStatefulWidget {
  const StudentsListScreen({super.key});

  @override
  ConsumerState<StudentsListScreen> createState() => _StudentsListScreenState();
}

class _StudentsListScreenState extends ConsumerState<StudentsListScreen> {
  String _selectedFilter = 'All';

  Future<void> _handleLongPress(StudentModel student) async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(student.name, style: AppTypography.titleMedium),
        content: const Text('Choose an action:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'kick'),
            child: const Text(
              'Kick Student',
              style: TextStyle(color: AppColors.neonPurple),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'ban'),
            child: const Text(
              'Ban Student',
              style: TextStyle(color: AppColors.warning),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'delete'),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (action == null || action == 'cancel') return;

    bool? confirm;
    if (mounted) {
      confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: ctx.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            action == 'kick'
                ? 'Kick Student'
                : action == 'ban'
                    ? 'Ban Student'
                    : 'Delete Student',
            style: AppTypography.titleMedium,
          ),
          content: Text(
            action == 'kick'
                ? '${student.name} will be removed from your library. Their seat will be released and the student will auto-leave. Continue?'
                : action == 'ban'
                    ? '${student.name} will be banned. Their seat will be released. Continue?'
                    : '${student.name} will be permanently deleted. Their seat will be released. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                action == 'kick'
                    ? 'Kick'
                    : action == 'ban'
                        ? 'Ban'
                        : 'Delete',
                style: TextStyle(
                  color: action == 'kick'
                      ? AppColors.neonPurple
                      : action == 'ban'
                          ? AppColors.warning
                          : AppColors.error,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (confirm != true) return;

    try {
      final studentRepo = ref.read(studentRepositoryProvider);

      if (action == 'kick') {
        // Kick is handled SERVER-SIDE so it can atomically release the seat,
        // clear the student's profile linkage (→ student auto-leaves) and
        // notify the student. A client write could not touch the profile.
        await FirebaseFunctions.instance
            .httpsCallable('kickStudent')
            .call({'studentId': student.uniqueId});
        if (mounted) context.showSuccess('${student.name} has been removed');
      } else if (action == 'ban') {
        // Ban must NOT delete the student — that would destroy fee/attendance
        // history and (via the old code) briefly delete + recreate the doc.
        // Instead: free the seat, then mark the student suspended.
        if (student.seatId != null && student.seatId!.isNotEmpty) {
          await studentRepo.releaseSeat(student.seatId!);
        }
        await studentRepo.updateStudent(
          student.copyWith(
            isActive: false,
            status: 'suspended',
            seatId: null,
            seatNumber: null,
          ),
        );
        if (mounted) context.showSuccess('${student.name} has been banned');
      } else {
        // Cascade-delete all related data from Firestore before removing the
        // student. The four cleanups touch INDEPENDENT collections (fees,
        // attendance, books, students+seat), so they run in parallel — the
        // delete finishes in ~1 network round-trip instead of 4 sequential
        // ones. Any single failure must not abort the whole delete.
        final attendanceRepo = AttendanceRepository(
          ref.read(firestoreServiceProvider),
        );
        await Future.wait([
          ref.read(feeRepositoryProvider).deleteFeesForStudent(student.studentId),
          attendanceRepo.removeStudentRecords(student.studentId),
          ref.read(bookRepositoryProvider).returnBooksForStudent(student.studentId),
          studentRepo.deleteStudentAndReleaseSeat(
            student.studentId,
            student.seatId,
          ),
        ]);
        if (mounted) context.showSuccess('${student.name} has been deleted');
      }

      ref.invalidate(studentsStreamProvider);
    } catch (e) {
      if (mounted) context.showError('Failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider);

    return Scaffold(
      body: Container(
        color: context.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Text(
                      AppLocalizations.of(context)!.students,
                      style: AppTypography.headlineMedium,
                    ),
                    const Spacer(),
                    Text(
                      '${studentsAsync.valueOrNull?.length ?? 0} students',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: CustomSearchBar(
                  hintText: 'Search students...',
                  onChanged: (v) =>
                      ref.read(studentsSearchProvider.notifier).state = v,
                ),
              ),
              const SizedBox(height: 14),

              // Filter chips
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: _filters.map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedFilter = filter;
                          ref.read(studentsFilterProvider.notifier).state =
                              filter;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : context.cardBg,
                            borderRadius: BorderRadius.circular(10),
                            border: !isSelected
                                ? Border.all(
                                    color: context.borderColor.withValues(
                                      alpha: 0.3,
                                    ),
                                  )
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              filter,
                              style: AppTypography.labelMedium.copyWith(
                                color: isSelected
                                    ? Colors.white
                                    : context.textSecondaryColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),

              // Student list
              Expanded(
                child: studentsAsync.when(
                  data: (students) => students.isEmpty
                      ? EmptyState(
                          icon: Icons.people_outline_rounded,
                          title: 'No Students Yet',
                          subtitle: 'Add your first student to get started',
                          actionText: AppLocalizations.of(context)!.addStudent,
                          onAction: () => context.push(AppRoutes.addStudent),
                        )
                      : RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: () async {
                            ref.invalidate(studentsStreamProvider);
                          },
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: students.length,
                            itemBuilder: (context, index) {
                              return _StudentCard(
                                student: students[index],
                                onTap: () => context.push(
                                  '/students/${students[index].studentId}',
                                ),
                                onLongPress: () =>
                                    _handleLongPress(students[index]),
                              );
                            },
                          ),
                        ),
                  loading: () => const SkeletonList(),
                  error: (e, _) => Center(
                    child: Text(
                      'Error: $e',
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
        onPressed: () => context.push(AppRoutes.addStudent),
        child: const Icon(Icons.person_add_rounded),
      ),
    );
  }

  static const _filters = ['All', 'Active', 'Inactive', 'Fee Pending'];
}

String _shortDate(DateTime? d) {
  if (d == null) return '—';
  final day = d.day.toString().padLeft(2, '0');
  final month = d.month.toString().padLeft(2, '0');
  return '$day-$month-${d.year}';
}

class _StudentCard extends StatelessWidget {
  final StudentModel student;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _StudentCard({
    required this.student,
    required this.onTap,
    this.onLongPress,
  });

  Color _feeStatusColor(BuildContext context) {
    switch (student.feeStatus) {
      case 'paid':
        return AppColors.feePaid;
      case 'pending':
        return AppColors.feePending;
      case 'overdue':
        return AppColors.feeOverdue;
      default:
        return context.textTertiaryColor;
    }
  }

  static Color _lifecycleStatusColor(String status) {
    switch (status) {
      case 'enrolled':
        return const Color(0xFF3B82F6);
      case 'active':
        return const Color(0xFF10B981);
      case 'suspended':
        return const Color(0xFFEF4444);
      case 'graduated':
        return const Color(0xFF8B5CF6);
      case 'alumni':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF10B981);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = student.name;
    final initials = name.isNotEmpty
        ? name
              .split(' ')
              .where((w) => w.isNotEmpty)
              .map((w) => w[0])
              .take(2)
              .join()
        : '?';

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: AppTypography.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.chair_rounded,
                        size: 14,
                        color: context.textTertiaryColor,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          student.seatNumber != null
                              ? 'Seat ${student.seatNumber}'
                              : 'No seat',
                          style: AppTypography.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.phone_rounded,
                        size: 14,
                        color: context.textTertiaryColor,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          student.phone,
                          style: AppTypography.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (student.uniqueId.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.qr_code_2_rounded,
                          size: 14,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'ID: ${student.uniqueId}',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.accent,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (student.joiningDate != null || student.leaveDate != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.event_rounded,
                          size: 14,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Joined: ${_shortDate(student.joiningDate ?? student.createdAt)}'
                            '${student.leaveDate != null ? '  •  Left: ${_shortDate(student.leaveDate)}' : ''}',
                            style: AppTypography.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _lifecycleStatusColor(
                      student.status,
                    ).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    student.status.toUpperCase(),
                    style: AppTypography.badge.copyWith(
                      color: _lifecycleStatusColor(student.status),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _feeStatusColor(context).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'FEE: ${student.feeStatus.toUpperCase()}',
                    style: AppTypography.badge.copyWith(
                      color: _feeStatusColor(context),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
