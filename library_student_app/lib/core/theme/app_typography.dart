import 'package:flutter/cupertino.dart';

class AppTypography {
  AppTypography._();

  static const TextStyle poppinsBold = TextStyle(fontWeight: FontWeight.w700);
  static const TextStyle poppinsSemiBold = TextStyle(fontWeight: FontWeight.w600);
  static const TextStyle poppinsMedium = TextStyle(fontWeight: FontWeight.w500);
  static const TextStyle poppinsRegular = TextStyle(fontWeight: FontWeight.w400);
  static const TextStyle interRegular = TextStyle(fontWeight: FontWeight.w400);
  static const TextStyle interMedium = TextStyle(fontWeight: FontWeight.w500);
  static const TextStyle interSemiBold = TextStyle(fontWeight: FontWeight.w600);

  // Since we are moving to Cupertino, TextTheme isn't typically used the same way,
  // but if needed, define styles here without GoogleFonts.
}

