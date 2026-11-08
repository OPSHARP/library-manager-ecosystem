import 'package:flutter/cupertino.dart';

/// iOS system color palette (dark + light) following Apple HIG.
///
/// All values map 1:1 to the iOS 13+ system colors so the app feels native
/// on iOS (SF Pro + system colors). Semantic names used by screens stay the
/// same, so migrating to the iOS look is drop-in.
class AppColors {
  AppColors._();

  // ─── Brand / accents (iOS system colors) ───
  static const Color primary = Color(0xFF0A84FF); // systemBlue (dark)
  static const Color primaryLight = Color(0xFF64D2FF);
  static const Color primaryDark = Color(0xFF0060DF);

  static const Color secondary = Color(0xFF64D2FF); // systemTeal
  static const Color secondaryLight = Color(0xFFA5F0FC);

  static const Color accent = Color(0xFF30D158); // systemGreen
  static const Color accentLight = Color(0xFF8AFFA6);

  static const Color neonPink = Color(0xFFFF375F); // systemPink
  static const Color neonPurple = Color(0xFFBF5AF2); // systemPurple
  static const Color neonBlue = Color(0xFF0A84FF); // systemBlue
  static const Color neonCyan = Color(0xFF64D2FF); // systemCyan
  static const Color neonGreen = Color(0xFF30D158); // systemGreen

  // ─── iOS system colors ───
  static const Color systemRed = Color(0xFFFF453A);
  static const Color systemOrange = Color(0xFFFF9F0A);
  static const Color systemYellow = Color(0xFFFFD60A);
  static const Color systemGreen = Color(0xFF30D158);
  static const Color systemMint = Color(0xFF63E6E2);
  static const Color systemTeal = Color(0xFF64D2FF);
  static const Color systemCyan = Color(0xFF64D2FF);
  static const Color systemBlue = Color(0xFF0A84FF);
  static const Color systemIndigo = Color(0xFF5E5CE6);
  static const Color systemPurple = Color(0xFFBF5AF2);
  static const Color systemPink = Color(0xFFFF375F);
  static const Color systemBrown = Color(0xFFAC8E68);

  // ─── iOS system grays ───
  static const Color systemGray = Color(0xFF8E8E93);
  static const Color systemGray2 = Color(0xFF636366);
  static const Color systemGray3 = Color(0xFF48484A);
  static const Color systemGray4 = Color(0xFF3A3A3C);
  static const Color systemGray5 = Color(0xFF2C2C2E);
  static const Color systemGray6 = Color(0xFF1C1C1E);

  // ─── iOS system labels ───
  static const Color label = Color(0xFFFFFFFF);
  static const Color secondaryLabel = Color(0xFF98989D);
  static const Color tertiaryLabel = Color(0xFF636366);
  static const Color quaternaryLabel = Color(0xFF38383A);

  // ─── iOS grouped backgrounds ───
  static const Color systemGroupedBackground = Color(0xFF000000);
  static const Color secondarySystemGroupedBackground = Color(0xFF1C1C1E);
  static const Color tertiarySystemGroupedBackground = Color(0xFF2C2C2E);
  static const Color separator = Color(0xFF38383A);
  static const Color opaqueSeparator = Color(0xFF48484A);

  // ─── Semantic surface colors (mapped to iOS) ───
  static const Color darkBg = systemGroupedBackground;
  static const Color darkSurface = secondarySystemGroupedBackground;
  static const Color darkCard = tertiarySystemGroupedBackground;
  static const Color darkCardLight = systemGray4;
  static const Color darkBorder = opaqueSeparator;

  static const Color lightBg = Color(0xFFF2F2F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFE5E5EA);

  static const Color textPrimary = label;
  static const Color textSecondary = secondaryLabel;
  static const Color textTertiary = tertiaryLabel;
  static const Color textDark = Color(0xFF000000);
  static const Color textDarkSecondary = Color(0xFF6C6C70);

  static const Color success = systemGreen;
  static const Color warning = systemOrange;
  static const Color error = systemRed;
  static const Color info = systemBlue;

  static final Color successBg = systemGreen.withValues(alpha: 0.16);
  static final Color warningBg = systemOrange.withValues(alpha: 0.16);
  static final Color errorBg = systemRed.withValues(alpha: 0.16);
  static final Color infoBg = systemBlue.withValues(alpha: 0.16);

  static const Color seatAvailable = systemGreen;
  static const Color seatOccupied = systemRed;
  static const Color seatReserved = systemOrange;
  static const Color seatMaintenance = systemGray;

  static const Color feePaid = systemGreen;
  static const Color feePending = systemOrange;
  static const Color feeOverdue = systemRed;

  static final Color glassWhite = CupertinoColors.white.withValues(alpha: 0.10);
  static final Color glassBorder = CupertinoColors.white.withValues(alpha: 0.16);

  /// Translucent fill used for iOS-style floating bars and cards.
  static final Color floatingBar =
      AppColors.secondarySystemGroupedBackground.withValues(alpha: 0.86);
}

extension ThemeColors on BuildContext {
  bool get isDarkMode => CupertinoTheme.of(this).brightness == Brightness.dark;

  Color get scaffoldBg =>
      isDarkMode ? AppColors.systemGroupedBackground : AppColors.lightBg;
  Color get cardBg =>
      isDarkMode ? AppColors.tertiarySystemGroupedBackground : AppColors.lightCard;
  Color get surfaceColor =>
      isDarkMode ? AppColors.secondarySystemGroupedBackground : AppColors.lightSurface;
  Color get borderColor =>
      isDarkMode ? AppColors.separator : AppColors.lightSurface;
  Color get textPrimaryColor => isDarkMode ? AppColors.label : AppColors.textDark;
  Color get textSecondaryColor =>
      isDarkMode ? AppColors.secondaryLabel : AppColors.textDarkSecondary;
}
