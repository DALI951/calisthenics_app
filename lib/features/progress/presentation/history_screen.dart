import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/pr_badge.dart';
import '../../workout_session/data/workout_history_repository.dart';
import '../../workout_session/domain/workout_session.dart';
import '../domain/records_engine.dart';

/// Which slice of history is shown (spec §17: today / week / month / all).
enum HistoryRange {
  today('Today'),
  week('This week'),
  month('This month'),
  all('All time');

  const HistoryRange(this.label);
  final String label;
}

/// Workout history (spec §17): filters, immutable records, PR badges,
/// read-only detail. Data comes from the local history repository — sync +
/// connected views arrive in Phase 11.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  HistoryRange _range = HistoryRange.all;

  @override
  Widget build(BuildContext context) {
    final history =
        ref.watch(workoutHistoryRepositoryProvider).value ?? const [];

    final filtered = _filter(history, _range);

    return Scaffold(
      appBar: AppBar(title: const Text('Workout history')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: SegmentedButton<HistoryRange>(
              segments: [
                for (final r in HistoryRange.values)
                  ButtonSegment(value: r, label: Text(r.label)),
              ],
              selected: {_range},
              onSelectionChanged: (s) => setState(() => _range = s.first),
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? AppEmptyState(
                    title: 'No workouts here yet',
                    message: _range == HistoryRange.all
                        ? 'Finish your first workout and it will show up here '
                              '— permanent and safe.'
                        : 'Nothing in this range. Switch filters or start a '
                              'workout.',
                    icon: Icons.history_rounded,
                    actionLabel: 'Start a workout',
                    onAction: () => context.go('/app/workouts'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) {
                      final s = filtered[i];
                      final prs = recordsForSession(history, s);
                      return _HistoryWorkoutCard(
                        session: s,
                        prCount: prs.length,
                        onTap: () => context.push(
                          '/app/progress/history/${s.id}',
                          extra: s,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<WorkoutSession> _filter(List<WorkoutSession> all, HistoryRange range) {
    switch (range) {
      case HistoryRange.today:
        final now = DateTime.now();
        final start = DateTime(now.year, now.month, now.day);
        return all.where((s) => s.startedAt.toLocal().isAfter(start)).toList();
      case HistoryRange.week:
        final now = DateTime.now();
        final monday = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));
        return all.where((s) => s.startedAt.toLocal().isAfter(monday)).toList();
      case HistoryRange.month:
        final now = DateTime.now();
        final first = DateTime(now.year, now.month, 1);
        return all.where((s) => s.startedAt.toLocal().isAfter(first)).toList();
      case HistoryRange.all:
        return all;
    }
  }
}

class _HistoryWorkoutCard extends StatelessWidget {
  const _HistoryWorkoutCard({
    required this.session,
    required this.prCount,
    required this.onTap,
  });

  final WorkoutSession session;
  final int prCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final d = session.duration(session.endedAt ?? session.startedAt);
    final minutes = d.inMinutes;
    final secs = d.inSeconds % 60;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(session.dayName, style: AppTypography.title),
              ),
              if (prCount > 0) ...[
                PrBadge(label: prCount == 1 ? 'New PR' : '$prCount new PRs'),
                const SizedBox(width: AppSpacing.sm),
              ],
              Icon(Icons.chevron_right, color: secondary),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            _dateLabel(session.startedAt),
            style: AppTypography.caption.apply(color: secondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _MiniStat(
                icon: Icons.schedule,
                label: minutes > 0 ? '$minutes min' : '${secs}s',
              ),
              const SizedBox(width: AppSpacing.md),
              _MiniStat(
                icon: Icons.fitness_center,
                label: '${session.completedSetCount} sets',
              ),
              const SizedBox(width: AppSpacing.md),
              _MiniStat(
                icon: Icons.repeat,
                label: session.totalReps > 0
                    ? '${session.totalReps} reps'
                    : session.totalSeconds > 0
                    ? '+${session.totalSeconds}s holds'
                    : '—',
              ),
            ],
          ),
          if (session.skippedSetCount > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${session.skippedSetCount} set(s) skipped',
              style: AppTypography.caption.apply(color: AppColors.warning),
            ),
          ],
        ],
      ),
    );
  }

  String _dateLabel(DateTime utc) {
    final l = utc.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(l.year, l.month, l.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${l.day}/${l.month}/${l.year}';
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: secondary),
        const SizedBox(width: AppSpacing.xxs),
        Text(label, style: AppTypography.bodySmall.apply(color: secondary)),
      ],
    );
  }
}
