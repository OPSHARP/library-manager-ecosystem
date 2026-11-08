import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/services/export_service.dart';
import '../../../../core/widgets/pdf_preview_screen.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../students/presentation/providers/student_provider.dart';
import '../../../fees/presentation/providers/fee_provider.dart';
import '../../../staff/presentation/providers/staff_provider.dart';
import '../../../attendance/data/models/attendance_model.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/l10n/app_localizations.dart';

/// Reports Screen
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final monthName = DateFormat('MMMM yyyy').format(now);
    final reports = [
      _ReportItem('Student List', 'Export all students as PDF or Excel', Icons.people_rounded, AppColors.primary, 'students'),
      _ReportItem('Attendance Report', 'Export today\'s attendance', Icons.fact_check_rounded, AppColors.accent, 'attendance'),
      _ReportItem('Fee Collection', 'Export fee summary for $monthName', Icons.receipt_long_rounded, AppColors.warning, 'fees'),
      _ReportItem('Staff Report', 'Export staff list as PDF or Excel', Icons.badge_rounded, AppColors.neonPurple, 'staff'),
    ];

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
                    Text(AppLocalizations.of(context)!.reports, style: AppTypography.headlineSmall),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final r = reports[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(16)),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _showExportOptions(context, ref, r),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 50, height: 50,
                                  decoration: BoxDecoration(color: r.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                                  child: Icon(r.icon, color: r.color, size: 24),
                                ),
                                const SizedBox(width: 14),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(r.title, style: AppTypography.titleSmall),
                                  const SizedBox(height: 4),
                                  Text(r.subtitle, style: AppTypography.bodySmall),
                                ])),
                                Icon(Icons.file_download_rounded, size: 20, color: context.textSecondaryColor),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExportOptions(BuildContext context, WidgetRef ref, _ReportItem report) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Text(report.title, style: AppTypography.titleMedium),
            const SizedBox(height: 6),
            Text('Choose export format', style: AppTypography.bodySmall.copyWith(color: context.textSecondaryColor)),
            const SizedBox(height: 20),
            _ExportFormatTile(
              icon: Icons.picture_as_pdf_rounded,
              iconColor: AppColors.error,
              label: 'Export as PDF',
              onTap: () {
                Navigator.pop(ctx);
                _exportReport(context, ref, report, 'pdf');
              },
            ),
            const SizedBox(height: 10),
            _ExportFormatTile(
              icon: Icons.table_chart_rounded,
              iconColor: AppColors.accent,
              label: 'Export as Excel',
              onTap: () {
                Navigator.pop(ctx);
                _exportReport(context, ref, report, 'excel');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportReport(BuildContext context, WidgetRef ref, _ReportItem report, String format) async {
    final libraryId = ref.read(libraryIdProvider);
    if (libraryId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No library found. Please log in again.'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generating ${report.title}...'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    try {
      final exportService = ExportService.instance;
      final outputDir = await getTemporaryDirectory();
      final libraryName = ref.read(libraryModelProvider).valueOrNull?.libraryName ?? 'Library Manager';

      final ctx = context;
      switch (report.type) {
        case 'students':
          await _exportStudentReport(ref, exportService, outputDir, libraryName, libraryId, format);
          break;
        case 'attendance':
          if (!ctx.mounted) return;
          await _exportAttendanceReport(ctx, ref, exportService, outputDir, libraryName, libraryId, format);
          break;
        case 'fees':
          if (!ctx.mounted) return;
          await _exportFeeReport(ctx, ref, exportService, outputDir, libraryName, libraryId, format);
          break;
        case 'staff':
          await _exportStaffReport(ref, exportService, outputDir, libraryName, libraryId, format);
          break;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _exportStudentReport(
    WidgetRef ref,
    ExportService exportService,
    Directory outputDir,
    String libraryName,
    String libraryId,
    String format,
  ) async {
    final studentList = await ref.read(studentRepositoryProvider).searchStudents('');
    final studentMaps = studentList.map((s) => {
      'name': s.name,
      'phone': s.phone,
      'parentPhone': s.parentPhone ?? '',
      'seat': s.seatNumber ?? '-',
      'feePlan': s.feePlan,
      'feeAmount': s.feeAmount,
      'isActive': s.isActive,
      'joiningDate': s.joiningDate != null ? DateFormat('dd MMM yyyy').format(s.joiningDate!) : '-',
    }).toList();

    if (format == 'excel') {
      final file = await exportService.exportStudentsToExcel(
        students: studentMaps,
        libraryName: libraryName,
        outputDir: outputDir,
      );
      await exportService.shareFile(file, subject: 'Student List Report');
    } else {
      final file = await exportService.exportStudentsToPdf(
        students: studentMaps,
        libraryName: libraryName,
        outputDir: outputDir,
      );
      await exportService.shareFile(file, subject: 'Student List Report');
    }
  }

  Future<void> _exportAttendanceReport(
    BuildContext context,
    WidgetRef ref,
    ExportService exportService,
    Directory outputDir,
    String libraryName,
    String libraryId,
    String format,
  ) async {
    final now = DateTime.now();
    final dateKey = Formatters.firestoreDateKey(now);
    final doc = await ref.read(firestoreServiceProvider).attendanceCol.doc(dateKey).get();
    final attendance = doc.exists
        ? AttendanceModel.fromFirestore(doc)
        : AttendanceModel.empty(dateKey);
    final dateStr = DateFormat('dd MMM yyyy').format(now);

    final records = attendance.records.map((r) => {
      'studentName': r.studentName,
      'checkIn': r.checkIn != null ? DateFormat('hh:mm a').format(r.checkIn!) : '-',
      'checkOut': r.checkOut != null ? DateFormat('hh:mm a').format(r.checkOut!) : '-',
      'status': r.checkIn != null ? 'Present' : 'Absent',
      'method': r.method,
    }).toList();

    if (format == 'excel') {
      final file = await exportService.exportAttendanceToExcel(
        records: records,
        libraryName: libraryName,
        date: dateStr,
        outputDir: outputDir,
      );
      if (context.mounted) {
        await exportService.shareFile(file, subject: 'Attendance Report');
      }
    } else {
      final bytes = await exportService.getAttendanceBytes(
        records: records,
        libraryName: libraryName,
        date: dateStr,
      );
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(pdfBytes: bytes, title: 'Attendance Report'),
          ),
        );
      }
    }
  }

  Future<void> _exportFeeReport(
    BuildContext context,
    WidgetRef ref,
    ExportService exportService,
    Directory outputDir,
    String libraryName,
    String libraryId,
    String format,
  ) async {
    final currencySymbol = ref.read(settingsProvider).currencySymbol;
    final fees = await ref.read(feeRepositoryProvider).getFees().first;
    final monthName = DateFormat('MMMM yyyy').format(DateTime.now());

    final feeMaps = fees.map((f) => {
      'studentName': f.studentName,
      'amount': f.amount,
      'status': f.status,
      'dueDate': f.dueDate != null ? DateFormat('dd MMM yyyy').format(f.dueDate!) : '-',
      'paymentMethod': f.paymentMethod ?? '-',
    }).toList();

    if (format == 'excel') {
      final file = await exportService.exportFeesToExcel(
        fees: feeMaps,
        libraryName: libraryName,
        month: monthName,
        outputDir: outputDir,
        currencySymbol: currencySymbol,
      );
      if (context.mounted) {
        await exportService.shareFile(file, subject: 'Fee Report');
      }
    } else {
      final bytes = await exportService.getFeeReportBytes(
        fees: feeMaps,
        libraryName: libraryName,
        month: monthName,
        currencySymbol: currencySymbol,
      );
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(pdfBytes: bytes, title: 'Fee Report'),
          ),
        );
      }
    }
  }

  Future<void> _exportStaffReport(
    WidgetRef ref,
    ExportService exportService,
    Directory outputDir,
    String libraryName,
    String libraryId,
    String format,
  ) async {
    final staff = await ref.read(staffRepositoryProvider).getStaff().first;

    final staffMaps = staff.map((s) => {
      'name': s.name,
      'email': s.email,
      'phone': s.phone,
      'role': s.roleDisplayName,
      'isActive': s.isActive,
    }).toList();

    if (format == 'excel') {
      final excel = Excel.createExcel();
      final sheet = excel['Staff'];
      sheet.appendRow([
        TextCellValue('#'), TextCellValue('Name'), TextCellValue('Email'),
        TextCellValue('Phone'), TextCellValue('Role'), TextCellValue('Status'),
      ]);
      for (var i = 0; i < staffMaps.length; i++) {
        final s = staffMaps[i];
        sheet.appendRow([
          TextCellValue('${i + 1}'),
          TextCellValue('${s['name'] ?? ''}'),
          TextCellValue('${s['email'] ?? ''}'),
          TextCellValue('${s['phone'] ?? ''}'),
          TextCellValue('${s['role'] ?? '-'}'),
          TextCellValue(s['isActive'] == true ? 'Active' : 'Inactive'),
        ]);
      }
      final file = File('${outputDir.path}/staff_report.xlsx');
      final bytes = excel.encode();
      if (bytes != null) await file.writeAsBytes(bytes);
      await exportService.shareFile(file, subject: 'Staff Report');
    } else {
      final file = await exportService.exportStaffToPdf(
        staff: staffMaps,
        libraryName: libraryName,
        outputDir: outputDir,
      );
      await exportService.shareFile(file, subject: 'Staff Report');
    }
  }
}

class _ReportItem {
  final String title, subtitle, type;
  final IconData icon;
  final Color color;
  const _ReportItem(this.title, this.subtitle, this.icon, this.color, this.type);
}

class _ExportFormatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _ExportFormatTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.cardBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Text(label, style: AppTypography.titleSmall),
              const Spacer(),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: context.textSecondaryColor),
            ],
          ),
        ),
      ),
    );
  }
}
