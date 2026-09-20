import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design-matching color palette based on screenshots
/// Premium dark-mode palette — deep navy/slate backgrounds, electric teal accent
class PgColors {
  // Backgrounds - Updated to match logo background color
  static const bgPrimary = Color(0xFF1A237E); // Dark blue (matching logo background)
  static const bgSecondary = Color(0xFF283593); // Slightly lighter card
  static const bgElevated = Color(0xFF3949AB); // Elevated content areas

  // Brand accent — electric teal/cyan
  static const accent = Color(0xFF00D4FF);
  static const accentDim = Color(0xFF0090B0);
  static const accentGlow = Color(0x3300D4FF); // 20% opacity glow

  // Semantic states
  // Electric Teal = Neutral Brand / System UI / AI Scambaiter
  // Green = Safe / Verified / Active only
  // Amber = Suspicious / Warning / Review only
  // Red = Scam / Danger / Critical Threat only
  static const safe = Color(0xFF22C55E); // Green
  static const safeDim = Color(0xFF166534);
  static const safeGlow = Color(0x4022C55E); // 25% glow
  static const suspicious = Color(0xFFF59E0B); // Amber
  static const suspiciousDim = Color(0xFF92400E);
  static const suspiciousGlow = Color(0x33F59E0B);
  static const scam = Color(0xFFEF4444); // Red
  static const scamDim = Color(0xFF991B1B);
  static const scamGlow = Color(0x40EF4444);

  // Hero Card Gradients & Glows
  static const heroCardGradient = [
    Color(0xFF112338),
    Color(0xFF0D1B2A),
    Color(0xFF0F2428),
  ];
  static const cyberCardGradient = [
    Color(0xFF131D31),
    Color(0xFF0F1726),
  ];

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

  // Legacy / backward-compat colors
  static const white = Color(0xFFFFFFFF);
  static const lightBlue = Color(0xFFC1E8FF);
  static const mediumBlue = Color(0xFF7DA0CA);
  static const accentBlue = Color(0xFF5483B3);
  static const primary = accentBlue;

  static const warn = Color(0xFFF4C95D);
  static const uncertain = Color(0xFFFFB020);      // amber
  static const uncertainGlow = Color(0x40FFB020);  // 25% opacity

  static const crit = Color(0xFFFF5D6C);
  static const criticalGlow = Color(0x40FF5D6C);   // pairs with existing `crit` (25% opacity)

  static const limited = Color(0xFF6B7280);        // muted grey, deliberately no glow

  static const dspAccent = Color(0xFF9D5CFF);      // purple, "AI/experimental" signal

  static const screenBottom = Color(0xFF010A18);

  // Surface layers (for glassmorphism card depth)
  static const surfaceGlass = Color(0x1AFFFFFF);   // 10% white, for frosted cards
  static const borderSubtle = Color(0x1AFFFFFF);   // hairline borders on glass cards

  static const screenGradient = [
    Color(0xFF00D4FF),
    Color(0xFF1E2A3A),
    Color(0xFF0A0F1E),
    Color(0xFF051018),
  ];

  static const primaryBtn = [Color(0xFFFF6B78), Color(0xFFFF4457)];
}

class PgType {
  // Display font: Poppins (already used in PgTheme.display) — headings, banners, buttons
  // Body font: Inter (already used in PgTheme.body) — paragraphs, labels
  // ADD a THIRD font role for technical readouts:
  static TextStyle mono({double size = 13, Color color = PgColors.lightBlue, FontWeight weight = FontWeight.w500}) =>
      GoogleFonts.jetBrainsMono(fontSize: size, color: color, fontWeight: weight);
  // Use PgType.mono() for: PDI scores, SHA-256 hashes, timestamps, phone numbers — anything numeric/technical.
}

class PgSpacing {
  static const xs = 4.0, sm = 8.0, md = 16.0, lg = 24.0, xl = 32.0, xxl = 48.0;
}

class PgRadius {
  static const card = 20.0, button = 14.0, chip = 100.0, bar = 8.0; // pill-shaped chips/badges + bar for pills
}

// Keeping old ones so app_theme.dart doesn't break if they were used elsewhere
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

  // Aliases for compatibility
  static const xs = 4.0;
  static const s = PgSpacing.sm;
  static const sm = 8.0;
  static const m = PgSpacing.md;
  static const md = 16.0;
  static const l = PgSpacing.lg;
  static const lg = 24.0;
  static const xl = PgSpacing.xl;
}

class PgAssets {
  static const String backgroundGif = 'assets/background.gif';
  static const String backgroundGifOriginal = 'assets/Loop Render GIF by xponentialdesign.gif';
}
