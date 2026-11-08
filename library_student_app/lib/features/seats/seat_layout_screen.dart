import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/loading_widget.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/glass_container.dart';
import '../dashboard/presentation/providers/dashboard_provider.dart';
import '../dashboard/data/models/seat_model.dart';
import '../auth/presentation/providers/auth_provider.dart';

class SeatLayoutScreen extends ConsumerStatefulWidget {
  const SeatLayoutScreen({super.key});

  @override
  ConsumerState<SeatLayoutScreen> createState() => _SeatLayoutScreenState();
}

class _SeatLayoutScreenState extends ConsumerState<SeatLayoutScreen> {
  String _selectedShift = 'all';

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final params = (ownerUid: auth.ownerUid ?? '', studentId: auth.studentUniqueId ?? '');
    final dashboard = ref.watch(dashboardProvider(params));

    return CupertinoPageScaffold(
      backgroundColor: AppColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.floatingBar,
        middle: const Text('Seat Layout'),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: dashboard.isLoading
                  ? const LoadingWidget()
                  : _buildContent(context, dashboard.allSeats, dashboard.assignedSeat),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, List<SeatModel> seats, dynamic assignedSeat) {
    if (seats.isEmpty) {
      return const EmptyState(
        icon: CupertinoIcons.square_grid_2x2,
        title: 'No Seats Available',
      );
    }

    final rows = <int, List<SeatModel>>{};
    for (final seat in seats) {
      rows.putIfAbsent(seat.row, () => []);
      rows[seat.row]!.add(seat);
    }

    final sortedRows = rows.keys.toList()..sort();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shift Selector
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<String>(
                groupValue: _selectedShift,
                backgroundColor: AppColors.systemGray6,
                thumbColor: AppColors.systemGray5,
                children: const {
                  'all': Padding(padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6), child: Text('All', style: TextStyle(fontSize: 12))),
                  'morning': Padding(padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6), child: Text('Morning', style: TextStyle(fontSize: 12))),
                  'evening': Padding(padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6), child: Text('Evening', style: TextStyle(fontSize: 12))),
                  'night': Padding(padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6), child: Text('Night', style: TextStyle(fontSize: 12))),
                  'full_day': Padding(padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6), child: Text('Full Day', style: TextStyle(fontSize: 12))),
                },
                onValueChanged: (val) {
                  if (val != null) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedShift = val);
                  }
                },
              ),
            ),
          ),
          _buildSummary(seats),
          const SizedBox(height: 16),
          _buildLegend(),
          const SizedBox(height: 16),
          if (assignedSeat != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.successBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.checkmark_seal_fill,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Your seat: ${assignedSeat.seatNumber}',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          ...sortedRows.map((row) => _buildRow(context, row, rows[row]!, assignedSeat)),
        ],
      ),
    );
  }

  Widget _buildSummary(List<SeatModel> seats) {
    final total = seats.length;
    final int free = _selectedShift == 'all'
        ? seats.where((s) => s.isAvailable).length
        : seats.where((s) => s.isShiftAvailable(_selectedShift)).length;

    final categories = seats.map((s) => s.category).toSet().toList()..sort();
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _summaryStat('Total Seats', '$total', AppColors.systemBlue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _summaryStat(
                  _selectedShift == 'all' ? 'Free Seats' : 'Available',
                  '$free',
                  AppColors.success,
                ),
              ),
            ],
          ),
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((cat) {
                final count = seats.where((s) => s.category == cat).length;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.systemIndigo.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    '$cat ($count)',
                    style: const TextStyle(
                      color: AppColors.systemIndigo,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.secondaryLabel,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem(AppColors.seatAvailable, 'Free'),
        const SizedBox(width: 16),
        _legendItem(AppColors.seatOccupied, 'Occupied'),
        const SizedBox(width: 16),
        _legendItem(AppColors.seatReserved, 'Reserved'),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: AppColors.secondaryLabel, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildRow(
      BuildContext context, int rowNum, List<SeatModel> seats, dynamic assignedSeat) {
    seats.sort((a, b) => a.column.compareTo(b.column));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$rowNum',
              style: const TextStyle(color: AppColors.tertiaryLabel, fontSize: 11),
            ),
          ),
          const SizedBox(width: 4),
          ...seats.map((seat) => _buildSeatItem(seat, assignedSeat)),
        ],
      ),
    );
  }

  Widget _buildSeatItem(SeatModel seat, dynamic assignedSeat) {
    final isMine = assignedSeat != null && seat.seatId == assignedSeat.seatId;

    final bool isAvailableForCurrentShift = _selectedShift == 'all'
        ? seat.isAvailable
        : seat.isShiftAvailable(_selectedShift);

    Color bg;
    Color textColor;
    if (isMine) {
      bg = AppColors.systemBlue;
      textColor = CupertinoColors.white;
    } else if (isAvailableForCurrentShift) {
      bg = AppColors.seatAvailable.withValues(alpha: 0.18);
      textColor = AppColors.seatAvailable;
    } else if (seat.isReserved) {
      bg = AppColors.seatReserved.withValues(alpha: 0.18);
      textColor = AppColors.seatReserved;
    } else {
      bg = AppColors.seatOccupied.withValues(alpha: 0.18);
      textColor = AppColors.seatOccupied;
    }

    return Container(
      width: 40,
      height: 40,
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: isMine
            ? Border.all(color: CupertinoColors.white, width: 2)
            : null,
      ),
      child: Center(
        child: Text(
          seat.seatNumber.replaceAll(RegExp(r'[^0-9]'), ''),
          style: TextStyle(
            color: textColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
