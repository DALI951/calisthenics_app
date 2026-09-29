import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../workouts/data/program_registry.dart';
import '../data/exercise_favorites.dart';
import '../data/exercise_library.dart';
import '../domain/exercise.dart';
import '../domain/exercise_enums.dart';
import 'quick_log_card.dart';

/// Polished exercise detail page (spec §13): everything about a movement,
/// plus a "Practice" mode that records nothing.
class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercise = ExerciseLibrary.byId(exerciseId);
    if (exercise == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Exercise')),
        body: const Center(child: Text('Exercise not found.')),
      );
    }

    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final favorites =
        ref.watch(exerciseFavoritesProvider).value ?? const <String>{};
    final isFavorite = favorites.contains(exercise.id);

    // Where this movement appears in the current program (recommended
    // sets/reps + rest come from the plan, so they never drift, §60).
    final plans = ProgramRegistry.beginner.days
        .where((d) => d.exercises.any((e) => e.exerciseId == exercise.id))
        .map(
          (d) =>
              (d, d.exercises.firstWhere((e) => e.exerciseId == exercise.id)),
        )
        .toList();

    ref.read(recentlyUsedExercisesProvider.notifier).record(exercise.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(exercise.name),
        actions: [
          IconButton(
            tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? AppColors.accent : null,
            ),
            onPressed: () => ref
                .read(exerciseFavoritesProvider.notifier)
                .toggle(exercise.id),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // He asked for this: do the movement and have it counted, without
          // having to squeeze it into a program day first.
          QuickLogCard(exercise: exercise),
          // Header row: category, difficulty, metric.
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              AppChip(
                label: exercise.category.label,
                icon: _categoryIcon(exercise.category),
              ),
              AppChip(label: '${exercise.difficulty.label} difficulty'),
              AppChip(
                label: exercise.metric == ExerciseMetric.time
                    ? 'Timed'
                    : 'Rep-based',
                icon: exercise.metric == ExerciseMetric.time
                    ? Icons.timer_outlined
                    : Icons.repeat,
              ),
              if (isFavorite)
                const AppChip(
                  label: 'Favorite',
                  accent: true,
                  icon: Icons.favorite,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // Target muscles + equipment.
          _Section(
            title: 'Target muscles',
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: exercise.muscleGroups
                  .map((m) => AppChip(label: m.label))
                  .toList(),
            ),
          ),
          _Section(
            title: 'Equipment',
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: exercise.equipment
                  .map(
                    (e) => AppChip(label: e.label, icon: Icons.home_outlined),
                  )
                  .toList(),
            ),
          ),

          // Plan targets if the movement is in the current program.
          if (plans.isNotEmpty) ...[
            _Section(
              title: 'Recommended in the program',
              child: Column(
                children: plans
                    .map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 16,
                              color: secondary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                '${p.$1.name}: ${p.$2.targetLabel}',
                                style: AppTypography.body,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          _Section(
            title: 'Rest between sets',
            child: Text(
              '${exercise.recommendedRestSeconds}s',
              style: AppTypography.body,
            ),
          ),

          // Practice mode — preview / try without recording (spec §13).
          AppCard(
            highlight: true,
            child: Row(
              children: [
                const Icon(
                  Icons.play_circle_outline,
                  color: AppColors.accentLight,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Practice mode — follow the cues below to try the '
                    'movement. Nothing is recorded.',
                    style: AppTypography.bodySmall.apply(color: secondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          _Section(
            title: 'Instructions',
            child: Column(
              children: List.generate(
                exercise.instructions.length,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.accentGlow,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${i + 1}',
                          style: AppTypography.caption.apply(
                            color: AppColors.accentLight,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          exercise.instructions[i],
                          style: AppTypography.body,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _Section(
            title: 'Technique checklist',
            child: Column(
              children: exercise.techniqueCues
                  .map(
                    (cue) => _CheckRow(
                      text: cue,
                      icon: Icons.check_circle_outline,
                      color: AppColors.success,
                    ),
                  )
                  .toList(),
            ),
          ),
          if (exercise.commonMistakes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            Text('Common mistakes', style: AppTypography.title),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                children: exercise.commonMistakes
                    .map(
                      (m) => _CheckRow(
                        text: m,
                        icon: Icons.error_outline,
                        color: AppColors.warning,
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          if (exercise.safetyNotes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            Text('Safety notes', style: AppTypography.title),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                children: exercise.safetyNotes
                    .map(
                      (s) => _CheckRow(
                        text: s,
                        icon: Icons.shield_outlined,
                        color: AppColors.accentLight,
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          if (exercise.prerequisites.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            Text('Prerequisites', style: AppTypography.title),
            const SizedBox(height: AppSpacing.sm),
            Text(
              exercise.prerequisites.join(' • '),
              style: AppTypography.bodySmall.apply(color: secondary),
            ),
          ],

          // Progression ladder (spec §10, §13).
          _Section(
            title: 'Progression',
            child: Column(
              children: [
                if (exercise.easierVariations.isNotEmpty)
                  _ProgressionLink(
                    direction: 'Easier',
                    ids: exercise.easierVariations,
                  ),
                const SizedBox(height: AppSpacing.sm),
                _ProgressionLink(
                  direction: 'Harder',
                  ids: exercise.harderVariations,
                  accent: true,
                ),
              ],
            ),
          ),
          if (exercise.tags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            Text('Tags', style: AppTypography.title),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: exercise.tags
                  .map((t) => AppChip(label: t.label))
                  .toList(),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  IconData _categoryIcon(ExerciseCategory c) {
    switch (c) {
      case ExerciseCategory.push:
        return Icons.fitness_center;
      case ExerciseCategory.pull:
        return Icons.arrow_upward;
      case ExerciseCategory.legs:
        return Icons.directions_walk;
      case ExerciseCategory.core:
        return Icons.accessibility_new;
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.title),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.text,
    required this.icon,
    required this.color,
  });

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: AppTypography.bodySmall)),
        ],
      ),
    );
  }
}

class _ProgressionLink extends ConsumerWidget {
  const _ProgressionLink({
    required this.direction,
    required this.ids,
    this.accent = false,
  });

  final String direction;
  final List<String> ids;
  final bool accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolved = ids
        .map((id) => ExerciseLibrary.byId(id))
        .whereType<Exercise>()
        .toList();
    if (resolved.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: resolved
            .map(
              (e) => ActionChip(
                avatar: Icon(
                  accent ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                ),
                label: Text('$direction: ${e.name}'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ExerciseDetailScreen(exerciseId: e.id),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

/// Empty state used by the library when filters match nothing.
class ExerciseLibraryEmpty extends StatelessWidget {
  const ExerciseLibraryEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppEmptyState(
      icon: Icons.search_off,
      title: 'No exercises match',
      message: 'Try clearing a filter, or search for another movement.',
    );
  }
}
