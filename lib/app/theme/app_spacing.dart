/// Spacing tokens — strict 4px grid.
///
/// Use these everywhere; never hardcode 13, 17, 31... px.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Standard card-to-card gap on phone screens.
  static const double cardGap = md;

  /// Standard screen padding on phones.
  static const double screenPadding = lg;
}
