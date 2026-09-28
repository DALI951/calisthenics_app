import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_shell.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../exercises/data/exercise_library.dart';
import '../../workout_session/presentation/workout_session_controller.dart';
import '../../workouts/data/program_registry.dart';
import '../../workouts/domain/workout_program.dart';

/// Workouts tab: current program with a real START/RESUME action (spec §41
/// — the recommended action is obvious), this week with today highlighted,
/// and the exercise library entry.
class WorkoutsScreen extends ConsumerWidget {
  const WorkoutsScreen({super.key});

  void _startDay(BuildContext context, WidgetRef ref, ProgramDay day) {
    final ctrl = ref.read(workoutSessionControllerProvider.notifier);
    if (ref.read(workoutSessionControllerProvider) != null) {
      context.push('/app/workouts/session');
      return;
    }
    ctrl.start(ProgramRegistry.beginner, day);
    context.push('/app/workouts/session');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final program = ProgramRegistry.beginner;
    final todaySlot = DateTime.now().weekday;
    final today = program.dayAt(todaySlot);
    final isRestDay = today.type == ProgramDayType.rest;
    final activeSession = ref.watch(workoutSessionControllerProvider);
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
                      label: isRestDay ? 'Rest day' : 'Today: ${today.name}',
                      accent: !isRestDay,
                      icon: isRestDay
                          ? Icons.self_improvement
                          : Icons.fitness_center,
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
                if (activeSession != null) ...[
                  Text(
                    'Workout in progress — ${activeSession.dayName}',
                    style: AppTypography.bodySmall.apply(
                      color: AppColors.accentLight,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                FilledButton.icon(
                  onPressed: () => _startDay(context, ref, today),
                  icon: Icon(
                    activeSession != null
                        ? Icons.play_arrow
                        : isRestDay
                        ? Icons.self_improvement
                        : Icons.fitness_center,
                  ),
                  label: Text(
                    activeSession != null
                        ? 'Resume workout'
                        : isRestDay
                        ? 'View rest day'
                        : 'Start today\'s workout',
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
              child: _DayCard(
                day: day,
                isToday: day.dayNumber == todaySlot,
                onTap: () {
                  if (day.type == ProgramDayType.rest) {
                    context.push('/app/workouts/rest-day');
                  } else {
                    _startDay(context, ref, day);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.isToday,
    required this.onTap,
  });

  final ProgramDay day;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final isRest = day.type == ProgramDayType.rest;

    return AppCard(
      highlight: isToday && !isRest,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isRest) ...[
            const SizedBox(height: AppSpacing.xxs),
            const Icon(
              Icons.self_improvement,
              size: 20,
              color: AppColors.success,
            ),
            const SizedBox(height: AppSpacing.xxs),
          ],
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
