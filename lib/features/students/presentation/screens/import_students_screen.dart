import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/services/import_service.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/plan_upgrade_prompt.dart';
import '../../../subscription/data/services/plan_guard.dart';
import '../../data/models/student_model.dart';
import '../../presentation/providers/student_provider.dart';

class ImportStudentsScreen extends ConsumerStatefulWidget {
  const ImportStudentsScreen({super.key});

  @override
  ConsumerState<ImportStudentsScreen> createState() => _ImportStudentsScreenState();
}

class _ImportStudentsScreenState extends ConsumerState<ImportStudentsScreen> {
  bool _isLoading = false;
  bool _isImporting = false;
  ImportResult? _result;
  List<Map<String, dynamic>>? _previewData;

  Future<void> _pickFile() async {
    setState(() {
      _isLoading = true;
      _result = null;
      _previewData = null;
    });

    final result = await ImportService.instance.pickAndImport();

    if (mounted) {
      setState(() {
        _isLoading = false;
        _result = result;
        if (result.success) {
          _previewData = result.students?.take(5).toList();
        }
      });
    }
  }

  Future<void> _importAll() async {
    if (_result?.students == null) return;
    setState(() => _isImporting = true);
    final repo = ref.read(studentRepositoryProvider);
    final students = _result!.students!;
    int imported = 0;

    for (final s in students) {
      final name = s['name'] ?? '';
      final phone = s['phone'] ?? '';
      if (name.isEmpty || phone.isEmpty) continue;

      final student = StudentModel(
        studentId: const Uuid().v4(),
        name: name,
        phone: phone,
        parentPhone: s['parentPhone'],
        seatNumber: s['seatNumber'],
        feePlan: s['feePlan'] ?? 'Monthly',
        feeAmount: (s['feeAmount'] ?? 0).toDouble(),
        feeStatus: 'pending',
        isActive: true,
        joiningDate: DateTime.now(),
        createdAt: DateTime.now(),
      );
      try {
        await repo.addStudent(student);
        imported++;
      } on PlanLimitExceededException {
        if (mounted) {
          setState(() => _isImporting = false);
          context.showSuccess('Imported $imported students');
          showPlanUpgradePrompt(context);
        }
        return;
      }
    }

    if (mounted) {
      setState(() => _isImporting = false);
      context.showSuccess('Imported $imported students');
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
                    Text('Import Students', style: AppTypography.headlineSmall),
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

                      // Instructions
                      GlassContainer(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text('File Format', style: AppTypography.titleSmall.copyWith(color: AppColors.primary)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Upload a CSV or Excel file with these columns:\n'
                              '• Name (required)\n'
                              '• Phone (required)\n'
                              '• Parent Phone (optional)\n'
                              '• Seat (optional)\n'
                              '• Fee Plan (optional)\n'
                              '• Fee Amount (optional)',
                              style: AppTypography.bodySmall.copyWith(color: context.textSecondaryColor, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Upload area
                      GestureDetector(
                        onTap: _pickFile,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          decoration: BoxDecoration(
                            color: context.cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: context.borderColor.withValues(alpha: 0.3)),
                          ),
                          child: _isLoading
                              ? const LoadingWidget(message: 'Parsing file...')
                              : Column(
                                  children: [
                                    Icon(
                                      _result?.success == true
                                          ? Icons.check_circle_rounded
                                          : _result?.error != null
                                              ? Icons.error_rounded
                                              : Icons.cloud_upload_rounded,
                                      size: 48,
                                      color: _result?.success == true
                                          ? AppColors.accent
                                          : _result?.error != null
                                              ? AppColors.error
                                              : AppColors.primary.withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _result?.success == true
                                          ? 'File parsed successfully'
                                          : _result?.error ?? 'Tap to select CSV or Excel file',
                                      style: AppTypography.labelLarge.copyWith(
                                        color: _result?.success == true ? AppColors.accent : null,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 4),
                                    Text('Supports .csv, .xlsx, .xls', style: AppTypography.labelSmall),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Import stats
                      if (_result?.success == true) ...[
                        Row(
                          children: [
                            _StatChip('Total', '${_result!.totalRows}', AppColors.primary),
                            const SizedBox(width: 8),
                            _StatChip('Valid', '${_result!.imported}', AppColors.accent),
                            const SizedBox(width: 8),
                            _StatChip('Skipped', '${_result!.skipped}', AppColors.warning),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Preview
                        Text('Preview (first 5 rows)', style: AppTypography.titleMedium),
                        const SizedBox(height: 12),
                        if (_previewData != null)
                          ..._previewData!.map((s) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: context.cardBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                  child: Text(
                                    (s['name'] as String? ?? '').isNotEmpty ? (s['name'] as String? ?? '')[0].toUpperCase() : '?',
                                    style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(s['name'] ?? '', style: AppTypography.labelMedium),
                                      Text(s['phone'] ?? '', style: AppTypography.bodySmall),
                                    ],
                                  ),
                                ),
                                if (s['seatNumber'] != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text('Seat ${s['seatNumber']}', style: AppTypography.labelSmall.copyWith(color: AppColors.accent)),
                                  ),
                              ],
                            ),
                          )),
                        const SizedBox(height: 24),
                        NeonButton(
                          text: 'Import ${_result!.imported} Students',
                          onPressed: _importAll,
                          isLoading: _isImporting,
                          width: double.infinity,
                          icon: Icons.download_rounded,
                        ),
                      ],

                      if (_result?.error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.error),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(_result!.error!, style: AppTypography.bodySmall.copyWith(color: AppColors.error)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton.icon(
                            onPressed: _pickFile,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Try Again'),
                          ),
                        ),
                      ],
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
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: AppTypography.titleMedium.copyWith(color: color)),
            Text(label, style: AppTypography.labelSmall),
          ],
        ),
      ),
    );
  }
}
