import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Library Manager Refined Gradient System
/// Clean, harmonious modern SaaS gradients
class AppGradients {
  AppGradients._();

  // ─── Primary Gradients ───
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primary, AppColors.primaryLight],
  );

  static const LinearGradient primaryDarkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primaryDark, AppColors.primary],
  );

  // ─── Refined Accent Gradients ───
  static const LinearGradient neonPurpleBlue = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6366F1), Color(0xFF3B82F6)],
  );

  static const LinearGradient neonPinkPurple = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF43F5E), Color(0xFF7C3AED)],
  );

  static const LinearGradient neonCyanBlue = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0EA5E9), Color(0xFF3B82F6)],
  );

  static const LinearGradient neonGreenCyan = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF0EA5E9)],
  );

  // ─── Background Gradients ───
  static const LinearGradient darkBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      AppColors.darkBg,
      Color(0xFF0D1321),
      AppColors.darkSurface,
    ],
  );

  static const RadialGradient darkRadialGlow = RadialGradient(
    center: Alignment.topRight,
    radius: 1.5,
    colors: [
      Color(0xFF141926),
      AppColors.darkBg,
    ],
  );

  // ─── Card Gradients ───
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1E293B),
      Color(0xFF1A2333),
    ],
  );

  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1E293B),
      Color(0xFF1A2333),
    ],
  );

  // ─── Stat Card Gradients (Harmonious & Professional) ───
  static const LinearGradient statStudents = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4338CA), Color(0xFF6366F1)], // Indigo
  );

  static const LinearGradient statSeats = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0284C7), Color(0xFF0EA5E9)], // Sky
  );

  static const LinearGradient statAttendance = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF059669), Color(0xFF10B981)], // Emerald
  );

  static const LinearGradient statRevenue = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD97706), Color(0xFFF59E0B)], // Warm Amber / Gold
  );

  // ─── Shimmer Gradient ───
  static const LinearGradient shimmer = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      AppColors.shimmerBase,
      AppColors.shimmerHighlight,
      AppColors.shimmerBase,
    ],
    stops: [0.0, 0.5, 1.0],
  );

  // ─── Onboarding Gradients ───
  static const List<LinearGradient> onboardingGradients = [
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF141926), Color(0xFF0B0F19)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0D1B2A), Color(0xFF0B0F19)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0F241D), Color(0xFF0B0F19)],
    ),
  ];
}
