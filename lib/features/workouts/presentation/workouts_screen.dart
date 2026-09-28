import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_shell.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../exercises/data/exercise_library.dart';
import '../../workouts/data/program_registry.dart';
import '../../workouts/domain/workout_program.dart';

/// Workouts tab: current program, today highlighted, full week, exercise
/// library entry. The recorded workout mode (sets, rest timer, summary)
/// replaces the availability card in Phase 3.
class WorkoutsScreen extends ConsumerWidget {
  const WorkoutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final program = ProgramRegistry.beginner;
    final todaySlot = DateTime.now().weekday;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: ShellAppBar(title: 'Workouts'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppCard(
            highlight: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppChip(
                      label: 'Program',
                      accent: true,
                      icon: Icons.fitness_center,
                    ),
                    const Spacer(),
                    Text(
                      'v${program.version}',
                      style: AppTypography.caption.apply(color: secondary),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(program.name, style: AppTypography.title),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  program.description ?? '',
                  style: AppTypography.bodySmall.apply(color: secondary),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Honest availability marker (spec §81: no dead buttons).
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 18,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Recorded workout mode (sets, rest timer, summary) '
                          'ships in the next build phase.',
                          style: AppTypography.bodySmall.apply(
                            color: secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(
            title: 'Exercise library',
            actionLabel: 'Open',
            onAction: () => context.push('/app/workouts/exercises'),
          ),
          AppCard(
            onTap: () => context.push('/app/workouts/exercises'),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.menu_book_outlined,
                    color: AppColors.accentLight,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${ExerciseLibrary.all.length} movements',
                        style: AppTypography.body,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Search, filter by muscle & gear, technique cues, '
                        'progressions, favorites.',
                        style: AppTypography.caption.apply(color: secondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(title: 'This week'),
          ...program.days.map(
            (day) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _DayCard(day: day, isToday: day.dayNumber == todaySlot),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.isToday});

  final ProgramDay day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final isRest = day.type == ProgramDayType.rest;

    return AppCard(
      highlight: isToday && !isRest,
      onTap: null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Day ${day.dayNumber}',
                style: AppTypography.label.apply(
                  color: isToday ? AppColors.accentLight : secondary,
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: AppSpacing.sm),
                AppChip(label: 'Today', accent: true),
              ],
              if (isRest) ...[
                const Spacer(),
                AppChip(label: 'Rest', icon: Icons.self_improvement),
              ] else ...[
                const Spacer(),
                AppChip(
                  label: '${day.exercises.length} moves',
                  icon: Icons.fitness_center,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            day.name,
            style: AppTypography.title.copyWith(
              fontSize: 17,
              color: isRest
                  ? secondary
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (day.focus != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              day.focus!,
              style: AppTypography.caption.apply(color: secondary),
            ),
          ],
          if (!isRest && day.exercises.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: day.exercises
                  .map(
                    (e) => ActionChip(
                      label: Text(
                        '${ExerciseLibrary.byId(e.exerciseId)?.name ?? e.exerciseId}: ${e.targetLabel}',
                      ),
                      visualDensity: VisualDensity.compact,
                      labelStyle: AppTypography.bodySmall.apply(
                        color: secondary,
                      ),
                      onPressed: () => context.push(
                        '/app/workouts/exercises/${e.exerciseId}',
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
