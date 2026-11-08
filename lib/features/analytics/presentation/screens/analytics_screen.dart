import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../dashboard/data/models/dashboard_stats_model.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../books/presentation/providers/book_provider.dart';
import '../../../../core/l10n/app_localizations.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final currencySymbol = ref.watch(settingsProvider).currencySymbol;

    return Scaffold(
      body: Container(
        color: context.scaffoldBg,
        child: SafeArea(
          child: statsAsync.when(
            data: (stats) => FutureBuilder(
              future: Future.wait([
                ref.read(bookRepositoryProvider).getTotalBookCount().first,
                ref.read(bookRepositoryProvider).getIssuedBookCount().first,
              ]),
              builder: (context, snapshot) {
                final totalBooks = snapshot.data?[0] ?? 0;
                final issuedBooks = snapshot.data?[1] ?? 0;
                return _buildContent(context, ref, stats, currencySymbol, totalBooks, issuedBooks);
              },
            ),
            loading: () => const SkeletonList(),
            error: (e, _) => Center(child: Text('Error: $e', style: AppTypography.bodyMedium.copyWith(color: AppColors.error))),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, DashboardStatsModel stats, String currencySymbol, int totalBooks, int issuedBooks) {
    final feeCollectionRate = (stats.pendingFees + stats.collectedFees) > 0
        ? ((stats.collectedFees / (stats.pendingFees + stats.collectedFees)) * 100).toStringAsFixed(1)
        : '—';

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context)!.analytics, style: AppTypography.headlineSmall),
              ],
            ),
          ),
        ),

        // Top stat cards
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                Expanded(child: _StatCard(label: 'Students', value: '${stats.totalStudents}', icon: Icons.people_rounded, color: AppColors.primary)),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(label: 'Active', value: '${stats.activeStudents}', icon: Icons.person_pin_rounded, color: AppColors.accent)),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(label: 'Attendance', value: '${stats.attendanceRate.toStringAsFixed(0)}%', icon: Icons.fact_check_rounded, color: AppColors.secondary)),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Row(
              children: [
                Expanded(child: _StatCard(label: 'Revenue', value: '$currencySymbol${_formatAmount(stats.monthlyRevenue)}', icon: Icons.trending_up_rounded, color: AppColors.neonPink)),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(label: 'Collected', value: '$currencySymbol${_formatAmount(stats.collectedFees)}', icon: Icons.account_balance_wallet_rounded, color: AppColors.feePaid)),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(label: 'Pending', value: '$currencySymbol${_formatAmount(stats.pendingFees)}', icon: Icons.pending_rounded, color: AppColors.warning)),
              ],
            ),
          ),
        ),

        // Revenue chart
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: GlassContainer(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Revenue Trend', style: AppTypography.titleMedium),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 200,
                    child: stats.monthlyRevenueHistory.isNotEmpty
                        ? _buildLineChart(context, stats.monthlyRevenueHistory, AppColors.accent)
                        : _noDataWidget(context),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Attendance chart
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: GlassContainer(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Weekly Attendance', style: AppTypography.titleMedium),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 200,
                    child: stats.weeklyAttendance.isNotEmpty
                        ? _buildBarChart(context, stats.weeklyAttendance)
                        : _noDataWidget(context),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Seat occupancy pie chart
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: GlassContainer(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Seat Occupancy', style: AppTypography.titleMedium),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 200,
                    child: stats.totalSeats > 0
                        ? PieChart(PieChartData(
                            sectionsSpace: 3,
                            centerSpaceRadius: 50,
                            sections: [
                              PieChartSectionData(value: stats.occupiedSeats.toDouble(), color: AppColors.seatOccupied, title: '${((stats.occupiedSeats / stats.totalSeats) * 100).toStringAsFixed(0)}%', titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12), radius: 40),
                              PieChartSectionData(value: stats.availableSeats.toDouble(), color: AppColors.seatAvailable, title: '${((stats.availableSeats / stats.totalSeats) * 100).toStringAsFixed(0)}%', titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12), radius: 40),
                              PieChartSectionData(value: stats.reservedSeats.toDouble(), color: AppColors.seatReserved, title: '${((stats.reservedSeats / stats.totalSeats) * 100).toStringAsFixed(0)}%', titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12), radius: 40),
                            ],
                          ))
                        : _noDataWidget(context),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _LegendDot(color: AppColors.seatOccupied, label: 'Occupied (${stats.occupiedSeats})'),
                      _LegendDot(color: AppColors.seatAvailable, label: 'Available (${stats.availableSeats})'),
                      _LegendDot(color: AppColors.seatReserved, label: 'Reserved (${stats.reservedSeats})'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Key metrics
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Key Metrics', style: AppTypography.titleMedium),
                const SizedBox(height: 14),
                _metricTile(context, 'Total Students', '${stats.totalStudents}', Icons.people_rounded, AppColors.primary, '${stats.activeStudents} active'),
                _metricTile(context, 'Attendance Rate', '${stats.attendanceRate.toStringAsFixed(1)}%', Icons.fact_check_rounded, AppColors.accent, '${stats.todayPresent} present / ${stats.todayAbsent} absent today'),
                _metricTile(context, 'Fee Collection Rate', '$feeCollectionRate%', Icons.account_balance_wallet_rounded, AppColors.neonPink, '${stats.collectedFees.toStringAsFixed(0)} collected of ${(stats.collectedFees + stats.pendingFees).toStringAsFixed(0)}'),
                _metricTile(context, 'Seat Occupancy', '${stats.occupancyRate.toStringAsFixed(1)}%', Icons.chair_rounded, AppColors.neonPurple, '${stats.occupiedSeats} of ${stats.totalSeats} seats filled'),
                _metricTile(context, 'Books', '$totalBooks', Icons.menu_book_rounded, AppColors.secondary, '$issuedBooks currently issued'),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildLineChart(BuildContext context, List<double> data, Color color) {
    final spots = data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.2;

    return LineChart(LineChartData(
      gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: (maxY / 4).clamp(0.5, double.infinity),
        getDrawingHorizontalLine: (v) => FlLine(color: context.borderColor.withValues(alpha: 0.2), strokeWidth: 1)),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28,
          getTitlesWidget: (v, m) {
            const labels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
            return v.toInt() < labels.length
                ? Padding(padding: const EdgeInsets.only(top: 8), child: Text(labels[v.toInt()], style: AppTypography.labelSmall.copyWith(fontSize: 10)))
                : const SizedBox();
          })),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true, color: color, barWidth: 3, dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.0)],
          )),
        ),
      ],
      minY: 0,
      maxY: maxY.clamp(1.0, double.infinity),
    ));
  }

  Widget _buildBarChart(BuildContext context, List<double> data) {
    final maxY = data.reduce((a, b) => a > b ? a : b) * 1.2;

    return BarChart(BarChartData(
      gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: (maxY / 4).clamp(0.5, double.infinity),
        getDrawingHorizontalLine: (v) => FlLine(color: context.borderColor.withValues(alpha: 0.2), strokeWidth: 1)),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28,
          getTitlesWidget: (v, m) {
            const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
            return v.toInt() < labels.length
                ? Padding(padding: const EdgeInsets.only(top: 8), child: Text(labels[v.toInt()], style: AppTypography.labelSmall.copyWith(fontSize: 10)))
                : const SizedBox();
          })),
      ),
      borderData: FlBorderData(show: false),
      barGroups: List.generate(data.length, (i) => BarChartGroupData(x: i, barRods: [
        BarChartRodData(toY: data[i], width: 20, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          gradient: const LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [AppColors.secondary, AppColors.neonCyan])),
      ])),
      maxY: maxY.clamp(1.0, double.infinity),
    ));
  }

  Widget _noDataWidget(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_rounded, size: 40, color: context.textTertiaryColor),
          const SizedBox(height: 8),
          Text('No data yet', style: AppTypography.bodySmall.copyWith(color: context.textTertiaryColor)),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 8),
          Text(value, style: AppTypography.titleMedium.copyWith(color: color, fontSize: 16)),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.labelSmall.copyWith(color: context.textTertiaryColor, fontSize: 9)),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 6),
      Text(label, style: AppTypography.labelSmall),
    ]);
  }
}

Widget _metricTile(BuildContext context, String label, String value, IconData icon, Color color, String subtitle) {
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(14)),
    child: Row(children: [
      Container(
        width: 42, height: 42,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, size: 22, color: color),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTypography.bodyMedium),
            Text(subtitle, style: AppTypography.labelSmall.copyWith(color: context.textSecondaryColor)),
          ],
        ),
      ),
      Text(value, style: AppTypography.titleMedium.copyWith(color: color), overflow: TextOverflow.ellipsis),
    ]),
  );
}
