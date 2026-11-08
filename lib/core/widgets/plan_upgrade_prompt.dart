import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Shows the free-plan limit reached toast plus an "Upgrade Plan" button.
///
/// Call this when a [PlanLimitExceededException] is caught: it displays a
/// SnackBar with the upgrade message and an inline action that opens the
/// subscription/upgrade screen. The router and messenger are captured
/// synchronously, so this is safe to call even after a sheet/dialog has
/// been popped (as long as the passed context was mounted at call time).
void showPlanUpgradePrompt(BuildContext context) {
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        AppConstants.upgradeToastMessage,
        style: AppTypography.bodyMedium,
      ),
      backgroundColor: AppColors.warning,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: 'Upgrade Plan',
        textColor: Colors.white,
        onPressed: () {
          messenger.hideCurrentSnackBar();
          router.push(AppRoutes.subscription);
        },
      ),
    ),
  );
}

/// Full-screen upgrade dialog shown when a free-plan limit is hit.
/// Includes a prominent "Upgrade Plan" button.
Future<void> showUpgradePlanDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Theme.of(ctx).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.workspace_premium_rounded,
              color: AppColors.warning, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Free Plan Limit Reached',
                style: AppTypography.titleLarge),
          ),
        ],
      ),
      content: Text(
        '${AppConstants.upgradeToastMessage}\n\n'
        'Free plan allows up to ${AppConstants.maxStudents} students, '
        '${AppConstants.maxSeats} seats, '
        '${AppConstants.maxAttendanceRecords} attendance records and '
        '${AppConstants.maxFees} fee records. Upgrade to Pro for unlimited '
        'access.',
        style: AppTypography.bodyMedium,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(
            'Not Now',
            style: AppTypography.bodyMedium
                .copyWith(color: Theme.of(ctx).colorScheme.secondary),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(ctx);
            GoRouter.of(ctx).push(AppRoutes.subscription);
          },
          icon: const Icon(Icons.workspace_premium_rounded, size: 18),
          label: const Text('Upgrade Plan'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    ),
  );
}
