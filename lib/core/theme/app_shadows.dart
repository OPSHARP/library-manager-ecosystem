import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Library Manager Shadow Definitions
/// Clean, subtle depth shadows for a modern SaaS aesthetic
class AppShadows {
  AppShadows._();

  // ─── Soft Shadows ───
  static List<BoxShadow> get soft => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ];

  static List<BoxShadow> get softLarge => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.16),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get subtle => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  // ─── Card Shadows ───
  static List<BoxShadow> get card => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  // ─── Refined Accent Glow Shadows ───
  static List<BoxShadow> get neonPrimary => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.2),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get neonCyan => [
        BoxShadow(
          color: AppColors.secondary.withValues(alpha: 0.2),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get neonPink => [
        BoxShadow(
          color: AppColors.neonPink.withValues(alpha: 0.2),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get neonGreen => [
        BoxShadow(
          color: AppColors.accent.withValues(alpha: 0.2),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> neonCustom(Color color, {double intensity = 0.2}) => [
        BoxShadow(
          color: color.withValues(alpha: intensity),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  // ─── Elevated Shadows ───
  static List<BoxShadow> get elevated => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  // ─── Bottom Navigation Shadow ───
  static List<BoxShadow> get bottomNav => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 16,
          offset: const Offset(0, -3),
        ),
      ];
}
