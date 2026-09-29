import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../challenges/data/challenges_providers.dart';
import '../../challenges/domain/challenge.dart';
import '../../progress/domain/streak_calculator.dart';
import '../../workout_session/data/workout_history_repository.dart';
import '../../workout_session/domain/workout_session.dart';
import '../domain/achievement.dart';

part 'achievement_stats_provider.g.dart';

/// Everything the achievement engine needs, derived ONLY from training data
/// (spec §26). App opens, screen time and taps are deliberately ignored.
@Riverpod(keepAlive: true)
Future<AchievementStats> achievementStats(Ref ref) async {
  final history =
      ref.watch(workoutHistoryRepositoryProvider).value ??
      const <WorkoutSession>[];
  final challenges =
      ref.watch(myChallengesProvider).value ?? const <Challenge>[];

  var sets = 0;
  var pullups = 0;
  var pushups = 0;
  var plank = 0;
  final exerciseIds = <String>{};

  for (final session in history) {
    for (final entry in session.sets) {
      if (entry.skipped || !entry.countsTowardRecords) continue;
      sets++;
      exerciseIds.add(entry.exerciseId);
      final name = entry.exerciseId.toLowerCase();
      final reps = entry.reps ?? 0;
      final seconds = entry.seconds ?? 0;
      if (name.contains('pull')) {
        if (reps > pullups) pullups = reps;
      } else if (name.contains('push')) {
        if (reps > pushups) pushups = reps;
      }
      if (name.contains('plank') && seconds > plank) plank = seconds;
    }
  }

  final streak = StreakCalculator.summary(history, DateTime.now());
  final completedChallenges = challenges
      .where((c) => c.status == ChallengeStatus.completed)
      .length;

  return AchievementStats(
    workoutsCompleted: history.length,
    setsCompleted: sets,
    challengesCompleted: completedChallenges,
    challengesStarted: challenges.length,
    currentStreak: streak.current,
    longestStreak: streak.longest,
    bestPullups: pullups,
    bestPushups: pushups,
    bestPlankSeconds: plank,
    exercisesLearned: exerciseIds.length,
  );
}
