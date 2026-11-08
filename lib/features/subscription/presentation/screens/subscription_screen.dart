import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../../data/models/subscription_model.dart';

/// Subscription / Pricing Screen
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _purchasing = false;

  /// Resolve the notifier from the family provider using the current user's UID.
  SubscriptionNotifier _notifier() {
    final user = ref.read(currentUserProvider);
    final uid = user?.uid ?? '';
    return ref.read(subscriptionProvider(uid).notifier);
  }

  Future<void> _purchase(String productId) async {
    if (_purchasing) return;
    setState(() => _purchasing = true);

    try {
      final success = await _notifier().purchaseProduct(productId);
      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription activated! Welcome to Pro.'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase was cancelled. You can try again anytime.'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } on ProductNotFoundException catch (e) {
      if (mounted) {
        _showSetupRequiredDialog(e.productId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  /// Shows a helpful dialog when the product doesn't exist in Play Console yet.
  void _showSetupRequiredDialog(String productId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppColors.warning),
            SizedBox(width: 10),
            Text('Play Console Setup Required'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The subscription product "$productId" has not been created in '
              'Google Play Console yet.',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Steps:\n'
                '1. Open Google Play Console\n'
                '2. Go to Monetize → Products → Subscriptions\n'
                '3. Create "pro_monthly" (\$9.99/mo) and "pro_yearly" (\$99.99/yr)\n'
                '4. Publish the app to Internal Testing track\n'
                '5. Install the testing build on your device',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Got it',
              style: TextStyle(color: context.textSecondaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _restorePurchases() async {
    if (_purchasing) return;
    setState(() => _purchasing = true);

    try {
      await _notifier().restorePurchases();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Restore completed. If you had an active subscription, it should now be available.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscription = ref.watch(currentSubscriptionProvider);
    final isActive = subscription.isActive;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          isActive ? 'My Subscription' : 'Upgrade to Pro',
          style: AppTypography.headlineSmall,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            children: [
              // Current plan card
              if (isActive) _buildActivePlanCard(subscription),

              if (!isActive) ...[
                _buildHeader(),
                const SizedBox(height: 24),

                // Monthly plan
                _buildPlanCard(
                  title: 'Pro Monthly',
                  price: '\$9.99',
                  period: '/month',
                  color: AppColors.neonPurple,
                  features: const [
                    'Unlimited book management',
                    'Unlimited student records',
                    'Seat management & tracking',
                    'Attendance & fee management',
                    'Real-time analytics & reports',
                    'Cloud backup & sync',
                    'Priority email support',
                    'No advertisements',
                  ],
                  onTap: () => _purchase(SubscriptionProducts.monthly),
                ),
                const SizedBox(height: 16),

                // Yearly plan (highlighted)
                _buildPlanCard(
                  title: 'Pro Yearly',
                  price: '\$99.99',
                  period: '/year',
                  color: AppColors.primary,
                  isBestValue: true,
                  features: const [
                    'Everything in Pro Monthly',
                    'Save \$19.89 per year',
                    'Priority chat support',
                    'Early access to new features',
                  ],
                  onTap: () => _purchase(SubscriptionProducts.yearly),
                ),
              ],

              const SizedBox(height: 24),

              // Restore purchases
              TextButton.icon(
                onPressed: _purchasing ? null : _restorePurchases,
                icon: const Icon(Icons.restore_rounded, size: 20),
                style: TextButton.styleFrom(
                  foregroundColor: context.textSecondaryColor,
                ),
                label: Text(
                  'Restore Purchases',
                  style: AppTypography.bodyMedium.copyWith(
                    color: context.textSecondaryColor,
                  ),
                ),
              ),

              if (_purchasing) ...[
                const SizedBox(height: 16),
                const CircularProgressIndicator(),
              ],

              const SizedBox(height: 24),

              // Terms note
              Text(
                'Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period. '
                'Manage your subscriptions in Google Play Settings.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  color: context.textTertiaryColor,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: AppGradients.primaryGradient,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(Icons.star_rounded, size: 44, color: Colors.white),
        ),
        const SizedBox(height: 16),
        Text(
          'Unlock Premium Features',
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Get the most out of your Library Manager with a Pro subscription',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: context.textSecondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildActivePlanCard(SubscriptionModel subscription) {
    final daysRemaining = subscription.expiresAt
        ?.difference(DateTime.now())
        .inDays;

    final expiresText = daysRemaining != null
        ? daysRemaining > 0
              ? '$daysRemaining days remaining'
              : 'Expires today'
        : '';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppGradients.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_rounded, size: 16, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'ACTIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            subscription.planName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (expiresText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              expiresText,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Manage Subscription',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required String period,
    required Color color,
    bool isBestValue = false,
    required List<String> features,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: isBestValue
            ? Border.all(color: AppColors.primary, width: 2)
            : null,
      ),
      child: Column(
        children: [
          // Best value badge
          if (isBestValue)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                gradient: AppGradients.primaryGradient,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
              ),
              child: const Text(
                'BEST VALUE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Title
                Text(
                  title,
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),

                // Price
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      price,
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        period,
                        style: AppTypography.bodyMedium.copyWith(
                          color: context.textSecondaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Features list
                ...features.map(
                  (feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(feature, style: AppTypography.bodyMedium),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Subscribe button
                SizedBox(
                  width: double.infinity,
                  child: Material(
                    color: isBestValue ? AppColors.primary : color,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _purchasing ? null : onTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          _purchasing ? 'Processing...' : 'Subscribe',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
