import 'package:calisthenics_app/features/progress/domain/streak_calculator.dart';
import 'package:calisthenics_app/features/workout_session/domain/workout_session.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSession _s(DateTime localDay, {String id = 's'}) => WorkoutSession(
  id: id,
  programId: 'beginner',
  dayName: 'Day 1',
  dayNumber: 1,
  // Store UTC; the calculator converts to LOCAL days (spec §69).
  startedAt: localDay.toUtc(),
  exercises: const [
    SessionExercise(
      exerciseId: 'push_up',
      name: 'Push-up',
      sets: 3,
      targetMin: 8,
      targetMax: 15,
    ),
  ],
  sets: const [],
);

void main() {
  // Use a fixed local "now" (Monday) to keep the math deterministic.
  final now = DateTime(2026, 9, 28, 15);

  test('no history → streak 0, longest 0', () {
    expect(StreakCalculator.currentStreak(const [], now), 0);
    expect(StreakCalculator.longestStreak(const []), 0);
  });

  test('single workout today → current 1', () {
    final h = [_s(now)];
    expect(StreakCalculator.currentStreak(h, now), 1);
  });

  test('consecutive days Mon,Sun,Sat → current 3; gap breaks it', () {
    final h = [
      _s(now), // Mon
      _s(now.subtract(const Duration(days: 1))), // Sun
      _s(now.subtract(const Duration(days: 2))), // Sat
      _s(now.subtract(const Duration(days: 4))), // Thu (gap on Fri)
      _s(now.subtract(const Duration(days: 5))), // Wed
    ];
    expect(StreakCalculator.currentStreak(h, now), 3);
    expect(StreakCalculator.longestStreak(h), 3);
  });

  test('rest day today (no workout) does NOT break a running streak', () {
    final h = [
      _s(now.subtract(const Duration(days: 1))), // Sun — last training
      _s(now.subtract(const Duration(days: 2))), // Sat
    ];
    // Monday is a planned gap/rest day (spec §27): streak survives.
    expect(StreakCalculator.currentStreak(h, now), 2);
  });

  test('old streak without recent training → current 0, longest remembers', () {
    final h = [
      _s(now.subtract(const Duration(days: 1))),
      _s(now.subtract(const Duration(days: 2))),
      _s(now.subtract(const Duration(days: 9))),
      _s(now.subtract(const Duration(days: 10))),
    ];
    expect(StreakCalculator.currentStreak(h, now), 2);
    expect(StreakCalculator.longestStreak(h), 2);
  });
}
