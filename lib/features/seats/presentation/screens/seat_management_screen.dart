import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../../../core/widgets/auto_hide_sheet.dart';
import '../../../../core/widgets/plan_upgrade_prompt.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../students/data/models/student_model.dart';
import '../../../students/presentation/providers/student_provider.dart';
import '../../../subscription/data/services/plan_guard.dart';
import '../../data/models/seat_model.dart';
import '../providers/seat_provider.dart';
import '../../../../core/l10n/app_localizations.dart';

/// Seat Management Screen
/// Interactive seat grid with categories, color-coded status and reservations
class SeatManagementScreen extends ConsumerStatefulWidget {
  const SeatManagementScreen({super.key});

  @override
  ConsumerState<SeatManagementScreen> createState() =>
      _SeatManagementScreenState();
}

class _SeatManagementScreenState extends ConsumerState<SeatManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _categories = [
    'All',
    'Normal',
    'AC',
    'Premium',
    'Cabin',
    'Reserved',
  ];

  @override
  void initState() {
    super.initState();
    final currentCategory = ref.read(seatCategoryProvider);
    final initialIndex = _categories.indexOf(currentCategory);
    _tabController = TabController(
      length: _categories.length,
      vsync: this,
      initialIndex: initialIndex >= 0 ? initialIndex : 0,
    )..addListener(() {
        if (!_tabController.indexIsChanging) {
          ref.read(seatCategoryProvider.notifier).state =
              _categories[_tabController.index];
        }
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Bottom sheet: Add new seat ──
  void _showAddSeatSheet(String libraryId) {
    // Capture the repository before the async sheet work so the onSave
    // closure never touches `ref` after this widget could be disposed.
    final seatRepo = ref.read(seatRepositoryProvider);
    showAutoHideSheet(
      context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SeatFormSheet(
        libraryId: libraryId,
        currencySymbol: ref.read(settingsProvider).currencySymbol,
        onSave: (number, category, price) async {
          final seat = SeatModel(
            seatId: '',
            seatNumber: number,
            category: category,
            price: price,
          );
          await seatRepo.addSeat(seat);
        },
      ),
    );
  }

  // ── Student picker for assignment (permanent) ──
  void _showStudentPickerForAssign(String libraryId, SeatModel seat) {
    final students = ref.read(studentsStreamProvider).valueOrNull;
    if (students == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading students...')),
      );
      return;
    }
    // Only students WITHOUT an assigned seat may be given a new seat.
    final activeStudents = students
        .where(
          (s) => s.isActive && (s.seatId == null || s.seatId!.isEmpty),
        )
        .toList();
    if (activeStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No unseated students available')),
      );
      return;
    }
    _showAssignDialog(libraryId, seat, activeStudents);
  }

  // ── Student picker dialog for reservation ──
  void _showStudentPicker(String libraryId, SeatModel seat) {
    final students = ref.read(studentsStreamProvider).valueOrNull;
    if (students == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading students...')),
      );
      return;
    }
    // Only students WITHOUT an assigned seat may reserve a seat.
    final activeStudents = students
        .where(
          (s) => s.isActive && (s.seatId == null || s.seatId!.isEmpty),
        )
        .toList();
    if (activeStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No unseated students available')),
      );
      return;
    }
    _showReserveDialog(libraryId, seat, activeStudents);
  }

  // ── Assign dialog (permanent, no date pickers) ──
  void _showAssignDialog(
      String libraryId, SeatModel seat, List<StudentModel> students) {
    StudentModel? selectedStudent;
    String selectedShift = 'full_day';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: context.surfaceColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Assign Seat ${seat.seatNumber}',
                style: AppTypography.headlineSmall
                    .copyWith(color: context.textPrimaryColor),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<StudentModel>(
                          value: selectedStudent,
                          isExpanded: true,
                          hint: Text('Select Student',
                              style: AppTypography.bodyMedium
                                  .copyWith(color: context.textSecondaryColor)),
                          dropdownColor: context.cardBg,
                          style: AppTypography.bodyMedium
                              .copyWith(color: context.textPrimaryColor),
                          items: students
                              .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s.name),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(() => selectedStudent = v);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedShift,
                          isExpanded: true,
                          dropdownColor: context.cardBg,
                          style: AppTypography.bodyMedium
                              .copyWith(color: context.textPrimaryColor),
                          items: const [
                            DropdownMenuItem(value: 'full_day', child: Text('Full Day Shift')),
                            DropdownMenuItem(value: 'morning', child: Text('Morning (6 AM - 12 PM)')),
                            DropdownMenuItem(value: 'evening', child: Text('Evening (12 PM - 6 PM)')),
                            DropdownMenuItem(value: 'night', child: Text('Night (6 PM - 12 AM)')),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(() => selectedShift = v);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The seat will be assigned to this student for the chosen shift.',
                      style: AppTypography.bodySmall
                          .copyWith(color: context.textSecondaryColor),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel',
                      style: AppTypography.bodyMedium
                          .copyWith(color: context.textTertiaryColor)),
                ),
                ElevatedButton(
                  onPressed: selectedStudent == null
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          try {
                            if (selectedShift == 'full_day') {
                              await ref
                                  .read(seatRepositoryProvider)
                                  .allocateSeat(
                                    seat.seatId,
                                    selectedStudent!.studentId,
                                    selectedStudent!.name,
                                  );
                            } else {
                              await ref
                                  .read(seatRepositoryProvider)
                                  .allocateShiftSeat(
                                    seatId: seat.seatId,
                                    shift: selectedShift,
                                    studentId: selectedStudent!.studentId,
                                    studentName: selectedStudent!.name,
                                  );
                            }
                            await ref
                                .read(studentRepositoryProvider)
                                .updateStudent(
                                  selectedStudent!.copyWith(
                                    seatId: seat.seatId,
                                    seatNumber: seat.seatNumber,
                                  ),
                                );
                          ref.read(activityRepositoryProvider).logActivity(
                            type: 'seat_changed',
                            description: 'Seat ${seat.seatNumber} ($selectedShift) assigned to ${selectedStudent!.name}',
                            relatedId: selectedStudent!.studentId,
                          );
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to assign seat: $e')),
                              );
                            }
                            return;
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Seat ${seat.seatNumber} assigned to ${selectedStudent!.name}'),
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Assign'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showReserveDialog(
      String libraryId, SeatModel seat, List<StudentModel> students) {
    StudentModel? selectedStudent;
    DateTime reservedFrom = DateTime.now();
    DateTime reservedUntil = DateTime.now().add(const Duration(hours: 4));

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: context.surfaceColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Reserve Seat ${seat.seatNumber}',
                style: AppTypography.headlineSmall
                    .copyWith(color: context.textPrimaryColor),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Student dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<StudentModel>(
                          value: selectedStudent,
                          isExpanded: true,
                          hint: Text('Select Student',
                              style: AppTypography.bodyMedium
                                  .copyWith(color: context.textSecondaryColor)),
                          dropdownColor: context.cardBg,
                          style: AppTypography.bodyMedium
                              .copyWith(color: context.textPrimaryColor),
                          items: students
                              .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s.name),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(() => selectedStudent = v);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // From date
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('From',
                          style: AppTypography.labelMedium
                              .copyWith(color: context.textSecondaryColor)),
                      subtitle: Text(
                        '${reservedFrom.day}/${reservedFrom.month}/${reservedFrom.year} '
                        '${reservedFrom.hour.toString().padLeft(2, '0')}:${reservedFrom.minute.toString().padLeft(2, '0')}',
                        style: AppTypography.bodyMedium,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_today_rounded,
                            size: 20),
                        onPressed: () async {
                          // ignore: use_build_context_synchronously
                          final date = await showDatePicker(
                            context: ctx,
                            initialDate: reservedFrom,
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            final time = await showTimePicker(
                              // ignore: use_build_context_synchronously
                              context: ctx,
                              initialTime:
                                  TimeOfDay.fromDateTime(reservedFrom),
                            );
                            setDialogState(() {
                              reservedFrom = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time?.hour ?? reservedFrom.hour,
                                time?.minute ?? reservedFrom.minute,
                              );
                              if (reservedUntil.isBefore(reservedFrom)) {
                                reservedUntil =
                                    reservedFrom.add(const Duration(hours: 4));
                              }
                            });
                          }
                        },
                      ),
                    ),
                    // Until date
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('Until',
                          style: AppTypography.labelMedium
                              .copyWith(color: context.textSecondaryColor)),
                      subtitle: Text(
                        '${reservedUntil.day}/${reservedUntil.month}/${reservedUntil.year} '
                        '${reservedUntil.hour.toString().padLeft(2, '0')}:${reservedUntil.minute.toString().padLeft(2, '0')}',
                        style: AppTypography.bodyMedium,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_today_rounded,
                            size: 20),
                        onPressed: () async {
                          // ignore: use_build_context_synchronously
                          final date = await showDatePicker(
                            context: ctx,
                            initialDate: reservedUntil,
                            firstDate: reservedFrom,
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            final time = await showTimePicker(
                              // ignore: use_build_context_synchronously
                              context: ctx,
                              initialTime:
                                  TimeOfDay.fromDateTime(reservedUntil),
                            );
                            setDialogState(() {
                              reservedUntil = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time?.hour ?? reservedUntil.hour,
                                time?.minute ?? reservedUntil.minute,
                              );
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel',
                      style: AppTypography.bodyMedium
                          .copyWith(color: context.textTertiaryColor)),
                ),
                ElevatedButton(
                  onPressed: selectedStudent == null
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          try {
                            await ref
                                .read(seatRepositoryProvider)
                                .reserveSeat(
                                  seat.seatId,
                                  selectedStudent!.studentId,
                                  selectedStudent!.name,
                                  reservedFrom,
                                  reservedUntil,
                                );
                            await ref
                                .read(studentRepositoryProvider)
                                .updateStudent(
                                  selectedStudent!.copyWith(
                                    seatId: seat.seatId,
                                    seatNumber: seat.seatNumber,
                                  ),
                                );
                          ref.read(activityRepositoryProvider).logActivity(
                            type: 'seat_changed',
                            description: 'Seat ${seat.seatNumber} reserved for ${selectedStudent!.name}',
                            relatedId: selectedStudent!.studentId,
                          );
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to reserve seat: $e')),
                              );
                            }
                            return;
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Seat ${seat.seatNumber} reserved for ${selectedStudent!.name}'),
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Reserve'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Bottom sheet: Seat details with Edit / Delete / Reserve / Cancel ──
  void _showSeatDetails(String libraryId, SeatModel seat) {
    showAutoHideSheet(
      context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.surfaceCardLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(seat.seatNumber, style: AppTypography.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Category: ${seat.category}',
                style: AppTypography.bodyMedium
                    .copyWith(color: context.textSecondaryColor),
              ),
              Text(
                'Status: ${seat.status.toUpperCase()}',
                style: AppTypography.bodyMedium
                    .copyWith(color: _getSeatColor(seat.status, context)),
              ),
              if (seat.price > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'Price: ${ref.read(settingsProvider).currencySymbol}${seat.price.toStringAsFixed(0)}/month',
                  style: AppTypography.bodyMedium
                      .copyWith(color: context.textSecondaryColor),
                ),
              ],
              if (seat.status == 'reserved' && seat.reservation != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.event_available_rounded,
                              size: 16, color: AppColors.warning),
                          const SizedBox(width: 6),
                          Text('Reservation Details',
                              style: AppTypography.labelMedium
                                  .copyWith(color: AppColors.warning)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Reserved by: ${seat.reservation!.reservedByName}',
                        style: AppTypography.bodyMedium,
                      ),
                      Text(
                        'From: ${_formatDateTime(seat.reservation!.reservedFrom)}',
                        style: AppTypography.bodySmall
                            .copyWith(color: context.textSecondaryColor),
                      ),
                      Text(
                        'Until: ${_formatDateTime(seat.reservation!.reservedUntil)}',
                        style: AppTypography.bodySmall
                            .copyWith(color: context.textSecondaryColor),
                      ),
                    ],
                  ),
                ),
              ],
              if (seat.status == 'occupied' &&
                  seat.assignedStudentName != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Assigned: ${seat.assignedStudentName}',
                  style: AppTypography.bodyMedium,
                ),
              ],
              if (seat.renewalDate != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Renewal: ${seat.renewalDate!.day}/${seat.renewalDate!.month}/${seat.renewalDate!.year}',
                  style: AppTypography.bodySmall
                      .copyWith(color: context.textTertiaryColor),
                ),
              ],
              if (seat.shifts != null && seat.shifts!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shift Assignments',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...seat.shifts!.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.key.toUpperCase(),
                                    style: AppTypography.labelSmall.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Text(
                                    entry.value.studentName,
                                    style: AppTypography.bodySmall,
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.error),
                                tooltip: 'Release this shift',
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  await ref.read(seatRepositoryProvider).releaseShiftSeat(
                                    seatId: seat.seatId,
                                    shift: entry.key,
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              // Action buttons based on status
              if (seat.status == 'available') ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showDeleteConfirm(libraryId, seat);
                        },
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 18),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showStudentPickerForAssign(libraryId, seat);
                        },
                        icon: const Icon(Icons.person_pin_rounded,
                            size: 18),
                        label: const Text('Assign'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showStudentPicker(libraryId, seat);
                    },
                    icon: const Icon(Icons.event_available_rounded,
                        size: 18),
                    label: const Text('Reserve (Temporary)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.warning,
                      side: const BorderSide(color: AppColors.warning),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ] else if (seat.status == 'reserved') ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          if (seat.reservation != null) {
                            try {
                              final student = await ref
                                  .read(studentRepositoryProvider)
                                  .getStudent(seat.reservation!.reservedBy);
                              if (student != null) {
                                await ref
                                    .read(studentRepositoryProvider)
                                    .updateStudent(
                                      student.copyWith(
                                        seatId: null,
                                        seatNumber: null,
                                      ),
                                    );
                              }
                            } catch (_) { /* non-critical */ } // Non-critical: student update failure
                          }
                          await ref
                              .read(seatRepositoryProvider)
                              .cancelReservation(seat.seatId);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Reservation for seat ${seat.seatNumber} cancelled'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.event_busy_rounded, size: 18),
                        label: const Text('Cancel Reservation'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.warning,
                          side: const BorderSide(color: AppColors.warning),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // occupied or other
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              if (seat.assignedStudentId != null) {
                                try {
                                  final student = await ref
                                      .read(studentRepositoryProvider)
                                      .getStudent(seat.assignedStudentId!);
                                  if (student != null) {
                                    await ref
                                        .read(studentRepositoryProvider)
                                        .updateStudent(
                                          student.copyWith(
                                            seatId: null,
                                            seatNumber: null,
                                          ),
                                        );
                                  }
                                } catch (_) { /* non-critical */ } // Non-critical: student update failure
                              }
                              await ref
                                  .read(seatRepositoryProvider)
                                  .releaseSeat(seat.seatId);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Seat ${seat.seatNumber} released'),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.lock_open_rounded,
                                size: 18),
                            label: const Text('Release'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.success,
                              side:
                                  const BorderSide(color: AppColors.success),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showDeleteConfirm(libraryId, seat);
                            },
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 18),
                            label: const Text('Delete'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side:
                                  const BorderSide(color: AppColors.error),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showEditSeatSheet(libraryId, seat);
                        },
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: const Text('Edit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // ── Bottom sheet: Edit existing seat ──
  void _showEditSeatSheet(String libraryId, SeatModel seat) {
    // Capture the repository before the async sheet work so the onSave
    // closure never touches `ref` after this widget could be disposed.
    final seatRepo = ref.read(seatRepositoryProvider);
    showAutoHideSheet(
      context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SeatFormSheet(
        libraryId: libraryId,
        currencySymbol: ref.read(settingsProvider).currencySymbol,
        initialNumber: seat.seatNumber,
        initialCategory: seat.category,
        initialPrice: seat.price > 0 ? seat.price.toStringAsFixed(0) : '',
        isEdit: true,
        onSave: (number, category, price) async {
          final updated = seat.copyWith(
            seatNumber: number,
            category: category,
            price: price,
          );
          await seatRepo.updateSeat(updated);
        },
      ),
    );
  }

  // ── Confirm delete dialog ──
  void _showDeleteConfirm(String libraryId, SeatModel seat) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: context.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Delete Seat',
            style: AppTypography.headlineSmall
                .copyWith(color: context.textPrimaryColor),
          ),
          content: Text(
            'Are you sure you want to delete seat "${seat.seatNumber}"? This action cannot be undone.',
            style: AppTypography.bodyMedium
                .copyWith(color: context.textSecondaryColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: AppTypography.bodyMedium
                    .copyWith(color: context.textTertiaryColor),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await ref
                      .read(seatRepositoryProvider)
                      .deleteSeat(seat.seatId);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Failed to delete seat: $e')),
                    );
                  }
                }
              },
              child: Text(
                'Delete',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final seatsAsync = ref.watch(seatsProvider);
    final libraryId = ref.watch(libraryIdProvider) ?? '';

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
                    Text(AppLocalizations.of(context)!.seats,
                        style: AppTypography.headlineMedium),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: libraryId.isEmpty
                          ? null
                          : () => _showAddSeatSheet(libraryId),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Summary row
              seatsAsync.when(
                data: (seats) {
                  final allSeatsStream = seats;
                  final available = allSeatsStream
                      .where((s) => s.status == 'available')
                      .length;
                  final occupied = allSeatsStream
                      .where((s) => s.status == 'occupied')
                      .length;
                  final reserved = allSeatsStream
                      .where((s) => s.status == 'reserved')
                      .length;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _StatusBadge(
                            color: AppColors.seatAvailable,
                            label: 'Available',
                            count: available),
                        const SizedBox(width: 10),
                        _StatusBadge(
                            color: AppColors.seatOccupied,
                            label: 'Occupied',
                            count: occupied),
                        const SizedBox(width: 10),
                        _StatusBadge(
                            color: AppColors.seatReserved,
                            label: 'Reserved',
                            count: reserved),
                      ],
                    ),
                  );
                },
                loading: () => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _StatusBadge(
                          color: AppColors.seatAvailable,
                          label: 'Available',
                          count: 0),
                      const SizedBox(width: 10),
                      _StatusBadge(
                          color: AppColors.seatOccupied,
                          label: 'Occupied',
                          count: 0),
                      const SizedBox(width: 10),
                      _StatusBadge(
                          color: AppColors.seatReserved,
                          label: 'Reserved',
                          count: 0),
                    ],
                  ),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Error loading seats',
                      style: AppTypography.bodyMedium
                          .copyWith(color: AppColors.error)),
                ),
              ),
              const SizedBox(height: 16),

              // Category tabs (includes Reserved filter)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: context.textTertiaryColor,
                  dividerHeight: 0,
                  tabAlignment: TabAlignment.start,
                  tabs: _categories.map((c) => Tab(text: c)).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Seat grid
              Expanded(
                child: seatsAsync.when(
                  data: (seats) {
                    if (seats.isEmpty) {
                      return EmptyState(
                        icon: Icons.chair_rounded,
                        title: 'No Seats Yet',
                        subtitle: 'Tap + to add your first seat',
                        actionText: 'Add Seat',
                        onAction: libraryId.isEmpty
                            ? null
                            : () => _showAddSeatSheet(libraryId),
                      );
                    }
                    return RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () async {
                        ref.invalidate(seatsStreamProvider);
                      },
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 6 : MediaQuery.of(context).size.width > 400 ? 4 : 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1,
                        ),
                        itemCount: seats.length,
                        itemBuilder: (context, index) {
                          final seat = seats[index];
                          return _SeatTile(
                            seat: seat,
                            onTap: () =>
                                _showSeatDetails(libraryId, seat),
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary),
                  ),
                  error: (e, _) => EmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'Something went wrong',
                    subtitle: e.toString(),
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

String _formatDateTime(DateTime dt) {
  return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

Color _getSeatColor(String status, BuildContext context) {
  switch (status) {
    case 'available':
      return AppColors.seatAvailable;
    case 'occupied':
      return AppColors.seatOccupied;
    case 'reserved':
      return AppColors.seatReserved;
    case 'maintenance':
      return AppColors.seatMaintenance;
    default:
      return context.textTertiaryColor;
  }
}

IconData _getSeatIcon(String status) {
  switch (status) {
    case 'available':
      return Icons.chair_rounded;
    case 'occupied':
      return Icons.person_rounded;
    case 'reserved':
      return Icons.event_available_rounded;
    case 'maintenance':
      return Icons.build_rounded;
    default:
      return Icons.chair_rounded;
  }
}

class _SeatTile extends StatelessWidget {
  final SeatModel seat;
  final VoidCallback onTap;
  const _SeatTile({required this.seat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _getSeatColor(seat.status, context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_getSeatIcon(seat.status), color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              seat.seatNumber,
              style: AppTypography.labelSmall
                  .copyWith(color: color, fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
            if (seat.status == 'reserved' &&
                seat.reservation != null) ...[
              const SizedBox(height: 2),
              Text(
                seat.reservation!.reservedByName,
                style: AppTypography.labelSmall
                    .copyWith(color: color, fontSize: 8),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
            if (seat.shifts != null && seat.shifts!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  seat.activeShiftsSummary,
                  style: TextStyle(
                    color: color,
                    fontSize: 7,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  const _StatusBadge(
      {required this.color, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassContainer(
        borderRadius: 10,
        blur: 0,
        opacity: 0,
        padding: const EdgeInsets.symmetric(vertical: 10),
        borderColor: color.withValues(alpha: 0.2),
        child: Column(
          children: [
            Text('$count',
                style: AppTypography.titleMedium.copyWith(color: color)),
            Text(label,
                style: AppTypography.labelSmall
                    .copyWith(color: color, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

/// Shared add/edit seat bottom sheet. Owns its controllers so they are
/// disposed exactly when the sheet is disposed (never while fields are
/// still mounted), and scrolls to avoid keyboard overflow.
class _SeatFormSheet extends StatefulWidget {
  final String libraryId;
  final String currencySymbol;
  final String? initialNumber;
  final String? initialCategory;
  final String? initialPrice;
  final bool isEdit;
  final Future<void> Function(String number, String category, double price)
      onSave;

  const _SeatFormSheet({
    required this.libraryId,
    required this.currencySymbol,
    this.initialNumber,
    this.initialCategory,
    this.initialPrice,
    this.isEdit = false,
    required this.onSave,
  });

  @override
  State<_SeatFormSheet> createState() => _SeatFormSheetState();
}

class _SeatFormSheetState extends State<_SeatFormSheet> {
  late final TextEditingController _numberCtrl;
  late final TextEditingController _priceCtrl;
  late String _selectedCategory;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _numberCtrl = TextEditingController(text: widget.initialNumber ?? '');
    _priceCtrl = TextEditingController(text: widget.initialPrice ?? '');
    _selectedCategory = widget.initialCategory ?? 'Normal';
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final number = _numberCtrl.text.trim();
    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a seat number')),
      );
      return;
    }
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.onSave(
        number,
        _selectedCategory,
        double.tryParse(_priceCtrl.text.trim()) ?? 0,
      );
    } on PlanLimitExceededException {
      if (mounted) {
        showUpgradePlanDialog(context);
        setState(() => _isSaving = false);
      }
      return;
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
              'Failed to ${widget.isEdit ? 'update' : 'add'} seat: $e'),
        ),
      );
      if (mounted) setState(() => _isSaving = false);
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.surfaceCardLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(widget.isEdit ? 'Edit Seat' : 'Add New Seat',
                style: AppTypography.headlineMedium),
            const SizedBox(height: 20),
            TextField(
              controller: _numberCtrl,
              style: AppTypography.bodyMedium
                  .copyWith(color: context.textPrimaryColor),
              decoration: InputDecoration(
                labelText: 'Seat Number',
                labelStyle: AppTypography.bodyMedium
                    .copyWith(color: context.textSecondaryColor),
                filled: true,
                fillColor: context.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  dropdownColor: context.cardBg,
                  style: AppTypography.bodyMedium
                      .copyWith(color: context.textPrimaryColor),
                  items: ['Normal', 'AC', 'Premium', 'Cabin']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _selectedCategory = v);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: AppTypography.bodyMedium
                  .copyWith(color: context.textPrimaryColor),
              decoration: InputDecoration(
                labelText: 'Price',
                labelStyle: AppTypography.bodyMedium
                    .copyWith(color: context.textSecondaryColor),
                prefixText: '${widget.currencySymbol} ',
                prefixStyle: AppTypography.bodyMedium
                    .copyWith(color: context.textSecondaryColor),
                filled: true,
                fillColor: context.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            NeonButton(
              text: widget.isEdit ? 'Save Changes' : 'Add Seat',
              icon: widget.isEdit ? Icons.check_rounded : Icons.add_rounded,
              width: double.infinity,
              isLoading: _isSaving,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
