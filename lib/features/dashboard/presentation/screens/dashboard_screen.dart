import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/stat_card.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/widgets/email_verification_banner.dart';
import '../../../../app/router.dart';
import '../providers/dashboard_provider.dart';
import '../../../students/presentation/providers/join_requests_provider.dart';

import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../fees/presentation/providers/fee_provider.dart';
import '../../../seats/presentation/providers/seat_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../data/models/dashboard_stats_model.dart';
import '../../../../core/l10n/app_localizations.dart';

/// Dashboard Screen
/// Real-time owner dashboard with stats, charts, and quick actions
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static const String _tutorialShownKey = 'owner_tutorial_shown_v1';

  /// One-shot guard so the first-launch tutorial only shows once per run.
  static bool _tutorialPrompted = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    // First-launch tutorial: guide the owner to publish their library
    // location and complete their library details.
    if (!_tutorialPrompted) {
      _tutorialPrompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        _maybeShowTutorial(context, ref);
      });
    }

    return Scaffold(
      body: Container(
        color: context.scaffoldBg,
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Header
              SliverToBoxAdapter(child: _buildHeader(context, ref)),
              // Email Verification (if unverified)
              const SliverToBoxAdapter(child: EmailVerificationBanner()),
              // Stats Grid
              SliverToBoxAdapter(child: statsAsync.when(
                data: (stats) => _buildStatsGridWithData(context, ref, stats),
                loading: () => const Padding(
                  padding: EdgeInsets.all(40),
                  child: LoadingWidget(message: 'Loading dashboard...'),
                ),
                error: (e, _) => _buildStatsGrid(context, ref),
              )),
              // Fee Alerts
              SliverToBoxAdapter(child: _buildFeeAlerts(context, ref)),
              // Revenue Chart
              SliverToBoxAdapter(child: _buildRevenueChart(context, ref, statsAsync.valueOrNull)),
              // Attendance Chart
              SliverToBoxAdapter(child: _buildAttendanceChart(context, statsAsync.valueOrNull)),
              // Occupancy Heatmap
              SliverToBoxAdapter(child: _buildOccupancyHeatmap(context, ref)),
              // Top Students
              SliverToBoxAdapter(child: _buildTopStudents(context, ref)),
              // Quick Actions
              SliverToBoxAdapter(child: _buildQuickActions(context, ref)),
              // Expiring Memberships
              SliverToBoxAdapter(child: _buildExpiringAlerts(context, ref)),
              // Recent Activity
              SliverToBoxAdapter(child: _buildRecentActivity(context, ref)),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _maybeShowTutorial(BuildContext context, WidgetRef ref) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_tutorialShownKey) ?? false) return;
      await prefs.setBool(_tutorialShownKey, true);
      if (!context.mounted) return;
      await _showTutorialDialog(context, ref);
    } catch (_) {}
  }

  Future<void> _showTutorialDialog(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.rocket_launch_rounded, color: AppColors.primary, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Welcome to Library Manager', style: AppTypography.titleMedium),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Let\'s get your library ready for students. Complete these two quick steps:',
              style: AppTypography.bodyMedium.copyWith(color: context.textSecondaryColor),
            ),
            const SizedBox(height: 16),
            _tutorialAction(
              ctx,
              number: '1',
              icon: Icons.share_location_rounded,
              color: AppColors.primary,
              title: 'Set / Show Your Library Location',
              subtitle: 'Please click here to set or show your library location to all users',
              onTap: () => Navigator.pop(ctx, 'location'),
            ),
            const SizedBox(height: 12),
            _tutorialAction(
              ctx,
              number: '2',
              icon: Icons.settings_rounded,
              color: AppColors.secondary,
              title: 'Setup Your Library Details',
              subtitle: 'Please setup your library details in Settings',
              onTap: () => Navigator.pop(ctx, 'settings'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Later', style: TextStyle(color: context.textTertiaryColor)),
          ),
        ],
      ),
    );

    if (!context.mounted || choice == null) return;
    switch (choice) {
      case 'location':
        context.push(AppRoutes.libraryLocation);
        break;
      case 'settings':
        context.push(AppRoutes.settings);
        break;
    }
  }

  Widget _tutorialAction(
    BuildContext ctx, {
    required String number,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: ctx.cardBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$number. $title', style: AppTypography.labelLarge),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTypography.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: ctx.textTertiaryColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final greeting = _getGreeting(context);
    final libraryAsync = ref.watch(libraryModelProvider);
    final libraryName = libraryAsync.valueOrNull?.libraryName ?? 'Library Manager';
    final initials = libraryName.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          // Profile avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: AppGradients.primaryGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(initials.isEmpty ? 'LM' : initials, style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14,
              )),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: AppTypography.bodySmall.copyWith(color: context.textSecondaryColor),
                ),
                Text(libraryName, style: AppTypography.titleMedium, overflow: TextOverflow.ellipsis, maxLines: 1),
              ],
            ),
          ),
          // Action buttons
          _headerIcon(context, Icons.analytics_rounded, () => context.push(AppRoutes.analytics)),
          const SizedBox(width: 4),
          _headerIcon(context, Icons.settings_rounded, () => context.push(AppRoutes.settings)),
          const SizedBox(width: 4),
          _headerIcon(context, Icons.share_location_rounded, () => context.push(AppRoutes.libraryLocation)),
          const SizedBox(width: 4),
          Stack(
            clipBehavior: Clip.none,
            children: [
              _headerIcon(context, Icons.notifications_rounded, () => context.push(AppRoutes.notifications)),
              Positioned(
                right: -2, top: -2,
                child: Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.surfaceColor, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerIcon(BuildContext context, IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: context.textPrimaryColor),
      ),
    );
  }

  String _getGreeting(BuildContext context) {
    final hour = DateTime.now().hour;
    if (hour < 12) return AppLocalizations.of(context)!.goodMorning;
    if (hour < 17) return AppLocalizations.of(context)!.goodAfternoon;
    return AppLocalizations.of(context)!.goodEvening;
  }

  Widget _buildStatsGridWithData(BuildContext context, WidgetRef ref, DashboardStatsModel stats) {
    final currencySymbol = ref.watch(settingsProvider).currencySymbol;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.6,
            children: [
              StatCard(
                value: '${stats.totalStudents}',
                label: AppLocalizations.of(context)!.totalStudents,
                icon: Icons.people_rounded,
                gradient: AppGradients.statStudents,
                trend: '${stats.activeStudents} active',
                isTrendPositive: true,
              ),
              StatCard(
                value: '${stats.occupiedSeats}/${stats.totalSeats}',
                label: 'Seats Occupied',
                icon: Icons.chair_rounded,
                gradient: AppGradients.statSeats,
                trend: '${stats.occupancyRate.toStringAsFixed(0)}%',
              ),
              StatCard(
                value: '${stats.todayPresent}',
                label: AppLocalizations.of(context)!.todayAttendance,
                icon: Icons.fact_check_rounded,
                gradient: AppGradients.statAttendance,
                trend: '${stats.attendanceRate.toStringAsFixed(0)}%',
              ),
              StatCard(
                value: '$currencySymbol${_formatAmount(stats.monthlyRevenue)}',
                label: AppLocalizations.of(context)!.monthlyRevenue,
                icon: Icons.account_balance_wallet_rounded,
                gradient: AppGradients.statRevenue,
                trend: '$currencySymbol${_formatAmount(stats.collectedFees)} ${AppLocalizations.of(context)!.collected}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Net Profit & Expense Banner Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.borderColor.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (stats.netProfit >= 0 ? AppColors.success : AppColors.error).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    stats.netProfit >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    color: stats.netProfit >= 0 ? AppColors.success : AppColors.error,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Net Profit (Revenue - Expenses)',
                        style: AppTypography.bodySmall.copyWith(color: context.textSecondaryColor, fontSize: 11),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '$currencySymbol${stats.netProfit.toStringAsFixed(0)}',
                            style: AppTypography.titleLarge.copyWith(
                              fontWeight: FontWeight.w800,
                              color: stats.netProfit >= 0 ? AppColors.success : AppColors.error,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Exp: $currencySymbol${stats.monthlyExpenses.toStringAsFixed(0)}',
                            style: AppTypography.bodySmall.copyWith(color: context.textTertiaryColor, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.push(AppRoutes.expenses),
                  icon: const Icon(Icons.receipt_long_rounded, size: 16),
                  label: const Text('Expenses'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }

  Widget _buildStatsGrid(BuildContext context, WidgetRef ref) {
    final currencySymbol = ref.watch(settingsProvider).currencySymbol;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.6,
        children: [
          StatCard(
            value: '0',
            label: AppLocalizations.of(context)!.totalStudents,
            icon: Icons.people_rounded,
            gradient: AppGradients.statStudents,
            trend: '0 active',
            isTrendPositive: true,
          ),
          StatCard(
            value: '0/0',
            label: 'Seats Occupied',
            icon: Icons.chair_rounded,
            gradient: AppGradients.statSeats,
            trend: '0%',
          ),
          StatCard(
            value: '0',
            label: AppLocalizations.of(context)!.todayAttendance,
            icon: Icons.fact_check_rounded,
            gradient: AppGradients.statAttendance,
            trend: '0%',
          ),
          StatCard(
            value: '$currencySymbol 0',
            label: AppLocalizations.of(context)!.monthlyRevenue,
            icon: Icons.account_balance_wallet_rounded,
            gradient: AppGradients.statRevenue,
            trend: '$currencySymbol 0 ${AppLocalizations.of(context)!.collected}',
          ),
        ],
      ),
    );
  }

  Widget _buildFeeAlerts(BuildContext context, WidgetRef ref) {
    final feesAsync = ref.watch(feesStreamProvider);
    final currencySymbol = ref.watch(settingsProvider).currencySymbol;

    return feesAsync.when(
      data: (fees) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final nextWeek = today.add(const Duration(days: 7));

        // Overdue fees: not paid and due date is before today
        final overdueFees = fees.where((f) {
          if (f.status == 'paid') return false;
          if (f.dueDate == null) return false;
          final dueDay = DateTime(f.dueDate!.year, f.dueDate!.month, f.dueDate!.day);
          return dueDay.isBefore(today);
        }).toList();

        // Upcoming dues: not paid and due date within next 7 days
        final upcomingDues = fees.where((f) {
          if (f.status == 'paid') return false;
          if (f.dueDate == null) return false;
          final dueDay = DateTime(f.dueDate!.year, f.dueDate!.month, f.dueDate!.day);
          return !dueDay.isBefore(today) && dueDay.isBefore(nextWeek);
        }).toList();

        if (overdueFees.isEmpty && upcomingDues.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: GlassContainer(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 22),
                    const SizedBox(width: 8),
                    Text('Fee Alerts', style: AppTypography.titleMedium),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _alertChip(
                      label: 'Overdue',
                      count: overdueFees.length,
                      color: AppColors.error,
                      icon: Icons.error_outline_rounded,
                    ),
                    const SizedBox(width: 12),
                    _alertChip(
                      label: 'Upcoming (7d)',
                      count: upcomingDues.length,
                      color: AppColors.warning,
                      icon: Icons.schedule_rounded,
                    ),
                  ],
                ),
                if (overdueFees.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Overdue Students', style: AppTypography.titleSmall.copyWith(
                    color: AppColors.error,
                  )),
                  const SizedBox(height: 8),
                  ...overdueFees.take(5).map((fee) {
                    final daysOverdue = today.difference(
                      DateTime(fee.dueDate!.year, fee.dueDate!.month, fee.dueDate!.day),
                    ).inDays;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                fee.studentName.isNotEmpty ? fee.studentName[0].toUpperCase() : '?',
                                style: AppTypography.titleSmall.copyWith(color: AppColors.error),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(fee.studentName, style: AppTypography.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text('$currencySymbol${fee.amount.toStringAsFixed(0)} - $daysOverdue days overdue',
                                  style: AppTypography.bodySmall.copyWith(color: context.textSecondaryColor)),
                                ],
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('${daysOverdue}d', style: AppTypography.labelSmall.copyWith(
                              color: AppColors.error,
                            )),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (overdueFees.length > 5) ...[
                    const SizedBox(height: 4),
                    Text('+ ${overdueFees.length - 5} more',
                      style: AppTypography.bodySmall.copyWith(color: context.textTertiaryColor)),
                  ],
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _alertChip({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text('$count $label', style: AppTypography.labelMedium.copyWith(color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart(BuildContext context, WidgetRef ref, DashboardStatsModel? stats) {
    final history = stats?.monthlyRevenueHistory ?? [];
    final revenue = stats?.monthlyRevenue ?? 0;
    final currencySymbol = ref.watch(settingsProvider).currencySymbol;
    final hasData = history.isNotEmpty;
    final spots = hasData
        ? history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList()
        : [const FlSpot(0, 0)];
    final maxY = hasData ? (spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.2).clamp(1.0, double.infinity) : 100.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Revenue', style: AppTypography.titleMedium),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('This Month', style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primary,
                  )),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('$currencySymbol${_formatAmount(revenue)}', style: AppTypography.headlineLarge.copyWith(
              color: AppColors.accent,
            )),
            const SizedBox(height: 20),
            SizedBox(
              height: 180,
              child: hasData ? LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: (maxY / 4).clamp(0.5, double.infinity),
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: context.borderColor.withValues(alpha: 0.2),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppColors.accent,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.accent.withValues(alpha: 0.3),
                            AppColors.accent.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                  minY: 0,
                  maxY: maxY,
                ),
              ) : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bar_chart_rounded, size: 40, color: context.textTertiaryColor),
                    const SizedBox(height: 8),
                    Text('No revenue data yet', style: AppTypography.bodySmall),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceChart(BuildContext context, DashboardStatsModel? stats) {
    final weekly = stats?.weeklyAttendance ?? [];
    final hasData = weekly.isNotEmpty;
    final maxY = hasData ? (weekly.reduce((a, b) => a > b ? a : b) * 1.2).clamp(1.0, double.infinity) : 100.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Attendance', style: AppTypography.titleMedium),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('This Week', style: AppTypography.labelSmall.copyWith(
                    color: AppColors.secondary,
                  )),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 160,
              child: hasData ? BarChart(
                BarChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: (maxY / 4).clamp(0.5, double.infinity),
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: context.borderColor.withValues(alpha: 0.2),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                          if (value.toInt() < labels.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(labels[value.toInt()],
                                style: AppTypography.labelSmall.copyWith(fontSize: 10)),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(weekly.length, (i) => _barGroup(i, weekly[i])),
                  maxY: maxY,
                ),
              ) : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bar_chart_rounded, size: 40, color: context.textTertiaryColor),
                    const SizedBox(height: 8),
                    Text('No attendance data yet', style: AppTypography.bodySmall),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _barGroup(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          width: 20,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          gradient: const LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [AppColors.secondary, AppColors.neonCyan],
          ),
        ),
      ],
    );
  }

  Widget _buildOccupancyHeatmap(BuildContext context, WidgetRef ref) {
    final seatsAsync = ref.watch(seatsStreamProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Seat Occupancy', style: AppTypography.titleMedium),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Live', style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primary,
                  )),
                ),
              ],
            ),
            const SizedBox(height: 16),
            seatsAsync.when(
              data: (seats) {
                if (seats.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        children: [
                          Icon(Icons.chair_rounded, size: 40, color: context.textTertiaryColor),
                          const SizedBox(height: 8),
                          Text('No seats configured yet', style: AppTypography.bodySmall),
                        ],
                      ),
                    ),
                  );
                }

                int occupied = 0, reserved = 0, available = 0;
                for (final s in seats) {
                  switch (s.status) {
                    case 'occupied': occupied++; break;
                    case 'reserved': reserved++; break;
                    default: available++; break;
                  }
                }
                final total = seats.length;
                final occPct = total > 0 ? (occupied / total * 100).round() : 0;

                return Row(
                  children: [
                    // Donut chart
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              centerSpaceRadius: 42,
                              sectionsSpace: 3,
                              startDegreeOffset: -90,
                              sections: [
                                if (occupied > 0)
                                  PieChartSectionData(
                                    value: occupied.toDouble(),
                                    color: AppColors.seatOccupied,
                                    radius: 18,
                                    showTitle: false,
                                  ),
                                if (reserved > 0)
                                  PieChartSectionData(
                                    value: reserved.toDouble(),
                                    color: AppColors.seatReserved,
                                    radius: 18,
                                    showTitle: false,
                                  ),
                                if (available > 0)
                                  PieChartSectionData(
                                    value: available.toDouble(),
                                    color: AppColors.seatAvailable,
                                    radius: 18,
                                    showTitle: false,
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('$occPct%', style: AppTypography.headlineMedium.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w800,
                              )),
                              Text('occupied', style: AppTypography.labelSmall.copyWith(
                                color: context.textTertiaryColor,
                              )),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Legend + counts
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _seatLegendRow(context, 'Occupied', occupied, total, AppColors.seatOccupied),
                          const SizedBox(height: 12),
                          _seatLegendRow(context, 'Reserved', reserved, total, AppColors.seatReserved),
                          const SizedBox(height: 12),
                          _seatLegendRow(context, 'Available', available, total, AppColors.seatAvailable),
                          const SizedBox(height: 12),
                          Divider(color: context.borderColor.withValues(alpha: 0.2), height: 1),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.chair_rounded, size: 16, color: context.textTertiaryColor),
                              const SizedBox(width: 8),
                              Text('Total: $total seats', style: AppTypography.labelLarge),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (_, _) => Center(
                child: Text('Failed to load seats', style: AppTypography.bodySmall.copyWith(color: AppColors.error)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seatLegendRow(BuildContext context, String label, int count, int total, Color color) {
    final pct = total > 0 ? (count / total * 100).round() : 0;
    return Row(
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: AppTypography.labelMedium)),
        Text('$count', style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(width: 6),
        Text('($pct%)', style: AppTypography.labelSmall.copyWith(color: context.textTertiaryColor)),
      ],
    );
  }

  Widget _buildTopStudents(BuildContext context, WidgetRef ref) {
    final topAsync = ref.watch(topStudentsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Top Students', style: AppTypography.titleMedium),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('By Attendance', style: AppTypography.labelSmall.copyWith(
                    color: AppColors.accent,
                  )),
                ),
              ],
            ),
            const SizedBox(height: 14),
            topAsync.when(
              data: (entries) {
                if (entries.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          Icon(Icons.school_rounded, size: 36, color: context.textTertiaryColor),
                          const SizedBox(height: 8),
                          Text('No attendance data available', style: AppTypography.bodySmall),
                        ],
                      ),
                    ),
                  );
                }

                final topEntries = entries.take(3).toList();
                final medals = [
                  Icons.emoji_events_rounded,
                  Icons.emoji_events_outlined,
                  Icons.emoji_events_outlined,
                ];
                final medalColors = [
                  const Color(0xFFFFD700), // Gold
                  const Color(0xFFC0C0C0), // Silver
                  const Color(0xFFCD7F32), // Bronze
                ];

                return Column(
                  children: List.generate(topEntries.length, (index) {
                    final entry = topEntries[index];
                    final studentName = entry.key;
                    final percentage = entry.value;
                    final medalIcon = medals[index];
                    final medalColor = medalColors[index];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: medalColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(medalIcon, color: medalColor, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(studentName, style: AppTypography.labelLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: percentage / 100,
                                    backgroundColor: context.borderColor.withValues(alpha: 0.2),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      percentage >= 80 ? AppColors.accent
                                          : percentage >= 50 ? AppColors.warning
                                          : AppColors.error,
                                    ),
                                    minHeight: 6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${percentage.toStringAsFixed(0)}%',
                            style: AppTypography.titleSmall.copyWith(
                              color: percentage >= 80 ? AppColors.accent
                                  : percentage >= 50 ? AppColors.warning
                                  : AppColors.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (_, _) => Center(
                child: Text('No attendance data available', style: AppTypography.bodySmall),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, WidgetRef ref) {
    final feesAsync = ref.watch(feesStreamProvider);
    final overdueCount = feesAsync.whenOrNull(
      data: (fees) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        return fees.where((f) {
          if (f.status == 'paid') return false;
          if (f.dueDate == null) return false;
          final dueDay = DateTime(f.dueDate!.year, f.dueDate!.month, f.dueDate!.day);
          return dueDay.isBefore(today);
        }).length;
      },
    ) ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions', style: AppTypography.titleMedium),
          const SizedBox(height: 14),
          Row(
            children: [
              _QuickActionButton(
                icon: Icons.person_add_rounded,
                label: 'Add Student',
                color: AppColors.primary,
                onTap: () => context.push(AppRoutes.addStudent),
              ),
              const SizedBox(width: 10),
              _QuickActionButton(
                icon: Icons.group_add_rounded,
                label: 'Requests',
                color: AppColors.warning,
                onTap: () => context.push(AppRoutes.joinRequests),
                badgeCount: ref.watch(joinRequestsProvider).valueOrNull?.length ?? 0,
              ),
              const SizedBox(width: 10),
              _QuickActionButton(
                icon: Icons.receipt_long_rounded,
                label: 'Collect Fee',
                color: AppColors.neonPink,
                onTap: () => context.go(AppRoutes.fees),
                badgeCount: overdueCount > 0 ? overdueCount : null,
              ),
              const SizedBox(width: 10),
              _QuickActionButton(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Expenses',
                color: const Color(0xFFEF4444),
                onTap: () => context.push(AppRoutes.expenses),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _QuickActionButton(
                icon: Icons.campaign_rounded,
                label: 'Notice Board',
                color: AppColors.secondary,
                onTap: () => context.push(AppRoutes.notices),
              ),
              const SizedBox(width: 10),
              _QuickActionButton(
                icon: Icons.grid_view_rounded,
                label: 'Seat Layout',
                color: AppColors.neonCyan,
                onTap: () => context.push(AppRoutes.seatLayoutEditor),
              ),
              const SizedBox(width: 10),
              _QuickActionButton(
                icon: Icons.badge_rounded,
                label: 'Staff',
                color: const Color(0xFF6366F1),
                onTap: () => context.push(AppRoutes.staff),
              ),
              const SizedBox(width: 10),
              _QuickActionButton(
                icon: Icons.storefront_rounded,
                label: 'Branded\nApp',
                color: AppColors.neonPurple,
                onTap: () => context.push(AppRoutes.whiteLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(recentActivitiesProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Activity', style: AppTypography.titleMedium),
              TextButton(
                onPressed: () => context.push(AppRoutes.notifications),
                child: Text('View All', style: AppTypography.labelMedium.copyWith(
                  color: AppColors.primary,
                )),
              ),
            ],
          ),
          const SizedBox(height: 8),
          activitiesAsync.when(
            data: (activities) {
              if (activities.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.borderColor.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.inbox_rounded, size: 40, color: context.textTertiaryColor),
                      const SizedBox(height: 8),
                      Text('No recent activity', style: AppTypography.bodyMedium.copyWith(
                        color: context.textTertiaryColor,
                      )),
                    ],
                  ),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.borderColor.withValues(alpha: 0.2)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: activities.length.clamp(0, 5),
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: context.borderColor.withValues(alpha: 0.1),
                  ),
                  itemBuilder: (context, index) {
                    final activity = activities[index];
                    return _ActivityTile(activity: activity);
                  },
                ),
              );
            },
            loading: () => Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiringAlerts(BuildContext context, WidgetRef ref) {
    final expiring = ref.watch(expiringMembershipsProvider);
    if (expiring.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timer_rounded, size: 18, color: AppColors.warning),
                const SizedBox(width: 8),
                Text('Expiring Soon', style: AppTypography.titleSmall.copyWith(color: AppColors.warning)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${expiring.length}', style: AppTypography.labelSmall.copyWith(color: AppColors.warning)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...expiring.take(3).map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.warning.withValues(alpha: 0.15),
                    child: Text(
                      e.student.name.isNotEmpty ? e.student.name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.warning),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(e.student.name, style: AppTypography.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Text(
                    e.daysRemaining == 0 ? 'Today' : '${e.daysRemaining}d',
                    style: AppTypography.labelSmall.copyWith(
                      color: e.daysRemaining <= 1 ? AppColors.error : AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final int? badgeCount;

  const _QuickActionButton({
    required this.icon, required this.label,
    required this.color, required this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                if (badgeCount != null && badgeCount! > 0)
                  Positioned(
                    right: -4, top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.surfaceColor, width: 2),
                      ),
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(label, style: AppTypography.labelSmall.copyWith(fontSize: 11),
              textAlign: TextAlign.center, maxLines: 2),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final dynamic activity; // ActivityModel

  const _ActivityTile({required this.activity});

  @override
  Widget build(BuildContext context) {
    final typeIcons = {
      'student_added': Icons.person_add_rounded,
      'fee_collected': Icons.payments_rounded,
      'attendance_marked': Icons.fact_check_rounded,
      'seat_changed': Icons.event_seat_rounded,
      'staff_added': Icons.badge_rounded,
      'book_issued': Icons.menu_book_rounded,
    };

    final typeColors = {
      'student_added': AppColors.accent,
      'fee_collected': AppColors.success,
      'attendance_marked': AppColors.info,
      'seat_changed': AppColors.neonPurple,
      'staff_added': AppColors.secondary,
      'book_issued': AppColors.warning,
    };

    final icon = typeIcons[activity.type] ?? Icons.circle;
    final color = typeColors[activity.type] ?? AppColors.primary;

    String timeAgo() {
      if (activity.timestamp == null) return '';
      final diff = DateTime.now().difference(activity.timestamp!);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return DateFormat('MMM d').format(activity.timestamp!);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              activity.description,
              style: AppTypography.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(timeAgo(), style: AppTypography.labelSmall.copyWith(color: context.textTertiaryColor)),
        ],
      ),
    );
  }
}
