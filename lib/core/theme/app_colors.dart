import 'package:flutter/material.dart';

/// Library Manager Refined Color Palette
/// Clean, high-contrast modern SaaS design system
class AppColors {
  AppColors._();

  // ─── Primary Palette ───
  static const Color primary = Color(0xFF4F46E5);        // Indigo 600
  static const Color primaryLight = Color(0xFF818CF8);    // Indigo 400
  static const Color primaryDark = Color(0xFF3730A3);     // Indigo 800

  // ─── Secondary Palette ───
  static const Color secondary = Color(0xFF0EA5E9);       // Sky 500
  static const Color secondaryLight = Color(0xFF7DD3FC);  // Sky 300
  static const Color secondaryDark = Color(0xFF0284C7);   // Sky 600

  // ─── Accent Palette ───
  static const Color accent = Color(0xFF10B981);          // Emerald 500
  static const Color accentLight = Color(0xFF6EE7B7);     // Emerald 300
  static const Color accentDark = Color(0xFF059669);       // Emerald 600

  // ─── Refined Accent Palette (Mature, high-contrast SaaS tones) ───
  static const Color neonPink = Color(0xFFF43F5E);         // Rose 500
  static const Color neonPurple = Color(0xFF7C3AED);       // Violet 600
  static const Color neonBlue = Color(0xFF3B82F6);         // Blue 500
  static const Color neonCyan = Color(0xFF0EA5E9);         // Sky 500
  static const Color neonGreen = Color(0xFF10B981);        // Emerald 500

  // ─── Dark Theme Surfaces ───
  static const Color darkBg = Color(0xFF0B0F19);           // Deep slate black
  static const Color darkSurface = Color(0xFF0F172A);      // Slate 900
  static const Color darkCard = Color(0xFF1E293B);         // Slate 800
  static const Color darkCardLight = Color(0xFF334155);    // Slate 700
  static const Color darkBorder = Color(0xFF334155);       // Slate 700 hairline
  static const Color darkDivider = Color(0xFF1E293B);      // Subtle line

  // ─── Light Theme Surfaces ───
  static const Color lightBg = Color(0xFFF8FAFC);          // Slate 50
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);        // Pure clean white
  static const Color lightBorder = Color(0xFFE2E8F0);      // Slate 200

  // ─── Text Colors ───
  static const Color textPrimary = Color(0xFFF8FAFC);      // Crisp Slate 50
  static const Color textSecondary = Color(0xFF94A3B8);     // Slate 400
  static const Color textTertiary = Color(0xFF64748B);      // Slate 500
  static const Color textDark = Color(0xFF0F172A);          // Slate 900
  static const Color textDarkSecondary = Color(0xFF475569); // Slate 600

  // ─── Status Colors ───
  static const Color success = Color(0xFF10B981);           // Emerald 500
  static const Color warning = Color(0xFFF59E0B);           // Amber 500
  static const Color error = Color(0xFFEF4444);             // Red 500
  static const Color info = Color(0xFF3B82F6);              // Blue 500

  // ─── Status with Opacity (for backgrounds) ───
  static final Color successBg = const Color(0xFF10B981).withValues(alpha: 0.15);
  static final Color warningBg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
  static final Color errorBg = const Color(0xFFEF4444).withValues(alpha: 0.15);
  static final Color infoBg = const Color(0xFF3B82F6).withValues(alpha: 0.15);

  // ─── Seat Status Colors ───
  static const Color seatAvailable = Color(0xFF10B981);     // Emerald
  static const Color seatOccupied = Color(0xFFEF4444);      // Red
  static const Color seatReserved = Color(0xFFF59E0B);      // Amber
  static const Color seatMaintenance = Color(0xFF64748B);   // Slate 500

  // ─── Fee Status Colors ───
  static const Color feePaid = Color(0xFF10B981);
  static const Color feePending = Color(0xFFF59E0B);
  static const Color feeOverdue = Color(0xFFEF4444);

  // ─── Card Border & Highlights ───
  static const Color glassWhite = Color(0xFF1E293B);
  static const Color glassBorder = Color(0xFF334155);
  static const Color glassDarkWhite = Color(0xFF0F172A);

  // ─── Shimmer ───
  static const Color shimmerBase = Color(0xFF1E293B);
  static const Color shimmerHighlight = Color(0xFF334155);
}

/// Theme-aware color helpers.
/// Use `context.scaffoldBg`, `context.cardBg`, etc. instead of hardcoding
/// AppColors.darkBg, AppColors.lightBg, etc.
extension ThemeColors on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get scaffoldBg => isDarkMode ? AppColors.darkBg : AppColors.lightBg;
  Color get cardBg => isDarkMode ? AppColors.darkCard : AppColors.lightCard;
  Color get surfaceColor => isDarkMode ? AppColors.darkSurface : AppColors.lightSurface;
  Color get borderColor => isDarkMode ? AppColors.darkBorder : AppColors.lightBorder;
  Color get surfaceCardLight => isDarkMode ? AppColors.darkCardLight : AppColors.lightCard;

  Color get textPrimaryColor => isDarkMode ? AppColors.textPrimary : AppColors.textDark;
  Color get textSecondaryColor => isDarkMode ? AppColors.textSecondary : AppColors.textDarkSecondary;
  Color get textTertiaryColor => isDarkMode ? AppColors.textTertiary : AppColors.textDarkSecondary;
}
