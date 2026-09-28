import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';

/// Rest day view (spec §30): recovery matters — light activities, no
/// competitive scoring anywhere on rest days.
class RestDayScreen extends StatelessWidget {
  const RestDayScreen({super.key, this.dayNumber});

  final int? dayNumber;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('Rest day')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          const SizedBox(height: AppSpacing.md),
          const Icon(
            Icons.self_improvement,
            size: 72,
            color: AppColors.success,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('REST DAY', style: AppTypography.headline),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Recovery matters. Your muscles grow while you rest — '
            'today is part of the program.',
            style: AppTypography.body.apply(color: secondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Optional light activities', style: AppTypography.title),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Column(
              children: const [
                _RestActivity(
                  icon: Icons.directions_walk,
                  label: 'Easy walk — 15–30 minutes',
                ),
                _RestActivity(
                  icon: Icons.accessibility_new,
                  label: 'Gentle mobility',
                ),
                _RestActivity(
                  icon: Icons.self_improvement,
                  label: 'Easy stretching',
                ),
                _RestActivity(
                  icon: Icons.bedtime_outlined,
                  label: 'Sleep well — the next session will thank you',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'No challenges, no scores — just recovery.',
            style: AppTypography.bodySmall.apply(color: secondary),
          ),
        ],
      ),
    );
  }
}

class _RestActivity extends StatelessWidget {
  const _RestActivity({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.accentLight),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: AppTypography.body)),
        ],
      ),
    );
  }
}
