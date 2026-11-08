import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';

/// iOS 26-style floating capsule tab bar over the content.
///
/// The bar blurs what is behind it (Liquid-Glass look) and tints the active
/// tab with the system blue pill. Content scrolls underneath, so scroll views
/// add bottom padding to keep the last row visible.
class MainNavScreen extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainNavScreen({super.key, required this.navigationShell});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  void _onTap(int index) {
    if (index == widget.navigationShell.currentIndex) return;
    HapticFeedback.selectionClick();
    widget.navigationShell.goBranch(index, initialLocation: false);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.systemGroupedBackground,
      child: Stack(
        children: [
          Positioned.fill(child: widget.navigationShell),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _FloatingTabBar(
                currentIndex: widget.navigationShell.currentIndex,
                onTap: _onTap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _FloatingTabBar({required this.currentIndex, required this.onTap});

  static const _tabs = [
    (icon: CupertinoIcons.house_fill, outline: CupertinoIcons.house, label: 'Home'),
    (icon: CupertinoIcons.location_fill, outline: CupertinoIcons.location, label: 'Nearby'),
    (icon: CupertinoIcons.person_fill, outline: CupertinoIcons.person, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.floatingBar,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppColors.glassBorder),
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.black.withValues(alpha: 0.45),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _tabs.length; i++) _buildTab(i),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(int index) {
    final tab = _tabs[index];
    final selected = currentIndex == index;
    final color = selected ? CupertinoColors.white : AppColors.tertiaryLabel;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.systemBlue : CupertinoColors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? tab.icon : tab.outline, color: color, size: 22),
            const SizedBox(width: 6),
            Text(
              tab.label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
