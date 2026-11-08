import 'package:flutter/cupertino.dart';
import '../theme/app_colors.dart';

/// iOS-style inset grouped card.
///
/// Rounded rect with theme-aware grouped fill and a crisp hairline border — the
/// building block used across every inset-grouped list screen. Defaults to
/// 16pt internal padding (standard iOS group inset).
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final double borderRadius;
  final Color? color;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius = 14,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? context.cardBg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: context.isDarkMode
              ? AppColors.glassBorder
              : const Color(0xFFD1D1D6),
          width: 0.8,
        ),
      ),
      child: child,
    );
  }
}
