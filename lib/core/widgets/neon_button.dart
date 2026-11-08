import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Flat button widget — minimalist filled/outlined button with no glow effects.
class NeonButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;
  final bool isLoading;
  final bool isOutlined;
  final double? width;
  final double height;
  final double borderRadius;

  const NeonButton({
    super.key,
    required this.text,
    this.onPressed,
    this.color = AppColors.primary,
    this.icon,
    this.isLoading = false,
    this.isOutlined = false,
    this.width,
    this.height = 52,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: isOutlined ? _buildOutlinedButton() : _buildFilledButton(),
    );
  }

  VoidCallback? _wrapPressed() {
    if (onPressed == null || isLoading) return null;
    return () {
      HapticFeedback.lightImpact();
      onPressed!();
    };
  }

  Widget _buildFilledButton() {
    return ElevatedButton(
      onPressed: _wrapPressed(),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: color.withValues(alpha: 0.4),
        elevation: 0,
        minimumSize: Size(width ?? 0, height),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      child: _buildChild(Colors.white),
    );
  }

  Widget _buildOutlinedButton() {
    return OutlinedButton(
      onPressed: _wrapPressed(),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color, width: 1.5),
        minimumSize: Size(width ?? 0, height),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      child: _buildChild(color),
    );
  }

  Widget _buildChild(Color textColor) {
    if (isLoading) {
      return SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: textColor,
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(text, style: AppTypography.buttonText.copyWith(color: textColor)),
        ],
      );
    }

    return Text(text, style: AppTypography.buttonText.copyWith(color: textColor));
  }
}
