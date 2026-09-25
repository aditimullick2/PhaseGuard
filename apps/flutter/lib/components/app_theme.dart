/// PhaseGuard Design System
/// All color, typography, and spacing tokens used across the app.
library app_theme;

import 'package:flutter/material.dart';

class AppColors {
  // Primary palette (Electric Blue: #1455D9 -> #2678FF)
  static const primary = Color(0xFF2678FF);
  static const primaryDark = Color(0xFF1455D9);
  static const primaryLight = Color(0xFF4A90E2);
  static const onPrimary = Colors.white;
  static const primary10 = Color(0x1A2678FF);
  static const primary20 = Color(0x332678FF);
  static const onPrimary10 = Color(0x1AFFFFFF);

  // Secondary
  static const secondary = Color(0xFF1455D9);
  static const onSecondary = Colors.white;
  static const secondary20 = Color(0x332678FF);

  // Tertiary (danger / decline)
  static const tertiary = Color(0xFFEF4444);

  // Background (pure/deep black #050505 - #080808)
  static const primaryBackground = Color(0xFF050505);
  static const secondaryBackground = Color(0xFF101114);
  static const surfaceVariant = Color(0xFF15171B);
  static const surface30 = Color(0x4D15171B);
  static const surface40 = Color(0x6615171B);
  static const surface20 = Color(0x3315171B);

  // Text (white primary, muted gray #8A8F98 secondary)
  static const primaryText = Colors.white;
  static const secondaryText = Color(0xFF8A8F98);
  static const accent3 = Color(0xFF6B7280);

  // Borders (1px hairline: rgba(255,255,255,0.08))
  static const alternate = Color(0x14FFFFFF);

  // Semantic (green #2ECC71 for safe, red #EF4444 for destructive)
  static const success = Color(0xFF2ECC71);
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);

  // Utility
  static const onSurface = Colors.white;
  static const fullContrast = Color(0x262678FF);
  static const onPrimaryContainer = Color(0xFFD6E4FF);
  static const onError = Colors.white;

  // Electric Blue Gradient & Glow
  static const electricBlueStart = Color(0xFF1455D9);
  static const electricBlueEnd = Color(0xFF2678FF);
  static const electricGradient = LinearGradient(
    colors: [electricBlueStart, electricBlueEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const electricGlow = Color(0x732678FF); // rgba(38,120,255,0.45)
}

class AppTextStyles {
  static const _fontFamily = 'Roboto';

  static TextStyle titleLarge = const TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryText,
    letterSpacing: 0.3,
    height: 1.3,
  );

  static TextStyle titleMedium = const TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryText,
    letterSpacing: 0.2,
    height: 1.4,
  );

  static TextStyle titleSmall = const TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryText,
    height: 1.4,
  );

  static TextStyle labelMedium = const TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryText,
    letterSpacing: 0.3,
    height: 1.3,
  );

  static TextStyle labelSmall = const TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.secondaryText,
    height: 1.2,
  );

  static TextStyle bodyMedium = const TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.primaryText,
    height: 1.5,
  );

  static TextStyle bodySmall = const TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.secondaryText,
    height: 1.4,
  );

  static TextStyle headlineSmall = const TextStyle(
    fontFamily: _fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryText,
    height: 1.3,
    letterSpacing: 0.5,
  );

  static TextStyle bodyLarge = const TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.primaryText,
    height: 1.6,
  );

  static TextStyle labelLarge = const TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryText,
    letterSpacing: 0.3,
  );
}

class AppRadius {
  static const small = 8.0;
  static const medium = 12.0;
  static const large = 20.0;
  static const full = 9999.0;
}

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}
