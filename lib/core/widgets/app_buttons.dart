import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// Primary action button (solid red). Consistent 48px touch target.
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: (loading || onPressed == null) ? null : onPressed,
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Text(label),
              ],
            ),
    );
  }
}

/// Secondary action button (hairline outline).
class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(label),
        ],
      ),
    );
  }
}

/// Compact full-width row of primary+secondary actions (bottom sheets etc.).
class ButtonRow extends StatelessWidget {
  const ButtonRow({
    super.key,
    required this.primaryLabel,
    this.onPrimary,
    this.onSecondary,
    this.loading = false,
  });

  final String primaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onSecondary != null)
          Expanded(
            child: AppSecondaryButton(label: 'Cancel', onPressed: onSecondary),
          ),
        if (onSecondary != null) const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 2,
          child: AppPrimaryButton(
            label: primaryLabel,
            onPressed: onPrimary,
            loading: loading,
          ),
        ),
      ],
    );
  }
}

/// Inline status text for validator errors without cluttering forms.
class FormErrorText extends StatelessWidget {
  const FormErrorText({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.danger),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySmall.apply(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
