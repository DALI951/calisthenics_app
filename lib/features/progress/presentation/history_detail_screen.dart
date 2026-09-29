import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/pr_badge.dart';
import '../../workout_session/data/workout_history_repository.dart';
import '../../workout_session/domain/personal_records.dart';
import '../../workout_session/domain/set_entry.dart';

/// Read-only view of ONE historical workout (spec §17: open a historical
/// workout — never modify it; §60 immutability).
class HistoryDetailScreen extends ConsumerWidget {
  const HistoryDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history =
        ref.watch(workoutHistoryRepositoryProvider).value ?? const [];
    final session = history
        .where((s) => s.id == sessionId)
        .toList()
        .firstOrNull;

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Workout')),
        body: const AppEmptyState(
          title: 'Workout not found',
          message: 'This record is not available anymore.',
          icon: Icons.search_off,
        ),
      );
    }

    final recordsForThis = <PersonalRecord>[];
    {
      final prior = history
          .where(
            (s) =>
                s.id != session.id && s.startedAt.isBefore(session.startedAt),
          )
          .toList();
      recordsForThis.addAll(WorkoutPrDetector(prior).detect(session));
    }

    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final d = session.duration(session.endedAt ?? session.startedAt);

    return Scaffold(
      appBar: AppBar(title: Text(session.dayName)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.dayName, style: AppTypography.title),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${_dateLabel(session.startedAt)} • '
                  '${d.inMinutes} min ${d.inSeconds % 60}s • '
                  '${session.completedSetCount} sets',
                  style: AppTypography.caption.apply(color: secondary),
                ),
                if (recordsForThis.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xxs,
                    children: [
                      for (final r in recordsForThis) PrBadge(label: r.display),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final ex in session.exercises) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(ex.name, style: AppTypography.title),
                      ),
                      Text(
                        ex.targetLabel,
                        style: AppTypography.caption.apply(color: secondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final set in session.setsFor(ex.exerciseId))
                    _SetRow(set: set),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }

  String _dateLabel(DateTime utc) {
    final l = utc.toLocal();
    return '${l.day}/${l.month}/${l.year}';
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({required this.set});

  final SetEntry set;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final value = set.seconds != null ? '${set.seconds}s' : '${set.reps}';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              'Set ${set.setNumber}',
              style: AppTypography.bodySmall.apply(color: secondary),
            ),
          ),
          Expanded(
            child: Text(
              set.skipped
                  ? 'Skipped'
                  : set.painReported
                  ? 'Stopped (pain noted)'
                  : value + (set.assistedReps > 0 ? ' (assisted)' : ''),
              style: AppTypography.body.apply(
                color: set.painReported
                    ? AppColors.warning
                    : set.skipped
                    ? secondary
                    : null,
              ),
            ),
          ),
          if (set.note != null)
            Icon(Icons.sticky_note_2_outlined, size: 14, color: secondary),
        ],
      ),
    );
  }
}
