import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';

/// Premium Content Card Container
///
/// Clean, high-performance card container with high contrast, subtle hairline
/// border, and smooth 120 FPS rendering. Replaces expensive GPU offscreen
/// blur convolutions over solid backgrounds with crisp, readable modern surfaces.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final double opacity;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Color? borderColor;
  final Gradient? gradient;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.blur = 0,
    this.opacity = 1.0,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderColor,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = opacity == 0
        ? Colors.transparent
        : (isDark ? AppColors.darkCard : AppColors.lightSurface);
    final effectiveBorder = borderColor ??
        (isDark
            ? AppColors.darkBorder.withValues(alpha: 0.5)
            : AppColors.lightBorder);

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: gradient == null ? surfaceColor : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: effectiveBorder,
          width: 1.0,
        ),
        boxShadow: (opacity > 0 && gradient == null)
            ? (isDark ? AppShadows.subtle : AppShadows.card)
            : null,
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}
