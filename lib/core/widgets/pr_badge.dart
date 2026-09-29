import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// Compact "PR" chip used on workout cards, history and lists (spec §39
/// PRBadge). Purely presentational.
class PrBadge extends StatelessWidget {
  const PrBadge({super.key, this.label = 'PR', this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.xs : AppSpacing.sm,
        vertical: compact ? 2 : AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentGlow,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: compact ? 12 : 14,
            color: AppColors.accentLight,
          ),
          if (!compact) const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.accentLight,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
