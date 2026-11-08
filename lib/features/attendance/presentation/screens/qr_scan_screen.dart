import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../../../core/utils/formatters.dart';
import '../../../subscription/data/services/plan_guard.dart';
import '../../../students/presentation/providers/student_provider.dart';
import '../../../students/data/models/student_model.dart';
import '../../data/models/attendance_model.dart';
import '../providers/attendance_provider.dart';

/// QR Scan Screen - Camera-based QR code scanner for attendance
class QRScanScreen extends ConsumerStatefulWidget {
  const QRScanScreen({super.key});

  @override
  ConsumerState<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends ConsumerState<QRScanScreen> {
  bool? _scanResult; // null = not scanned, true = success, false = failed
  String? _message;
  bool _isProcessing = false;

  Future<void> _processStudent(StudentModel student) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });

    final now = DateTime.now();
    final selectedDate = ref.read(selectedDateProvider);
    final dateKey = Formatters.firestoreDateKey(selectedDate);
    final record = AttendanceRecord(
      studentId: student.studentId,
      studentName: student.name,
      checkIn: now,
      method: 'qr',
      isLate: false,
    );

    try {
      await ref
          .read(attendanceRepositoryProvider)
          .markAttendance(dateKey: dateKey, record: record);
      
      if (mounted) {
        setState(() {
          _scanResult = true;
          _message = 'Checked in ${student.name}';
          _isProcessing = false;
        });
      }
    } on PlanLimitExceededException {
      if (mounted) {
        setState(() {
          _scanResult = false;
          _message = 'Free plan limit reached';
          _isProcessing = false;
        });
        // We let them know, maybe don't pop the dialog here, or maybe we pop?
        // Usually we show the upgrade dialog.
        // For simplicity, we just mark as failed. 
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _scanResult = false;
          _message = 'Failed to mark attendance';
          _isProcessing = false;
        });
      }
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanResult != null || _isProcessing) return;
    
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    
    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    final students = ref.read(studentsProvider).valueOrNull ?? [];
    
    // Look up student by their unique ID
    final student = students.where((s) => s.uniqueId == rawValue).firstOrNull;
    
    if (student != null) {
      _processStudent(student);
    } else {
      setState(() {
        _scanResult = false;
        _message = 'Student not found';
      });
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
                    Text('QR Scanner', style: AppTypography.headlineSmall),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Camera preview
                      Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          color: context.cardBg,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _scanResult == null
                                ? AppColors.primary
                                : _scanResult == true
                                    ? AppColors.accent
                                    : AppColors.error,
                            width: 3,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _scanResult == null
                            ? MobileScanner(
                                onDetect: _onDetect,
                              )
                            : _scanResult == true
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 80, height: 80,
                                        decoration: BoxDecoration(
                                          color: AppColors.accent.withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.check_rounded, size: 48, color: AppColors.accent),
                                      ),
                                      const SizedBox(height: 12),
                                      Text('Attendance Marked!', style: AppTypography.titleMedium.copyWith(color: AppColors.accent)),
                                    ],
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 80, height: 80,
                                        decoration: BoxDecoration(
                                          color: AppColors.error.withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close_rounded, size: 48, color: AppColors.error),
                                      ),
                                      const SizedBox(height: 12),
                                      Text('Invalid QR Code', style: AppTypography.titleMedium.copyWith(color: AppColors.error)),
                                    ],
                                  ),
                      ),
                      const SizedBox(height: 32),

                      if (_scanResult != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Column(
                            children: [
                              Text(
                                _message ?? (_scanResult == true ? 'Student checked in successfully' : 'This QR code is not recognized'),
                                style: AppTypography.bodyMedium.copyWith(color: context.textSecondaryColor),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              NeonButton(
                                text: 'Scan Again',
                                onPressed: () => setState(() {
                                  _scanResult = null;
                                  _message = null;
                                }),
                                width: double.infinity,
                                icon: Icons.qr_code_scanner_rounded,
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Text('Scanning...', style: AppTypography.bodyMedium.copyWith(color: context.textSecondaryColor)),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 40, height: 40,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Manual fallback
              Padding(
                padding: const EdgeInsets.all(20),
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Show manual student selection
                    _showManualEntry(context);
                  },
                  icon: const Icon(Icons.keyboard_rounded),
                  label: const Text('Manual Entry'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showManualEntry(BuildContext context) {
    final studentsAsync = ref.read(studentsStreamProvider);
    final students = studentsAsync.valueOrNull ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: context.surfaceCardLight, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text('Select Student', style: AppTypography.headlineSmall),
              const SizedBox(height: 16),
              Expanded(
                child: students.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline_rounded, size: 48, color: context.textSecondaryColor),
                            const SizedBox(height: 12),
                            Text('No students found', style: AppTypography.bodyMedium.copyWith(color: context.textSecondaryColor)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: students.length,
                        itemBuilder: (context, index) {
                          final student = students[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                              child: Text(student.name.isNotEmpty ? student.name[0].toUpperCase() : '?', style: TextStyle(color: AppColors.primary)),
                            ),
                            title: Text(student.name, style: AppTypography.labelLarge),
                            subtitle: Text(student.seatNumber ?? 'No seat', style: AppTypography.bodySmall),
                            onTap: () {
                              Navigator.pop(context);
                              _processStudent(student);
                            },
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
}
