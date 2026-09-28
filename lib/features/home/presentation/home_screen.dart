import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_shell.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../auth/data/auth_providers.dart';
import '../../exercises/data/exercise_library.dart';
import '../../workouts/data/program_registry.dart';
import '../../workouts/domain/workout_program.dart';

/// Home answers: "What should I do today?"
///
/// Greeting → streak → today's plan → open plan → friend activity.
/// Deliberately not overloaded (spec §40).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Still up?';
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  String _exerciseName(String id) => ExerciseLibrary.byId(id)?.name ?? id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final today = ProgramRegistry.beginner.dayAt(DateTime.now().weekday);
    final isRestDay = today.type == ProgramDayType.rest;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: ShellAppBar(title: 'Calisthenics'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            '${_greeting()}, ${user?.displayLabel ?? 'athlete'}',
            style: AppTypography.headline,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'One workout at a time. Today: ${today.name}.',
            style: AppTypography.body.apply(color: secondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Today's plan card
          AppCard(
            highlight: !isRestDay,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppChip(
                      label: isRestDay ? 'Rest day' : today.focus ?? today.name,
                      accent: !isRestDay,
                      icon: isRestDay ? Icons.self_improvement : Icons.bolt,
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  today.name,
                  style: AppTypography.title.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (today.note != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    today.note!,
                    style: AppTypography.bodySmall.apply(color: secondary),
                  ),
                ],
                if (!isRestDay && today.exercises.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  ...today.exercises
                      .take(3)
                      .map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                size: 16,
                                color: AppColors.accentLight,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  e.targetLabel,
                                  style: AppTypography.bodySmall,
                                ),
                              ),
                              Text(
                                _exerciseName(e.exerciseId),
                                style: AppTypography.label.apply(
                                  color: secondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
                const SizedBox(height: AppSpacing.lg),
                FilledButton.tonalIcon(
                  onPressed: () => context.go('/app/workouts'),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Open today\'s plan'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Quick stats row
          Row(
            children: [
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: StatBlock(value: '0', label: 'Day streak'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: StatBlock(value: '0', label: 'Workouts'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: StatBlock(value: 'Lv 1', label: 'Level'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Friend activity (spec §40) — honest empty state until friends land.
          AppCard(
            child: Row(
              children: [
                const Icon(
                  Icons.people_outline,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'No training partners yet. Friends arrive in Phase 6 — '
                    'then you\'ll see live activity here.',
                    style: AppTypography.bodySmall.apply(color: secondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
