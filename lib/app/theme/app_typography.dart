import 'package:flutter/material.dart';

/// Typography tokens.
///
/// Hierarchy rule: max ~3 sizes per screen. Bold titles, semibold section
/// labels, gray body. Timer/stat numbers use tabular figures so digits do
/// not jitter while counting.
abstract final class AppTypography {
  static const TextStyle display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 1.15,
    letterSpacing: -0.5,
  );

  static const TextStyle headline = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.3,
  );

  static const TextStyle title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const TextStyle label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.2,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.6,
  );

  /// Big numbers (timers, PRs, reps). Tabular figures = no width jitter.
  static const TextStyle timerNumber = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w800,
    height: 1.0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle statNumber = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    height: 1.1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
