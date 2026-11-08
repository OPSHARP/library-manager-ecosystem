import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/loading_widget.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/utils/extensions.dart';
import '../dashboard/presentation/providers/dashboard_provider.dart';
import '../dashboard/data/models/attendance_model.dart';
import '../auth/presentation/providers/auth_provider.dart';

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final params = (ownerUid: auth.ownerUid ?? '', studentId: auth.studentUniqueId ?? '');
    final dashboard = ref.watch(dashboardProvider(params));

    return CupertinoPageScaffold(
      backgroundColor: AppColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.floatingBar,
        middle: const Text('Attendance'),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: dashboard.isLoading
                  ? const LoadingWidget()
                  : dashboard.attendance.isEmpty
                      ? const EmptyState(
                          icon: CupertinoIcons.calendar,
                          title: 'No Attendance Records',
                        )
                      : _buildContent(dashboard, dashboard.attendance),
            ),
                      ],
        ),
      ),
    );
  }

  Widget _buildContent(
      DashboardState state, List<AttendanceModel> attendance) {
    final rate = state.totalAttendanceDays > 0
        ? (state.presentDays / state.totalAttendanceDays * 100).toStringAsFixed(1)
        : '0.0';

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: _bigStat('Present', '${state.presentDays}', AppColors.success),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _bigStat('Missed', '${state.missedDays}', AppColors.error),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _bigStat('Rate', '$rate%', AppColors.systemBlue),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Attendance Log',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.label,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 8),
        ...attendance.reversed.take(60).map((day) =>
            _buildDayRecord(day, state.student?.studentId ?? '')),
      ],
    );
  }

  Widget _bigStat(String label, String value, Color color) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.secondaryLabel,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayRecord(AttendanceModel day, String studentId) {
    final record = day.records.where((r) => r.studentId == studentId).firstOrNull;
    final isPresent = record != null;

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isPresent ? AppColors.successBg : AppColors.errorBg,
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Icon(
              isPresent
                  ? CupertinoIcons.checkmark_alt_circle_fill
                  : CupertinoIcons.clear_fill,
              color: isPresent ? AppColors.success : AppColors.error,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              day.date,
              style: const TextStyle(
                color: AppColors.label,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (isPresent) ...[
            if (record.checkIn != null)
              Text(
                'In: ${record.checkIn!.formatTime()}',
                style: const TextStyle(
                  color: AppColors.secondaryLabel,
                  fontSize: 12,
                ),
              ),
            const SizedBox(width: 8),
            if (record.checkOut != null)
              Text(
                'Out: ${record.checkOut!.formatTime()}',
                style: const TextStyle(
                  color: AppColors.secondaryLabel,
                  fontSize: 12,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
