import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/auto_hide_sheet.dart';
import '../../../../core/widgets/plan_upgrade_prompt.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/services/export_service.dart';
import '../../../../core/services/offline_attendance_service.dart';
import '../../../../core/widgets/pdf_preview_screen.dart';
import '../../../subscription/data/services/plan_guard.dart';
import '../../data/models/attendance_model.dart';
import '../providers/attendance_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../students/data/models/student_model.dart';
import '../../../students/presentation/providers/student_provider.dart';
import '../../../../core/l10n/app_localizations.dart';

/// Attendance Screen
/// Daily attendance with check-in/check-out and manual entry
class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  String _formatDate(DateTime date) {
    return '${date.day} ${_months[date.month - 1]} ${date.year}, ${_weekdays[date.weekday - 1]}';
  }

  Widget _buildOfflineSyncBanner() {
    return ValueListenableBuilder<int>(
      valueListenable: OfflineAttendanceService.instance.pendingCountNotifier,
      builder: (context, pendingCount, _) {
        if (pendingCount == 0) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_rounded, color: AppColors.warning, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$pendingCount offline record${pendingCount > 1 ? 's' : ''} queued. Will sync automatically.',
                  style: AppTypography.bodySmall.copyWith(
                    color: context.textPrimaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              InkWell(
                onTap: () async {
                  final repo = ref.read(attendanceRepositoryProvider);
                  final synced = await OfflineAttendanceService.instance.syncQueue(repo);
                  if (context.mounted && synced > 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Synced $synced offline attendance record(s)!'),
                        backgroundColor: AppColors.accent,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    'Sync Now',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateSelector(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final isToday = selectedDay == today;
    final isFuture = selectedDay.isAfter(today);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            // Previous day
            GestureDetector(
              onTap: () {
                ref.read(selectedDateProvider.notifier).state = selectedDate
                    .subtract(const Duration(days: 1));
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: 20,
                  color: context.textPrimaryColor,
                ),
              ),
            ),
            // Date text (tappable for datepicker)
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: today,
                    builder: (ctx, child) {
                      return Theme(
                        data: Theme.of(ctx).copyWith(
                          colorScheme: ColorScheme.dark(
                            primary: AppColors.primary,
                            surface: context.surfaceColor,
                            onSurface: context.textPrimaryColor,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    ref.read(selectedDateProvider.notifier).state = picked;
                  }
                },
                child: Column(
                  children: [
                    Text(
                      _formatDate(selectedDate),
                      style: AppTypography.labelLarge.copyWith(
                        color: context.textPrimaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isToday)
                      Text(
                        'Today',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Next day (disabled if today or future)
            GestureDetector(
              onTap: isFuture
                  ? null
                  : () {
                      ref.read(selectedDateProvider.notifier).state =
                          selectedDate.add(const Duration(days: 1));
                    },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: isFuture
                      ? context.textTertiaryColor.withValues(alpha: 0.3)
                      : context.textPrimaryColor,
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Today button
            if (!isToday)
              GestureDetector(
                onTap: () {
                  ref.read(selectedDateProvider.notifier).state =
                      DateTime.now();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Today',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showMarkAttendanceSheet() {
    showAutoHideSheet(
      context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _MarkAttendanceSheet(),
    );
  }

  Future<void> _toggleCheckOut(AttendanceRecord record) async {
    if (!mounted) return;
    final selectedDate = ref.read(selectedDateProvider);
    final dateKey = Formatters.firestoreDateKey(selectedDate);
    final now = DateTime.now();
    final effectiveCheckOut = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      now.hour,
      now.minute,
      now.second,
    );

    try {
      if (record.checkOut == null) {
        await ref
            .read(attendanceRepositoryProvider)
            .checkOut(dateKey: dateKey, studentId: record.studentId, checkOutTime: effectiveCheckOut);
      } else {
        final updatedRecord = AttendanceRecord(
          studentId: record.studentId,
          studentName: record.studentName,
          checkIn: record.checkIn,
          checkOut: null,
          method: record.method,
          isLate: record.isLate,
        );
        await ref
            .read(attendanceRepositoryProvider)
            .markAttendance(dateKey: dateKey, record: updatedRecord);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteRecord(AttendanceRecord record) async {
    if (!mounted) return;
    final selectedDate = ref.read(selectedDateProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Remove Record', style: AppTypography.headlineSmall),
        content: Text(
          'Remove ${record.studentName} from this day\'s attendance?',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTypography.labelLarge.copyWith(
                color: context.textSecondaryColor,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Remove',
              style: AppTypography.labelLarge.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final dateKey = Formatters.firestoreDateKey(selectedDate);
    final current = ref.read(attendanceProvider).valueOrNull;
    if (current == null) return;

    final records = List<AttendanceRecord>.from(current.records);
    records.removeWhere((r) => r.studentId == record.studentId);

    final present = records
        .where((r) => r.checkIn != null && r.checkOut == null)
        .length;
    final absent = records.where((r) => r.checkIn == null).length;

    final updated = AttendanceModel(
      date: dateKey,
      records: records,
      totalPresent: present,
      totalAbsent: absent,
    );

    try {
      await ref
          .read(firestoreServiceProvider)
          .attendanceCol
          .doc(dateKey)
          .set(updated.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _exportAttendance() async {
    final selectedDate = ref.read(selectedDateProvider);
    final dateKey = Formatters.firestoreDateKey(selectedDate);
    final doc = await ref
        .read(firestoreServiceProvider)
        .attendanceCol
        .doc(dateKey)
        .get();

    if (!doc.exists || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No attendance data for this date'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    final attendance = AttendanceModel.fromFirestore(doc);
    final records = attendance.records;

    final attendanceData = records
        .map(
          (r) => {
            'studentName': r.studentName,
            'checkIn': r.checkIn != null
                ? '${r.checkIn!.hour.toString().padLeft(2, '0')}:${r.checkIn!.minute.toString().padLeft(2, '0')}'
                : '--',
            'checkOut': r.checkOut != null
                ? '${r.checkOut!.hour.toString().padLeft(2, '0')}:${r.checkOut!.minute.toString().padLeft(2, '0')}'
                : '--',
            'status': r.checkIn != null
                ? (r.checkOut != null ? 'Checked Out' : 'Present')
                : 'Absent',
            'isLate': r.isLate ? 'Yes' : 'No',
          },
        )
        .toList();

    try {
      final bytes = await ExportService.instance.getAttendanceBytes(
        records: attendanceData,
        date: dateKey,
        libraryName:
            ref.read(libraryModelProvider).valueOrNull?.libraryName ??
            'Library Manager',
      );
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PdfPreviewScreen(pdfBytes: bytes, title: 'Attendance Report'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendanceAsync = ref.watch(attendanceProvider);
    final studentsAsync = ref.watch(studentsStreamProvider);

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
                      AppLocalizations.of(context)!.attendance,
                      style: AppTypography.headlineMedium,
                    ),
                    const Spacer(),
                    // Export button
                    GestureDetector(
                      onTap: _exportAttendance,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: context.cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: context.borderColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.picture_as_pdf_rounded,
                              size: 16,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Export',
                              style: AppTypography.labelMedium.copyWith(
                                color: context.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              _buildDateSelector(context, ref),
              _buildOfflineSyncBanner(),
              const SizedBox(height: 16),

              // Stats: Total Students, Present, Absent, Attendance %
              attendanceAsync.when(
                data: (attendance) {
                  final records = attendance.records;
                  final total = records.length;
                  final present = records
                      .where((r) => r.checkIn != null && r.checkOut == null)
                      .length;
                  final checkedOut = records
                      .where((r) => r.checkIn != null && r.checkOut != null)
                      .length;
                  final absent = records.where((r) => r.checkIn == null).length;
                  final presentAndCheckedOut = present + checkedOut;
                  final rate = total > 0
                      ? (presentAndCheckedOut / total * 100).toStringAsFixed(0)
                      : '0';

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _StatBox(
                          label: 'Students',
                          value:
                              '${studentsAsync.valueOrNull?.length ?? total}',
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        _StatBox(
                          label: 'Present',
                          value: '$presentAndCheckedOut',
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 10),
                        _StatBox(
                          label: 'Absent',
                          value: '$absent',
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 10),
                        _StatBox(
                          label: 'Rate',
                          value: '$rate%',
                          color: AppColors.neonPurple,
                        ),
                      ],
                    ),
                  );
                },
                loading: () => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _StatBox(
                        label: 'Students',
                        value: '-',
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      _StatBox(
                        label: 'Present',
                        value: '-',
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 10),
                      _StatBox(
                        label: 'Absent',
                        value: '-',
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 10),
                      _StatBox(
                        label: 'Rate',
                        value: '-',
                        color: AppColors.neonPurple,
                      ),
                    ],
                  ),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _StatBox(
                        label: 'Students',
                        value: '!',
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 10),
                      _StatBox(
                        label: 'Present',
                        value: '!',
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 10),
                      _StatBox(
                        label: 'Absent',
                        value: '!',
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 10),
                      _StatBox(
                        label: 'Rate',
                        value: '!',
                        color: AppColors.error,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // List
              Expanded(
                child: attendanceAsync.when(
                  data: (attendance) {
                    final records = attendance.records;
                    if (records.isEmpty) {
                      return EmptyState(
                        icon: Icons.people_rounded,
                        title: 'No attendance records',
                        subtitle:
                            'Tap the button below to mark attendance for today',
                      );
                    }
                    return RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () async {
                        ref.invalidate(attendanceProvider);
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: records.length,
                        itemBuilder: (context, index) {
                          final record = records[index];
                          return _AttendanceTile(
                            record: record,
                            onToggle: () => _toggleCheckOut(record),
                            onLongPress: () => _deleteRecord(record),
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                  error: (e, _) => EmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'Error loading attendance',
                    subtitle: e.toString(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        elevation: 0,
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onPressed: _showMarkAttendanceSheet,
        icon: const Icon(Icons.person_add_rounded, size: 20),
        label: Text(
          AppLocalizations.of(context)!.markAttendance,
          style: AppTypography.labelLarge.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTypography.titleMedium.copyWith(color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: color,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceTile extends StatelessWidget {
  final AttendanceRecord record;
  final VoidCallback onToggle;
  final VoidCallback onLongPress;
  const _AttendanceTile({
    required this.record,
    required this.onToggle,
    required this.onLongPress,
  });

  String _formatTime(DateTime? dt) {
    if (dt == null) return '--';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final hasCheckedOut = record.checkOut != null;
    final isCheckedIn = record.checkIn != null;
    final statusColor = hasCheckedOut
        ? AppColors.secondary
        : isCheckedIn
        ? AppColors.accent
        : AppColors.error;

    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  Formatters.initials(record.studentName),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.studentName,
                    style: AppTypography.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'In: ${_formatTime(record.checkIn)}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Out: ${_formatTime(record.checkOut)}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.secondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (record.isLate) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Late',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.warning,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Toggle (check-out / checked-out indicator)
            GestureDetector(
              onTap: onToggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 52,
                height: 30,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: hasCheckedOut
                      ? AppColors.secondary
                      : isCheckedIn
                      ? AppColors.accent
                      : context.surfaceCardLight,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: hasCheckedOut
                      ? Alignment.centerRight
                      : isCheckedIn
                      ? Alignment.center
                      : Alignment.centerLeft,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onLongPress,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  size: 16,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Manual "Mark Attendance" bottom sheet. Owns its controller so it is
/// disposed exactly when the sheet is disposed, and scrolls to avoid
/// keyboard overflow.
class _MarkAttendanceSheet extends ConsumerStatefulWidget {
  const _MarkAttendanceSheet();

  @override
  ConsumerState<_MarkAttendanceSheet> createState() =>
      _MarkAttendanceSheetState();
}

class _MarkAttendanceSheetState extends ConsumerState<_MarkAttendanceSheet> {
  final _formKey = GlobalKey<FormState>();
  StudentModel? _selectedStudent;
  bool _isSaving = false;

  Future<void> _submit() async {
    final student = _selectedStudent;
    if (student == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a student')),
      );
      return;
    }
    setState(() => _isSaving = true);
    final selectedDate = ref.read(selectedDateProvider);
    final now = DateTime.now();
    final effectiveCheckIn = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      now.hour,
      now.minute,
      now.second,
    );
    final dateKey = Formatters.firestoreDateKey(selectedDate);
    final record = AttendanceRecord(
      studentId: student.studentId,
      studentName: student.name,
      checkIn: effectiveCheckIn,
      method: 'manual',
      isLate: false,
    );
    // Capture messenger before the async gap so we never look up a
    // deactivated widget ancestor afterwards.
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(attendanceRepositoryProvider)
          .markAttendance(dateKey: dateKey, record: record);
    } on PlanLimitExceededException {
      if (mounted) {
        showPlanUpgradePrompt(context);
        setState(() => _isSaving = false);
      }
      return;
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsStreamProvider);
    final students = studentsAsync.valueOrNull ?? [];
    final isLoading = studentsAsync.isLoading && students.isEmpty;
    final hasError = studentsAsync.hasError;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  AppLocalizations.of(context)!.markAttendance,
                  style: AppTypography.headlineMedium,
                ),
                const SizedBox(height: 20),
                // Student dropdown — all added students are shown for selection
                InputDecorator(
                  isEmpty: _selectedStudent == null,
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.person_rounded,
                      color: context.textSecondaryColor,
                    ),
                    filled: true,
                    fillColor: context.cardBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: context.borderColor.withValues(alpha: 0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: context.borderColor.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppColors.accent,
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: isLoading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text('Loading students...'),
                            ],
                          ),
                        )
                      : DropdownButtonHideUnderline(
                          child: DropdownButton<StudentModel>(
                            value: _selectedStudent,
                            isExpanded: true,
                            hint: Text(
                              hasError
                                  ? 'Failed to load students'
                                  : students.isEmpty
                                      ? 'No students added yet'
                                      : 'Select Student',
                              style: AppTypography.bodyMedium.copyWith(
                                color: context.textSecondaryColor,
                              ),
                            ),
                            dropdownColor: context.cardBg,
                            style: AppTypography.bodyMedium.copyWith(
                              color: context.textPrimaryColor,
                            ),
                            items: students.map((s) {
                              return DropdownMenuItem<StudentModel>(
                                value: s,
                                child: Text(
                                  s.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: students.isEmpty
                                ? null
                                : (s) {
                                    setState(() => _selectedStudent = s);
                                  },
                          ),
                        ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      disabledBackgroundColor:
                          AppColors.accent.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.person_add_rounded, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Mark Present',
                                style: AppTypography.buttonText.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
