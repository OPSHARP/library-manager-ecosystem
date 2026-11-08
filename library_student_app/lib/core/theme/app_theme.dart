import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Open Sans-themed Cupertino theme following Apple HIG.
///
/// Every text slot in the Cupertino text theme uses Open Sans, and the
/// app-level [DefaultTextStyle] (wired in [LibraryStudentApp]) makes Open Sans
/// the inherited family for all text widgets, including inline const styles.
/// Type sizes follow the iOS ramp: large title 34 / title 22 / headline 17 /
/// body 17 / subhead 15 / footnote 13 / caption 12.
class AppTheme {
  AppTheme._();

  static TextStyle _openSans({
    Color color = AppColors.label,
    double fontSize = 17,
    FontWeight fontWeight = FontWeight.w400,
    double? letterSpacing,
  }) =>
      GoogleFonts.openSans(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
      );

  static CupertinoThemeData get cupertinoDarkTheme => CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: AppColors.systemBlue,
        primaryContrastingColor: CupertinoColors.white,
        scaffoldBackgroundColor: AppColors.systemGroupedBackground,
        barBackgroundColor: AppColors.floatingBar,
        applyThemeToAll: true,
        textTheme: CupertinoTextThemeData(
          primaryColor: AppColors.label,
          textStyle: _openSans(letterSpacing: -0.4),
          actionTextStyle: _openSans(),
          tabLabelTextStyle: _openSans(
            color: AppColors.tertiaryLabel,
            fontSize: 12,
          ),
          navTitleTextStyle: _openSans(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
          ),
          navLargeTitleTextStyle: _openSans(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
          pickerTextStyle: _openSans(),
          dateTimePickerTextStyle: _openSans(
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}
