import 'package:flutter/material.dart';

/// Calisthenics color tokens.
///
/// Design language (see .opencode/skills/fitness-ui): dark cinema first,
/// near-black surfaces, ONE red accent, neutral grays, hairline borders.
/// Light theme exists for accessibility but dark is the product look.
///
/// NEVER scatter raw colors in widgets — reference these tokens only.
abstract final class AppColors {
  // ---- Dark palette (default) -----------------------------------------
  static const Color bg = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF12121A);
  static const Color surfaceHigh = Color(0xFF171722);
  static const Color surfaceRaised = Color(0xFF1C1C28);

  static const Color textPrimary = Color(0xFFF2F2F5);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textDisabled = Color(0xFF55555F);

  /// Hairline borders: white at 8% over any surface.
  static const Color hairline = Color(0x14FFFFFF);
  static const Color hairlineStrong = Color(0x26FFFFFF);

  // ---- Accent (the ONE accent) -----------------------------------------
  static const Color accent = Color(0xFFDC2626);
  static const Color accentDark = Color(0xFFB91C1C);
  static const Color accentLight = Color(0xFFEF4444);

  /// Accent glow wash (rgba(239,68,68,0.15) equivalent).
  static const Color accentGlow = Color(0x26EF4444);
  static const Color onAccent = Colors.white;

  // ---- Semantic (used sparingly, never color-only) ---------------------
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFF87171);
  static const Color info = Color(0xFF60A5FA);

  // ---- Light palette -----------------------------------------------------
  static const Color lightBg = Color(0xFFF5F5F6);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceHigh = Color(0xFFECECF1);
  static const Color lightTextPrimary = Color(0xFF111113);
  static const Color lightTextSecondary = Color(0xFF52525B);
  static const Color lightHairline = Color(0x14000000);

  // ---- Chart palette (fl_chart) ------------------------------------------
  static const List<Color> chartSeries = [
    accentLight,
    Color(0xFFF87171),
    Color(0xFFFDA4AF),
    Color(0xFFFBCFE8),
  ];
}
