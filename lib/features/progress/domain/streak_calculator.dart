import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

import '../../workout_session/domain/workout_session.dart';

part 'streak_calculator.freezed.dart';
part 'streak_calculator.g.dart';

/// A training streak — encourages consistency WITHOUT shaming (spec §27):
/// planned rest days never break it because streaks count consecutive
/// TRAINING days with workouts, not calendar days.
@freezed
abstract class StreakSummary with _$StreakSummary {
  const factory StreakSummary({
    /// Consecutive training days ending today or yesterday (so a rest day
    /// today doesn't break the streak).
    required int current,

    /// Longest streak ever seen in this history.
    required int longest,
  }) = _StreakSummary;

  const StreakSummary._();

  factory StreakSummary.fromJson(Map<String, Object?> json) =>
      _$StreakSummaryFromJson(json);
}

/// Pure, deterministic streak math (unit-tested, spec §69: timezone-safe —
/// work in LOCAL calendar days derived from UTC stored timestamps).
abstract final class StreakCalculator {
  /// Training day dates (local) that have at least one completed workout.
  static Set<DateTime> _trainingDays(List<WorkoutSession> history) {
    final days = <DateTime>{};
    for (final s in history) {
      final local = s.startedAt.toLocal();
      days.add(DateTime(local.year, local.month, local.day));
    }
    return days;
  }

  static bool _hasWorkoutOn(List<WorkoutSession> history, DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return history.any((s) {
      final local = s.startedAt.toLocal();
      return !local.isBefore(dayStart) && local.isBefore(dayEnd);
    });
  }

  static int _consecutiveBackFrom(
    List<WorkoutSession> history,
    DateTime day, {
    required bool allowGapToday,
  }) {
    var cursor = DateTime(day.year, day.month, day.day);
    if (!_hasWorkoutOn(history, cursor)) {
      if (!allowGapToday) return 0;
      // Today is a (planned) rest/gap day — check from yesterday.
      cursor = cursor.subtract(const Duration(days: 1));
      if (!_hasWorkoutOn(history, cursor)) return 0;
    }
    var count = 0;
    while (_hasWorkoutOn(history, cursor)) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  /// Current streak: consecutive training days ending today (or yesterday,
  /// so an unfinished rest day doesn't break it).
  static int currentStreak(List<WorkoutSession> history, DateTime now) {
    if (history.isEmpty) return 0;
    final today = DateTime(now.year, now.month, now.day);
    final todayTrained = _hasWorkoutOn(history, today);
    return _consecutiveBackFrom(history, today, allowGapToday: !todayTrained);
  }

  /// Longest streak in the whole history.
  static int longestStreak(List<WorkoutSession> history) {
    if (history.isEmpty) return 0;
    final days = _trainingDays(history).toList()..sort();
    var longest = 0;
    var run = 0;
    DateTime? prev;
    for (final d in days) {
      if (prev != null && d.difference(prev).inDays == 1) {
        run++;
      } else {
        run = 1;
      }
      if (run > longest) longest = run;
      prev = d;
    }
    return longest;
  }

  static StreakSummary summary(List<WorkoutSession> history, DateTime now) =>
      StreakSummary(
        current: currentStreak(history, now),
        longest: longestStreak(history),
      );
}
