import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_shell.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';

/// Progress tab. Charts arrive with data in Phase 5 (spec §19) — the layout
/// slots are already defined so the phase drops in without redesign.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: ShellAppBar(title: 'Progress'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Weekly overview slot (Phase 5)
          Row(
            children: [
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: StatBlock(value: '0', label: 'This week'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: StatBlock(value: '0h 0m', label: 'Trained'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: StatBlock(value: '0', label: 'PRs'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const SizedBox(
            height: 380,
            child: AppEmptyState(
              title: 'No progress data yet',
              message:
                  'Charts for frequency, consistency and exercise progression '
                  'appear after your first workouts. Favorite stats: '
                  'weekly consistency, training time, PR timeline.',
              icon: Icons.insights_outlined,
            ),
          ),
        ],
      ),
    );
  }
}
