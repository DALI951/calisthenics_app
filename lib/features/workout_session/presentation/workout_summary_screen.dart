import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_card.dart';
import '../data/workout_history_repository.dart';
import '../domain/personal_records.dart';
import '../domain/workout_session.dart';
import 'workout_session_controller.dart';

/// Post-workout summary (spec §16): duration, exercises, sets, reps, holds,
/// XP, personal records (vs all prior sessions), encouraging comparisons.
class WorkoutSummaryScreen extends ConsumerWidget {
  const WorkoutSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The finished session is passed as route extra; fall back to provider.
    final session =
        GoRouterState.of(context).extra as WorkoutSession? ??
        ref.watch(lastCompletedSessionProvider);

    final history =
        ref.watch(workoutHistoryRepositoryProvider).value ?? const [];
    final prior = history
        .where(
          (s) =>
              s.id != session?.id &&
              s.startedAt.isBefore(session?.startedAt ?? DateTime.utc(3000)),
        )
        .toList();
    final records = session == null
        ? const <PersonalRecord>[]
        : WorkoutPrDetector(prior).detect(session);

    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final duration = session?.duration(DateTime.now()) ?? Duration.zero;
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Summary'),
        automaticallyImplyLeading: false,
      ),
      body: session == null
          ? const Center(child: Text('No workout to summarize.'))
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                // Hero moment.
                AppCard(
                  highlight: true,
                  child: Column(
                    children: [
                      const Icon(
                        Icons.emoji_events_outlined,
                        size: 48,
                        color: AppColors.accentLight,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Workout completed', style: AppTypography.title),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '${session.dayName} • ${_dateLabel(session.startedAt)}',
                        style: AppTypography.caption.apply(color: secondary),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _Stat(
                            label: 'Duration',
                            value: minutes > 0 ? '$minutes min' : '${seconds}s',
                          ),
                          _Stat(
                            label: 'Exercises',
                            value: '${session.exercises.length}',
                          ),
                          _Stat(
                            label: 'Sets',
                            value: '${session.completedSetCount}',
                          ),
                          _Stat(
                            label: 'Reps',
                            value: session.isComplete
                                ? '${session.totalReps}'
                                : '${session.totalReps}',
                          ),
                        ],
                      ),
                      if (session.totalSeconds > 0) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '+ ${session.totalSeconds}s of timed holds',
                          style: AppTypography.caption.apply(color: secondary),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // XP (deterministic, §26).
                AppCard(
                  child: Row(
                    children: [
                      const Icon(Icons.bolt, color: AppColors.warning),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Workout complete',
                          style: AppTypography.body,
                        ),
                      ),
                      Text(
                        '+${session.estimatedXp} XP',
                        style: AppTypography.title.apply(
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),

                // Personal records (§16, §18).
                if (records.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.flag,
                              size: 18,
                              color: AppColors.accentLight,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'New personal records',
                              style: AppTypography.title,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ...records.map(
                          (r) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  size: 18,
                                  color: AppColors.success,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    '${r.kindLabel}: ${r.display}',
                                    style: AppTypography.body,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Encouraging comparison (spec §16, never shaming §27).
                if (prior.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Compared with your last ${session.dayName}',
                          style: AppTypography.title,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        _ComparisonTile(
                          label: 'Total sets',
                          delta:
                              session.completedSetCount -
                              prior.first.completedSetCount,
                        ),
                        _ComparisonTile(
                          label: 'Total reps',
                          delta: session.totalReps - prior.first.totalReps,
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),
                AppPrimaryButton(
                  label: 'Done',
                  icon: Icons.done,
                  onPressed: () => context.go('/app/workouts'),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
    );
  }

  String _dateLabel(DateTime utc) {
    final local = utc.toLocal();
    final now = DateTime.now();
    final sameDay =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (sameDay) return 'Today';
    return '${local.day}/${local.month}/${local.year}';
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      children: [
        Text(value, style: AppTypography.title),
        const SizedBox(height: AppSpacing.xxs),
        Text(label, style: AppTypography.caption.apply(color: secondary)),
      ],
    );
  }
}

class _ComparisonTile extends StatelessWidget {
  const _ComparisonTile({required this.label, required this.delta});

  final String label;
  final int delta;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final color = delta > 0
        ? AppColors.success
        : delta == 0
        ? secondary
        : AppColors.warning;
    final icon = delta > 0
        ? Icons.trending_up
        : delta == 0
        ? Icons.trending_flat
        : Icons.trending_down;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: AppTypography.bodySmall)),
          Text(
            delta == 0
                ? 'same as last time'
                : '${delta.abs()} ${delta > 0 ? 'more' : 'fewer'} than last',
            style: AppTypography.bodySmall.apply(color: color),
          ),
        ],
      ),
    );
  }
}
