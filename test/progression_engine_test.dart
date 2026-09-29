import 'package:calisthenics_app/features/exercises/data/exercise_library.dart';
import 'package:calisthenics_app/features/progress/domain/progression_engine.dart';
import 'package:calisthenics_app/features/workout_session/domain/set_entry.dart';
import 'package:calisthenics_app/features/workout_session/domain/workout_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = ProgressionEngine();

  group('ProgressionEngine (spec §11 — deterministic, testable)', () {
    test('empty history → keepTarget with onboarding-style message', () {
      final advice = engine.evaluate(
        recentSetsPerSession: const [],
        sets: 4,
        targetMin: 8,
        targetMax: 15,
        harder: null,
      );
      expect(advice.outcome, ProgressionOutcome.keepTarget);
      expect(advice.message, contains('Complete a few workouts'));
    });

    test('mid-range performance → keepTarget', () {
      final advice = engine.evaluate(
        recentSetsPerSession: const [
          [10, 11, 10, 12],
          [11, 12, 10, 11],
        ],
        sets: 4,
        targetMin: 8,
        targetMax: 15,
        harder: null,
      );
      expect(advice.outcome, ProgressionOutcome.keepTarget);
    });

    test('at top of range without harder variation (ceiling) → keepTarget', () {
      final advice = engine.evaluate(
        recentSetsPerSession: const [
          [15, 15, 14, 15],
          [15, 15, 15, 14],
        ],
        sets: 4,
        targetMin: 8,
        targetMax: 15, // already at the hard cap (15): cannot raise further
        harder: null,
      );
      expect(advice.outcome, ProgressionOutcome.keepTarget);
    });

    test('at top with ceiling reached → raiseTarget capped at 15', () {
      // targetMax 13 + raiseStep 2 → capped 15.
      final advice = engine.evaluate(
        recentSetsPerSession: const [
          [13, 14, 13, 13],
          [14, 14, 13, 13],
        ],
        sets: 4,
        targetMin: 8,
        targetMax: 13,
        harder: null,
      );
      expect(advice.outcome, ProgressionOutcome.raiseTarget);
      expect(advice.newTargetMax, 15);
    });

    test('at top WITH harder variation → readyToStep (recommend harder)', () {
      final pushUp = ExerciseLibrary.byId('pushup-standard');
      expect(pushUp, isNotNull);
      final advice = engine.evaluate(
        recentSetsPerSession: const [
          [15, 15, 15, 15],
          [15, 14, 15, 15],
        ],
        sets: 4,
        targetMin: 8,
        targetMax: 15,
        harder: pushUp,
      );
      expect(advice.outcome, ProgressionOutcome.readyToStep);
      expect(advice.harderExercise?.id, 'pushup-standard');
      expect(advice.message, contains('Ready to progress?'));
    });

    test('junk/negative values are ignored (safety guard)', () {
      // Visible values average 15 → consistently at top of 14-based range.
      final advice = engine.evaluate(
        recentSetsPerSession: const [
          [0, -3, 15, 15],
          [15, 15],
        ],
        sets: 4,
        targetMin: 8,
        targetMax: 14,
        harder: null,
      );
      expect(advice.outcome, ProgressionOutcome.raiseTarget);
      expect(advice.newTargetMax, 15);
    });
  });

  group('validSetsByExercise', () {
    test('extracts only counting sets for the exercise', () {
      final sessions = <WorkoutSession>[
        WorkoutSession(
          id: 's1',
          programId: 'beginner',
          dayName: 'Day 1 — Push + Core',
          dayNumber: 1,
          startedAt: DateTime.utc(2026, 9, 20, 9),
          endedAt: DateTime.utc(2026, 9, 20, 9, 12),
          exercises: const [
            SessionExercise(
              exerciseId: 'pushup-standard',
              name: 'Push-ups',
              sets: 3,
              targetMin: 8,
              targetMax: 15,
            ),
          ],
          sets: [
            SetEntry(
              id: 'a1',
              exerciseId: 'pushup-standard',
              setNumber: 1,
              reps: 10,
              completedAt: DateTime.utc(2026, 9, 20, 9, 1),
            ),
            SetEntry(
              id: 'a2',
              exerciseId: 'pushup-standard',
              setNumber: 2,
              reps: 12,
              completedAt: DateTime.utc(2026, 9, 20, 9, 4),
            ),
            // Skipped — must NOT appear in progression input.
            SetEntry(
              id: 'a3',
              exerciseId: 'pushup-standard',
              setNumber: 3,
              skipped: true,
              completedAt: DateTime.utc(2026, 9, 20, 9, 7),
            ),
            // Pain-reported — must NOT appear either.
            SetEntry(
              id: 'a4',
              exerciseId: 'pushup-standard',
              setNumber: 4,
              reps: 5,
              painReported: true,
              completedAt: DateTime.utc(2026, 9, 20, 9, 9),
            ),
          ],
        ),
      ];

      final values = validSetsByExercise(sessions, 'pushup-standard');
      expect(values, hasLength(1));
      expect(values.first, [10, 12]);
    });
  });
}
