import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_motion.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Builds the app ThemeData (Material 3) from color tokens.
///
/// Dark-first product look; light theme is a first-class accessibility
/// alternative via the theme toggle.
abstract final class AppTheme {
  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    background: AppColors.bg,
    surface: AppColors.surface,
    surfaceHigh: AppColors.surfaceHigh,
    surfaceRaised: AppColors.surfaceRaised,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    hairline: AppColors.hairline,
  );

  static ThemeData light() => _build(
    brightness: Brightness.light,
    background: AppColors.lightBg,
    surface: AppColors.lightSurface,
    surfaceHigh: AppColors.lightSurfaceHigh,
    surfaceRaised: AppColors.lightSurface,
    textPrimary: AppColors.lightTextPrimary,
    textSecondary: AppColors.lightTextSecondary,
    hairline: AppColors.lightHairline,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color surfaceHigh,
    required Color surfaceRaised,
    required Color textPrimary,
    required Color textSecondary,
    required Color hairline,
  }) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      secondary: AppColors.accentLight,
      onSecondary: AppColors.onAccent,
      error: AppColors.danger,
      onError: brightness == Brightness.dark ? AppColors.bg : Colors.white,
      surface: surface,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      surfaceContainerHighest: surfaceHigh,
      outline: hairline,
      outlineVariant: hairline,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamilyFallback: const ['Roboto'],
    );

    return base.copyWith(
      textTheme: base.textTheme
          .copyWith(
            displayLarge: AppTypography.display,
            headlineLarge: AppTypography.display,
            headlineMedium: AppTypography.headline,
            titleLarge: AppTypography.title,
            titleMedium: AppTypography.label.copyWith(fontSize: 16),
            bodyLarge: AppTypography.bodyLarge,
            bodyMedium: AppTypography.body,
            bodySmall: AppTypography.bodySmall,
            labelLarge: AppTypography.label,
            labelMedium: AppTypography.caption.copyWith(fontSize: 12),
          )
          .apply(bodyColor: textPrimary, displayColor: textPrimary),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.title.apply(color: textPrimary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.35),
          disabledForegroundColor: AppColors.onAccent.withValues(alpha: 0.7),
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTypography.label,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: hairline),
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTypography.label,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentLight,
          minimumSize: const Size(48, 40),
          textStyle: AppTypography.label,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        hintStyle: AppTypography.body.apply(color: textSecondary),
        labelStyle: AppTypography.body.apply(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: AppColors.accentGlow,
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(
          AppTypography.caption.apply(color: textSecondary),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.accentLight
                : textSecondary,
            size: 24,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: hairline),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surfaceHigh,
        side: BorderSide(color: hairline),
        labelStyle: AppTypography.label.apply(color: textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: hairline,
        thickness: 1,
        space: AppSpacing.lg,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceRaised,
        contentTextStyle: AppTypography.body.apply(color: textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: hairline),
        ),
      ),
      splashFactory: InkSparkle.splashFactory,
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: surfaceHigh,
        circularTrackColor: surfaceHigh,
      ),
      dividerColor: hairline,
    );
  }

  /// Shared easing used by flutter_animate calls in screens.
  static final animationCurve = AppMotion.standard;
}
