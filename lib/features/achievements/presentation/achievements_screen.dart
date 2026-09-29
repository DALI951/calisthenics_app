import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_shell.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../workout_session/data/workout_history_repository.dart';
import '../../workout_session/domain/personal_records.dart';
import '../data/achievement_stats_provider.dart';
import '../data/achievements_providers.dart';
import '../domain/achievement.dart';
import '../domain/achievement_engine.dart';

/// Achievements + XP (spec §25/§26). Quiet, honest, training-driven.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(achievementStatsProvider);
    final unlocked = ref.watch(unlockedAchievementsProvider).value ?? const [];
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: const ShellAppBar(title: 'Achievements'),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Could not load stats.')),
        data: (stats) {
          final held = unlocked.map((u) => u.id).toSet();
          final totalXp =
              XpEngine.totalFromSessions(
                ref
                    .watch(workoutHistoryRepositoryProvider)
                    .value!
                    .map((s) => s.estimatedXp),
              ) +
              unlocked.fold<int>(0, (a, u) => a + u.xp);
          final level = XpEngine.levelForXp(totalXp);
          final list = AchievementEngine.visible(stats, held);

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              AppCard(
                highlight: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Level $level', style: AppTypography.title),
                        const Spacer(),
                        Text('$totalXp XP', style: AppTypography.body),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    LinearProgressIndicator(
                      value: XpEngine.levelProgress(totalXp),
                      color: AppColors.accentLight,
                      backgroundColor: AppColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(AppSpacing.xs),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${XpEngine.xpToNextLevel(totalXp)} XP to level ${level + 1} — '
                      'earned by training, not by opening the app.',
                      style: AppTypography.caption.copyWith(color: secondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '${held.length} of ${list.length} earned',
                style: AppTypography.bodySmall.copyWith(color: secondary),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final a in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _AchievementTile(
                    achievement: a,
                    unlocked: held.contains(a.id),
                    progress: AchievementEngine.progressOf(a, stats),
                    raw: a.progress(stats),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({
    required this.achievement,
    required this.unlocked,
    required this.progress,
    required this.raw,
  });

  final Achievement achievement;
  final bool unlocked;
  final double progress;
  final int raw;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return AppCard(
      child: Row(
        children: [
          Opacity(
            opacity: unlocked ? 1 : 0.4,
            child: Text(achievement.emoji, style: AppTypography.headline),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unlocked ? achievement.title : achievement.hint,
                  style: AppTypography.body.copyWith(
                    color: unlocked ? null : secondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                if (unlocked)
                  Text(
                    'Earned · +${achievement.xp} XP',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.success,
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: progress,
                          color: AppColors.surfaceRaised,
                          backgroundColor: AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(AppSpacing.xs),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        achievement.target >= 60
                            ? '${raw ~/ 60} min / '
                                  '${(achievement.target / 60).round()} min'
                            : '$raw / ${achievement.target}',
                        style: AppTypography.caption.copyWith(color: secondary),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (unlocked)
            Icon(Icons.check_circle, color: AppColors.success, size: 20)
          else if (achievement.hidden)
            Icon(Icons.lock_outline, color: secondary, size: 18),
        ],
      ),
    );
  }
}
