/// PhaseGuard Design System
/// All color, typography, and spacing tokens used across the app.
library app_theme;

import 'package:flutter/material.dart';

class AppColors {
  // Primary palette
  static const primary = Color(0xFF6C63FF);
  static const primaryDark = Color(0xFF4F46E5);
  static const primaryLight = Color(0xFF9C59FF);
  static const onPrimary = Colors.white;
  static const primary10 = Color(0x1A6C63FF);
  static const primary20 = Color(0x336C63FF);
  static const onPrimary10 = Color(0x1AFFFFFF);

  // Secondary
  static const secondary = Color(0xFF9C59FF);
  static const onSecondary = Colors.white;
  static const secondary20 = Color(0x339C59FF);

  // Tertiary (danger / decline)
  static const tertiary = Color(0xFFEF4444);

  // Background
  static const primaryBackground = Color(0xFF0F0E1A);
  static const secondaryBackground = Color(0xFF1E1D2E);
  static const surfaceVariant = Color(0xFF252438);
  static const surface30 = Color(0x4D252438);
  static const surface40 = Color(0x66252438);
  static const surface20 = Color(0x33252438);

  // Text
  static const primaryText = Colors.white;
  static const secondaryText = Color(0xFF9A97C5);
  static const accent3 = Color(0xFF6A6890);

  // Borders
  static const alternate = Color(0xFF3D3B5E);

  // Semantic
  static const success = Color(0xFF4ADE80);
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);

  // Utility
  static const onSurface = Colors.white;
  static const fullContrast = Color(0x266C63FF);
  static const onPrimaryContainer = Color(0xFFE0DEFF);
  static const onError = Colors.white;
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
