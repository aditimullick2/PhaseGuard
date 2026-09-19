import 'package:flutter/material.dart';

/// Design-matching color palette based on screenshots
/// Premium dark-mode palette — deep navy/slate backgrounds, electric teal accent
class PgColors {
  // Backgrounds
  static const bgPrimary = Color(0xFF0A0F1E); // Very deep navy
  static const bgSecondary = Color(0xFF111827); // Slightly lighter card
  static const bgElevated = Color(0xFF1E2A3A); // Elevated content areas

  // Brand accent — electric teal/cyan
  static const accent = Color(0xFF00D4FF);
  static const accentDim = Color(0xFF0090B0);
  static const accentGlow = Color(0x3300D4FF); // 20% opacity glow

  // Semantic states
  static const safe = Color(0xFF22C55E); // Green
  static const safeDim = Color(0xFF166534);
  static const suspicious = Color(0xFFF59E0B); // Amber
  static const suspiciousDim = Color(0xFF92400E);
  static const scam = Color(0xFFEF4444); // Red
  static const scamDim = Color(0xFF991B1B);
  static const scamGlow = Color(0x40EF4444);

  // Text
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF475569);

  // Waveform bars
  static const waveformActive = Color(0xFF00D4FF);
  static const waveformInactive = Color(0xFF1E3A4A);

  // Borders
  static const border = Color(0xFF1E2D45);
  static const borderAccent = Color(0xFF0A4D68);

  // Glass effects
  static const glassBg = Color.fromRGBO(0, 212, 255, 0.05);
  static const glassBgStrong = Color.fromRGBO(0, 212, 255, 0.08);
  static const glassBorder = Color.fromRGBO(0, 212, 255, 0.14);

  // Legacy colors (for backward compatibility)
  static const white = Color(0xFFFFFFFF);
  static const lightBlue = Color(0xFFC1E8FF);
  static const mediumBlue = Color(0xFF7DA0CA);
  static const accentBlue = Color(0xFF5483B3);
  static const warn = Color(0xFFF4C95D);
  static const crit = Color(0xFFFF5D6C);
  static const screenBottom = Color(0xFF010A18);

  static const screenGradient = [
    Color(0xFF00D4FF),
    Color(0xFF1E2A3A),
    Color(0xFF0A0F1E),
    Color(0xFF051018),
  ];

  static const primaryBtn = [Color(0xFFFF6B78), Color(0xFFFF4457)];
}

class PgRadii {
  static const glass = 22.0;
  static const pill = 999.0;
  static const nav = 26.0;
  static const icon = 10.0;
  static const bar = 4.0;
  static const card = 16.0;
  static const button = 16.0;
}

class PgSpace {
  static const screenH = 20.0;
  static const section = 28.0;
  static const titleGap = 14.0;
  static const navBottom = 120.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}
