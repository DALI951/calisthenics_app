import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_shell.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../workout_session/data/workout_history_repository.dart';
import '../domain/records_engine.dart';

/// Progress tab. Phase 4: history-driven stats + records + entry points.
/// Phase 5 replaces the placeholder with fl_chart analytics + range select.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history =
        ref.watch(workoutHistoryRepositoryProvider).value ?? const [];

    final records = RecordsEngine.build(history);
    final withRecords = records.values.where((r) => r.bestSingle > 0).toList();

    // Training totals this week (Monday-start).
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final thisWeek = history.where(
      (s) => s.startedAt.toLocal().isAfter(monday),
    );
    final weekWorkouts = thisWeek.length;
    final weekMinutes = thisWeek.fold<int>(
      0,
      (a, s) => a + s.duration(s.endedAt ?? s.startedAt).inMinutes,
    );

    // Lifetime totals.
    final totalWorkouts = history.length;
    final totalMinutes = history.fold<int>(
      0,
      (a, s) => a + s.duration(s.endedAt ?? s.startedAt).inMinutes,
    );
    final totalReps = history.fold<int>(0, (a, s) => a + s.totalReps);

    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: ShellAppBar(title: 'Progress'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Row(
            children: [
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: _StatBlock(value: '$weekWorkouts', label: 'This week'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: _StatBlock(
                    value: _minutes(weekMinutes),
                    label: 'Trained',
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: _StatBlock(
                    value: '${withRecords.length}',
                    label: 'Exercises',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: _StatBlock(value: '$totalWorkouts', label: 'Workouts'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: _StatBlock(
                    value: _minutes(totalMinutes),
                    label: 'Time trained',
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: _StatBlock(value: '$totalReps', label: 'Reps'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppPrimaryButton(
            label: 'Workout history',
            icon: Icons.history_rounded,
            onPressed: () => context.go('/app/progress/history'),
          ),
          const SizedBox(height: AppSpacing.xl),

          if (history.isEmpty)
            const SizedBox(
              height: 320,
              child: AppEmptyState(
                title: 'No progress data yet',
                message:
                    'Charts for frequency, consistency and exercise '
                    'progression appear after your first workouts.',
                icon: Icons.insights_outlined,
              ),
            )
          else ...[
            Text('Personal records', style: AppTypography.title),
            const SizedBox(height: AppSpacing.sm),
            if (withRecords.isEmpty)
              const AppEmptyState(
                title: 'No records yet',
                message: 'Complete a workout to start tracking records.',
                icon: Icons.emoji_events_outlined,
              )
            else
              AppCard(
                child: Column(
                  children: [
                    for (final r in withRecords.take(8))
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xs,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              r.isTimed
                                  ? Icons.timer_outlined
                                  : Icons.fitness_center,
                              size: 16,
                              color: AppColors.accentLight,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                r.exerciseName,
                                style: AppTypography.body,
                              ),
                            ),
                            Text(
                              r.labelValue,
                              style: AppTypography.bodySmall.apply(
                                color: secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            if (withRecords.length > 8) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'and ${withRecords.length - 8} more…',
                style: AppTypography.caption.apply(color: secondary),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
          ],
        ],
      ),
    );
  }

  String _minutes(int m) =>
      m >= 60 ? '${(m / 60).toStringAsFixed(1)}h' : '${m}m';
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      children: [
        Text(value, style: AppTypography.statNumber),
        const SizedBox(height: AppSpacing.xxs),
        Text(label, style: AppTypography.caption.apply(color: secondary)),
      ],
    );
  }
}
