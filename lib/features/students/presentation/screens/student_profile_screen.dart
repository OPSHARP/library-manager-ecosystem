import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/services/export_service.dart';
import '../../../../core/widgets/pdf_preview_screen.dart';
import '../../../students/data/models/student_model.dart';
import '../../../students/presentation/providers/student_provider.dart';
import '../../../fees/presentation/providers/fee_provider.dart';
import '../../../books/presentation/providers/book_provider.dart';
import '../../../seats/data/repositories/seat_repository.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../attendance/data/repositories/attendance_repository.dart';
import '../../../attendance/presentation/providers/attendance_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Student Profile Screen
/// Detailed profile with tabs for attendance, fees, books + report download
class StudentProfileScreen extends ConsumerStatefulWidget {
  final String studentId;
  const StudentProfileScreen({super.key, required this.studentId});

  @override
  ConsumerState<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends ConsumerState<StudentProfileScreen> {
  static const _statusOptions = ['enrolled', 'active', 'suspended', 'graduated', 'alumni'];

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

  Future<void> _updateStudentStatus(StudentModel student, String newStatus) async {
    final repo = ref.read(studentRepositoryProvider);
    await repo.updateStudent(student.copyWith(status: newStatus));
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider);

    return studentsAsync.when(
      data: (students) {
        final student = students.where((s) => s.studentId == widget.studentId).firstOrNull;
        if (student == null) {
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
                          Text('Student Profile', style: AppTypography.headlineSmall),
                        ],
                      ),
                    ),
                    const Expanded(
                      child: Center(child: Text('Student not found')),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            body: Container(
              color: context.scaffoldBg,
              child: SafeArea(
                child: Column(
                  children: [
                    // App bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Row(
                        children: [
                          IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
                          const SizedBox(width: 8),
                          Text('Student Profile', style: AppTypography.headlineSmall),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf_rounded),
                            color: AppColors.error,
                            onPressed: () => _downloadReport(context, ref, student),
                          ),
                          IconButton(
                            icon: const Icon(Icons.notifications_active_rounded),
                            color: AppColors.accent,
                            tooltip: 'Send Update',
                            onPressed: () => context.push(
                              AppRoutes.sendNotification,
                              extra: [student.studentId],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            color: AppColors.primary,
                            onPressed: () => context.push('/students/${student.studentId}/edit'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded),
                            color: AppColors.error,
                            onPressed: () => _deleteStudent(context, ref, student),
                          ),
                        ],
                      ),
                    ),

                    // Profile header with status dropdown
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: GlassContainer(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 68, height: 68,
                                  decoration: BoxDecoration(
                                    gradient: AppGradients.neonPurpleBlue,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _initials(student.name),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 22),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(student.name, style: AppTypography.headlineSmall),
                                      const SizedBox(height: 4),
                                      Row(children: [
                                        Icon(Icons.chair_rounded, size: 14, color: context.textTertiaryColor),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(student.seatNumber ?? 'No seat', style: AppTypography.bodySmall, overflow: TextOverflow.ellipsis),
                                        ),
                                        const SizedBox(width: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: _feeStatusColor(student.feeStatus).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text('FEE: ${student.feeStatus.toUpperCase()}', style: AppTypography.badge.copyWith(color: _feeStatusColor(student.feeStatus))),
                                        ),
                                      ]),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Joined: ${student.joiningDate?.toString().split(' ').first ?? 'N/A'}",
                                        style: AppTypography.labelSmall,
                                      ),
                                      if (student.leaveDate != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          "Left: ${student.leaveDate!.toString().split(' ').first}",
                                          style: AppTypography.labelSmall.copyWith(color: AppColors.error),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            // Status dropdown row
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: _lifecycleStatusColor(student.status).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _lifecycleStatusColor(student.status).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.circle, size: 10, color: _lifecycleStatusColor(student.status)),
                                  const SizedBox(width: 8),
                                  Text('Status:', style: AppTypography.labelMedium.copyWith(color: context.textSecondaryColor)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: student.status,
                                        isDense: true,
                                        dropdownColor: context.surfaceColor,
                                        style: AppTypography.labelLarge.copyWith(color: _lifecycleStatusColor(student.status)),
                                        icon: Icon(Icons.arrow_drop_down_rounded, color: _lifecycleStatusColor(student.status)),
                                        items: _statusOptions.map((s) => DropdownMenuItem(
                                          value: s,
                                          child: Text(s[0].toUpperCase() + s.substring(1)),
                                        )).toList(),
                                        onChanged: (val) {
                                          if (val != null) _updateStudentStatus(student, val);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick info row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          _InfoChip(icon: Icons.phone_rounded, label: student.phone, color: AppColors.secondary),
                          const SizedBox(width: 10),
                          _InfoChip(icon: Icons.attach_money_rounded, label: '${ref.watch(settingsProvider).currencySymbol}${student.feeAmount.toInt()}/${student.feePlan}', color: AppColors.accent),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Attendance stats section
                    _AttendanceStatsSection(studentId: widget.studentId, joiningDate: student.joiningDate),
                    const SizedBox(height: 12),

                    // Tab bar
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        indicator: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelColor: Colors.white,
                        unselectedLabelColor: context.textTertiaryColor,
                        dividerHeight: 0,
                        tabs: const [
                          Tab(text: 'Books'),
                          Tab(text: 'Fees'),
                          Tab(text: 'Details'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tab content
                    Expanded(
                      child: TabBarView(
                        children: [
                          _BooksTab(studentId: widget.studentId),
                          _FeesTab(studentId: widget.studentId),
                          _DetailsTab(student: student),
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
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }

  String _initials(String name) {
    final parts = name.split(' ').where((w) => w.isNotEmpty).toList();
    if (parts.isEmpty) return 'ST';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Color _feeStatusColor(String status) {
    switch (status) {
      case 'paid': return AppColors.feePaid;
      case 'overdue': return AppColors.feeOverdue;
      default: return AppColors.feePending;
    }
  }

  Future<void> _deleteStudent(BuildContext context, WidgetRef ref, StudentModel student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Student', style: TextStyle(color: Colors.white)),
        content: Text(
          'This will permanently delete ${student.name} and all associated data:\n'
          '• Seats assigned\n• Attendance records\n• Fee records\n• Issued books',
          style: AppTypography.bodyMedium.copyWith(color: context.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      // All five cleanups touch INDEPENDENT collections (seat, fees,
      // attendance, books, student doc) — run them in parallel so the delete
      // completes in ~1 network round-trip instead of 5 sequential ones.
      final seatRepo = SeatRepository(ref.read(firestoreServiceProvider));
      final attendanceRepo = AttendanceRepository(
        ref.read(firestoreServiceProvider),
      );
      await Future.wait([
        student.seatId != null && student.seatId!.isNotEmpty
            ? seatRepo.releaseSeat(student.seatId!)
            : Future<void>.value(),
        ref.read(feeRepositoryProvider).deleteFeesForStudent(student.studentId),
        attendanceRepo.removeStudentRecords(student.studentId),
        ref.read(bookRepositoryProvider).returnBooksForStudent(student.studentId),
        ref.read(studentRepositoryProvider).deleteStudent(student.studentId),
      ]);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${student.name} deleted successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete student: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _downloadReport(BuildContext context, WidgetRef ref, StudentModel student) async {
    // Gather data from streams (one-shot)
    final booksRepo = ref.read(bookRepositoryProvider);
    final booksList = await booksRepo.getBooks().first;
    final studentBooks = booksList.where((b) => b.studentId == widget.studentId || b.studentName == student.name).toList();

    final feesRepo = ref.read(feeRepositoryProvider);
    final feesList = await feesRepo.getStudentFees(widget.studentId).first;

    final booksData = studentBooks.map((b) => {
      'title': b.title,
      'author': b.author,
      'issueDate': b.issueDate?.toString().split(' ').first ?? '-',
      'status': b.status,
    }).toList();

    final feesData = feesList.map((f) => {
      'month': f.month,
      'amount': f.amount,
      'status': f.status,
      'dueDate': f.dueDate?.toString().split(' ').first ?? '-',
    }).toList();

    final studentData = {
      'name': student.name,
      'phone': student.phone,
      'seatNumber': student.seatNumber ?? 'Not assigned',
      'feePlan': student.feePlan,
      'feeAmount': student.feeAmount,
      'isActive': student.isActive,
      'joiningDate': student.joiningDate ?? '-',
    };

    try {
      final currencySymbol = ref.read(settingsProvider).currencySymbol;
      final bytes = await ExportService.instance.getStudentReportBytes(
        student: studentData,
        books: booksData,
        fees: feesData,
        libraryName: ref.read(libraryModelProvider).valueOrNull?.libraryName ?? 'Library Manager',
        currencySymbol: currencySymbol,
      );
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(pdfBytes: bytes, title: '${student.name} Report'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate report: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(child: Text(label, style: AppTypography.labelMedium.copyWith(color: color), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

class _BooksTab extends ConsumerWidget {
  final String studentId;
  const _BooksTab({required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksRepo = ref.watch(bookRepositoryProvider);
    return StreamBuilder(
      stream: booksRepo.getBooks(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final allBooks = snapshot.data!;
        final books = allBooks.where((b) => b.studentId == studentId).toList();

        if (books.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.menu_book_rounded, size: 48, color: context.textTertiaryColor),
                const SizedBox(height: 8),
                Text('No books issued', style: AppTypography.bodyMedium.copyWith(color: context.textTertiaryColor)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: books.length,
          itemBuilder: (context, index) {
            final book = books[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.menu_book_rounded, size: 20, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(book.title, style: AppTypography.labelLarge),
                      if (book.author.isNotEmpty) Text(book.author, style: AppTypography.bodySmall),
                    ]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(book.status.toUpperCase(), style: AppTypography.labelSmall.copyWith(color: AppColors.accent, fontSize: 10)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _FeesTab extends ConsumerWidget {
  final String studentId;
  const _FeesTab({required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feesRepo = ref.watch(feeRepositoryProvider);
    return StreamBuilder(
      stream: feesRepo.getStudentFees(studentId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final fees = snapshot.data!;

        if (fees.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_rounded, size: 48, color: context.textTertiaryColor),
                const SizedBox(height: 8),
                Text('No fee records', style: AppTypography.bodyMedium.copyWith(color: context.textTertiaryColor)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: fees.length,
          itemBuilder: (context, index) {
            final fee = fees[index];
            final statusColor = fee.status == 'paid' ? AppColors.feePaid : fee.status == 'overdue' ? AppColors.feeOverdue : AppColors.feePending;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.receipt_rounded, size: 20, color: statusColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(fee.month, style: AppTypography.labelLarge),
                      Text('${ref.watch(settingsProvider).currencySymbol}${fee.amount.toInt()}', style: AppTypography.bodySmall),
                    ]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(fee.status.toUpperCase(), style: AppTypography.badge.copyWith(color: statusColor)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _DetailsTab extends ConsumerWidget {
  final StudentModel student;
  const _DetailsTab({required this.student});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _DetailRow(icon: Icons.person_rounded, label: 'Full Name', value: student.name),
          _DetailRow(icon: Icons.qr_code_2_rounded, label: 'Student ID', value: student.uniqueId.isEmpty ? 'Not set' : student.uniqueId),
          _DetailRow(icon: Icons.phone_rounded, label: 'Phone', value: student.phone),
          if (student.parentPhone != null)
            _DetailRow(icon: Icons.people_rounded, label: 'Parent Phone', value: student.parentPhone!),
          if (student.address != null)
            _DetailRow(icon: Icons.place_rounded, label: 'Address', value: student.address!),
          _DetailRow(icon: Icons.chair_rounded, label: 'Seat', value: student.seatNumber ?? 'Not assigned'),
          _DetailRow(icon: Icons.calendar_today_rounded, label: 'Joining Date', value: student.joiningDate?.toString().split(' ').first ?? 'N/A'),
          _DetailRow(icon: Icons.event_busy_rounded, label: 'Leave Date', value: student.leaveDate?.toString().split(' ').first ?? 'Still joined'),
          _DetailRow(icon: Icons.attach_money_rounded, label: 'Fee Plan', value: '${student.feePlan} - ${ref.watch(settingsProvider).currencySymbol}${student.feeAmount.toInt()}'),
          _DetailRow(icon: Icons.toggle_on_rounded, label: 'Active', value: student.isActive ? 'Yes' : 'No'),
          _DetailRow(icon: Icons.flag_rounded, label: 'Lifecycle Status', value: student.status[0].toUpperCase() + student.status.substring(1)),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(12)),
              child: Row(
        children: [
          Icon(icon, size: 20, color: context.textTertiaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: AppTypography.labelSmall),
              const SizedBox(height: 2),
              Text(value, style: AppTypography.bodyMedium, overflow: TextOverflow.ellipsis, maxLines: 2),
            ]),
          ),
        ],
      ),
    );
  }
}

/// Attendance statistics section for the student profile.
/// Shows attendance percentage, streak, and a 30-day mini calendar.
class _AttendanceStatsSection extends ConsumerWidget {
  final String studentId;
  final DateTime? joiningDate;
  const _AttendanceStatsSection({required this.studentId, required this.joiningDate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (joiningDate == null) return const SizedBox.shrink();

    // Use the cached provider to avoid N+1 sequential reads on every rebuild.
    final statsAsync = ref.watch(
      studentAttendanceStatsProvider((studentId: studentId, joiningDate: joiningDate)),
    );

    return statsAsync.when(
      data: (stats) {
        if (stats.isEmpty) return const SizedBox.shrink();
        final percentage = stats['percentage'] as double;
        final streak = stats['streak'] as int;
        final presentDays = stats['presentDays'] as int;
        final totalDays = stats['totalDays'] as int;
        final last30 = stats['last30'] as List<bool>;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.borderColor.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Attendance Statistics', style: AppTypography.labelLarge),
                const SizedBox(height: 10),
                // Stats row
                Row(
                  children: [
                    _AttendanceStatBox(
                      label: 'Present',
                      value: '$presentDays/$totalDays',
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 8),
                    _AttendanceStatBox(
                      label: 'Rate',
                      value: '${percentage.toStringAsFixed(0)}%',
                      color: AppColors.neonPurple,
                    ),
                    const SizedBox(width: 8),
                    _AttendanceStatBox(
                      label: 'Streak',
                      value: '$streak days',
                      color: AppColors.neonBlue,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 30-day mini calendar
                Text('Last 30 Days', style: AppTypography.bodySmall),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 3,
                  runSpacing: 3,
                  children: List.generate(30, (i) {
                    final present = i < last30.length && last30[i];
                    return Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: present
                            ? AppColors.accent.withValues(alpha: 0.8)
                            : context.surfaceCardLight.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => const SizedBox.shrink(),
    );
  }
}

class _AttendanceStatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _AttendanceStatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value, style: AppTypography.titleMedium.copyWith(color: color, fontSize: 14)),
            const SizedBox(height: 2),
            Text(label, style: AppTypography.labelSmall.copyWith(color: color, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
