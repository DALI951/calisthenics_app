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
import '../../progress/domain/streak_calculator.dart';
import '../../workout_session/data/workout_history_repository.dart';
import '../../workout_session/domain/personal_records.dart';
import '../../workout_session/presentation/workout_session_controller.dart';
import '../../../core/widgets/sync_status_chip.dart';
import '../../../core/widgets/update_banner.dart';
import '../../workouts/data/program_registry.dart';
import '../../workouts/domain/workout_program.dart';

/// Home answers: "What should I do today?" (spec §40).
///
/// Greeting → streak → today's workout with a real START button →
/// quick stats → friend activity (honest empty state until Phase 6).
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

    final activeSession = ref.watch(workoutSessionControllerProvider);
    final history =
        ref.watch(workoutHistoryRepositoryProvider).value ?? const [];
    final streak = StreakCalculator.currentStreak(history, DateTime.now());
    final totalXp = history.fold(
      0,
      (a, s) => a + s.estimatedXp,
    ); // Phase 10 real levels

    void startToday() {
      final ctrl = ref.read(workoutSessionControllerProvider.notifier);
      if (activeSession != null) {
        context.push('/app/workouts/session');
        return;
      }
      ctrl.start(ProgramRegistry.beginner, today);
      context.push('/app/workouts/session');
    }

    return Scaffold(
      appBar: const ShellAppBar(title: 'Calisthenics'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const Align(alignment: Alignment.centerLeft, child: SyncStatusChip()),
          const UpdateBanner(),
          Text(
            '${_greeting()}, ${user?.displayLabel ?? 'athlete'}',
            style: AppTypography.headline,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            activeSession != null
                ? 'You have a workout in progress — pick up where you left off.'
                : 'One workout at a time. Today: ${today.name}.',
            style: AppTypography.body.apply(color: secondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Today's plan card — the single recommended action (spec §40, §41).
          AppCard(
            highlight: !isRestDay,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppChip(
                      label: isRestDay
                          ? 'Rest day'
                          : activeSession != null
                          ? 'In progress'
                          : today.focus ?? today.name,
                      accent: !isRestDay && activeSession == null,
                      icon: activeSession != null
                          ? Icons.play_circle_outline
                          : isRestDay
                          ? Icons.self_improvement
                          : Icons.bolt,
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
                FilledButton.icon(
                  onPressed: startToday,
                  icon: Icon(
                    activeSession != null
                        ? Icons.play_arrow
                        : isRestDay
                        ? Icons.self_improvement
                        : Icons.play_arrow,
                  ),
                  label: Text(
                    activeSession != null
                        ? 'Resume workout'
                        : isRestDay
                        ? 'See today\'s recovery'
                        : 'Start today\'s workout',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Quick stats row (real values from history).
          Row(
            children: [
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: StatBlock(value: '$streak', label: 'Day streak'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: StatBlock(
                    value: '${history.length}',
                    label: 'Workouts',
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: StatBlock(
                    value: 'Lv ${LevelForXp.levelFor(totalXp)}',
                    label: 'Level ($totalXp XP)',
                  ),
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

/// Minimal level curve (Phase 10 fleshes out achievements/XP fully).
abstract final class LevelForXp {
  static int levelFor(int xp) {
    if (xp < 0) return 1;
    // 100 XP per level, gentle curve.
    return (xp ~/ 100) + 1;
  }
}
