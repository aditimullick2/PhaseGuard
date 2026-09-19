import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

class PgTheme {
  static ThemeData data() {
    final inter = GoogleFonts.interTextTheme(
      ThemeData.dark().textTheme,
    ).apply(
      bodyColor: PgColors.textPrimary,
      displayColor: PgColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: PgColors.bgPrimary,
      textTheme: inter,
      colorScheme: const ColorScheme.dark(
        surface: PgColors.bgPrimary,
        primary: PgColors.accent,
        secondary: PgColors.accentDim,
        error: PgColors.scam,
      ),
    );
  }

  static TextStyle display({
    double size = 14,
    FontWeight weight = FontWeight.w600,
    Color color = PgColors.textPrimary,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.poppins(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static TextStyle body({
    double size = 12,
    FontWeight weight = FontWeight.w500,
    Color color = PgColors.textSecondary,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }
}
