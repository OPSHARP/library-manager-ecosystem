import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_shadows.dart';
import '../services/connectivity_service.dart';
import '../l10n/app_localizations.dart';

/// Connectivity stream provider
final connectivityProvider = StreamProvider<bool>((ref) {
  return ConnectivityService.instance.onConnectivityChanged;
});

/// Bottom Navigation Shell
/// Wraps the main app screens with an animated bottom nav bar
class BottomNavShell extends ConsumerWidget {
  final Widget child;

  const BottomNavShell({super.key, required this.child});

  static const _tabs = [
    '/dashboard',
    '/students',
    '/seats',
    '/attendance',
    '/fees',
    '/books',
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i])) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = _currentIndex(context);
    final connectivityAsync = ref.watch(connectivityProvider);
    final isOffline = connectivityAsync.whenOrNull(data: (connected) => !connected) ?? !ConnectivityService.instance.isConnected;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          // Offline banner
          if (isOffline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              color: AppColors.warning,
              child: SafeArea(
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      'You are offline',
                      style: AppTypography.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(child: child),
        ],
      ),
      // Banner ads were removed — ads are now interstitial (foreground
      // resume, throttled) and rewarded (user-initiated), gated by the Pro
      // subscription. Bottom bar is just navigation.
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: AppShadows.bottomNav,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Flexible(
                  child: _NavItem(
                    icon: Icons.dashboard_rounded,
                    label: AppLocalizations.of(context)!.dashboard,
                    isSelected: currentIndex == 0,
                    onTap: () => context.go('/dashboard'),
                  ),
                ),
                Flexible(
                  child: _NavItem(
                    icon: Icons.people_rounded,
                    label: AppLocalizations.of(context)!.students,
                    isSelected: currentIndex == 1,
                    onTap: () => context.go('/students'),
                  ),
                ),
                Flexible(
                  child: _NavItem(
                    icon: Icons.chair_rounded,
                    label: AppLocalizations.of(context)!.seats,
                    isSelected: currentIndex == 2,
                    onTap: () => context.go('/seats'),
                  ),
                ),
                Flexible(
                  child: _NavItem(
                    icon: Icons.fact_check_rounded,
                    label: AppLocalizations.of(context)!.attendance,
                    isSelected: currentIndex == 3,
                    onTap: () => context.go('/attendance'),
                  ),
                ),
                Flexible(
                  child: _NavItem(
                    icon: Icons.receipt_long_rounded,
                    label: AppLocalizations.of(context)!.fees,
                    isSelected: currentIndex == 4,
                    onTap: () => context.go('/fees'),
                  ),
                ),
                Flexible(
                  child: _NavItem(
                    icon: Icons.menu_book_rounded,
                    label: 'Books',
                    isSelected: currentIndex == 5,
                    onTap: () => context.go('/books'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? AppColors.primary : context.textTertiaryColor,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSmall.copyWith(
                color: isSelected ? AppColors.primary : context.textTertiaryColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
