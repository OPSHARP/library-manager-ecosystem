import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/loading_widget.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/utils/extensions.dart';
import '../dashboard/presentation/providers/dashboard_provider.dart';
import '../dashboard/data/models/fee_model.dart';
import '../auth/presentation/providers/auth_provider.dart';

class FeeDetailsScreen extends ConsumerWidget {
  const FeeDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final params = (ownerUid: auth.ownerUid ?? '', studentId: auth.studentUniqueId ?? '');
    final dashboard = ref.watch(dashboardProvider(params));

    return CupertinoPageScaffold(
      backgroundColor: AppColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.floatingBar,
        middle: const Text('Fee Details'),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: dashboard.isLoading
                  ? const LoadingWidget()
                  : dashboard.fees.isEmpty
                      ? const EmptyState(
                          icon: CupertinoIcons.money_dollar_circle,
                          title: 'No Fee Records',
                        )
                      : _buildContent(
                          context,
                          dashboard.fees,
                          dashboard.totalPaid,
                          dashboard.totalPending,
                          dashboard.currency,
                          auth.libraryName ?? '',
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context,
      List<FeeModel> fees,
      double totalPaid,
      double totalPending,
      String currency,
      String libraryName) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _buildSummary(totalPaid, totalPending, currency),
        const SizedBox(height: 20),
        const Text(
          'Payment History',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.label,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 8),
        ...fees.map((fee) => _buildFeeItem(context, fee, currency, libraryName)),
      ],
    );
  }

  Widget _buildSummary(double totalPaid, double totalPending, String currency) {
    return Row(
      children: [
        Expanded(
          child: GlassContainer(
            child: Column(
              children: [
                const Icon(
                  CupertinoIcons.checkmark_alt_circle_fill,
                  color: AppColors.success,
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  '$currency${totalPaid.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const Text(
                  'Total Paid',
                  style: TextStyle(color: AppColors.secondaryLabel, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GlassContainer(
            child: Column(
              children: [
                const Icon(
                  CupertinoIcons.time_solid,
                  color: AppColors.warning,
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  '$currency${totalPending.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const Text(
                  'Pending',
                  style: TextStyle(color: AppColors.secondaryLabel, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeeItem(
      BuildContext context, FeeModel fee, String currency, String libraryName) {
    final isPaid = fee.isPaid;
    return GestureDetector(
      onTap: isPaid ? () => _showReceiptDialog(context, fee, currency, libraryName) : null,
      child: GlassContainer(
        margin: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isPaid ? AppColors.successBg : AppColors.warningBg,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                isPaid
                    ? CupertinoIcons.checkmark_alt_circle_fill
                    : CupertinoIcons.time,
                color: isPaid ? AppColors.success : AppColors.warning,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        fee.month,
                        style: const TextStyle(
                          color: AppColors.label,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isPaid) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Receipt Available',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isPaid
                        ? 'Paid on ${fee.paidDate?.formatDate() ?? 'N/A'}'
                        : 'Due: ${fee.dueDate?.formatDate() ?? 'N/A'}',
                    style: const TextStyle(
                      color: AppColors.secondaryLabel,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '$currency${fee.amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: isPaid ? AppColors.success : AppColors.warning,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReceiptDialog(
      BuildContext context, FeeModel fee, String currency, String libraryName) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Digital Fee Receipt'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.successBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.checkmark_seal_fill,
                    color: AppColors.success,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  '$currency${fee.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'STATUS: PAID',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _receiptRow('Library', libraryName.isNotEmpty ? libraryName : 'Library Portal'),
              _receiptRow('Month', fee.month),
              _receiptRow('Paid On', fee.paidDate?.formatDate() ?? 'Verified'),
              _receiptRow('Method', fee.paymentMethod ?? 'Direct Cash/Online'),
              const SizedBox(height: 10),
              const Text(
                'This is a verified digital payment receipt issued by library management.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.tertiaryLabel),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.secondaryLabel)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.label)),
        ],
      ),
    );
  }
}
