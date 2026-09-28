import 'package:flutter/widgets.dart';

/// Motion tokens.
///
/// All durations/curves live here. Prefer [durationOf] so the
/// reduced-motion system preference (or app setting) zeroes animations.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasize = Curves.easeOutBack;

  /// Duration honoring reduced-motion. Pass the widget's context (or
  /// MediaQueryData) — when animations are disabled, everything snaps.
  static Duration durationOf(BuildContext context, Duration normal) {
    return MediaQuery.maybeDisableAnimationsOf(context) == true
        ? Duration.zero
        : normal;
  }

  static Duration baseOf(BuildContext context) => durationOf(context, base);
  static Duration fastOf(BuildContext context) => durationOf(context, fast);
}
