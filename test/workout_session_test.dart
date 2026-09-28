import 'package:calisthenics_app/features/workout_session/domain/personal_records.dart';
import 'package:calisthenics_app/features/workout_session/domain/set_entry.dart';
import 'package:calisthenics_app/features/workout_session/domain/workout_session.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSession _session({
  String id = 'ws_test',
  List<SessionExercise>? exercises,
  List<SetEntry>? sets,
  WorkoutPhase phase = WorkoutPhase.working,
  DateTime? startedAt,
  DateTime? endedAt,
  Duration paused = Duration.zero,
}) => WorkoutSession(
  id: id,
  programId: 'beginner',
  dayName: 'Day 1 - Push + Core',
  dayNumber: 1,
  startedAt: startedAt ?? DateTime.utc(2026, 9, 28, 8),
  endedAt: endedAt,
  exercises:
      exercises ??
      const [
        SessionExercise(
          exerciseId: 'push_up',
          name: 'Push-up',
          sets: 3,
          targetMin: 8,
          targetMax: 15,
          restSeconds: 90,
        ),
        SessionExercise(
          exerciseId: 'plank',
          name: 'Plank',
          sets: 3,
          targetSecondsMin: 20,
          targetSecondsMax: 60,
          restSeconds: 60,
        ),
      ],
  sets: sets ?? const [],
  phase: phase,
  pausedTotal: paused,
);

SetEntry _set(
  String id,
  String ex, {
  int? reps,
  int? seconds,
  bool skipped = false,
  bool pain = false,
}) => SetEntry(
  id: id,
  exerciseId: ex,
  setNumber: 1,
  reps: reps,
  seconds: seconds,
  skipped: skipped,
  painReported: pain,
  completedAt: DateTime.utc(2026, 9, 28, 8, 5),
);

void main() {
  group('WorkoutSession', () {
    test(
      'currentExerciseIndex scans forward: earliest incomplete exercise',
      () {
        // Push-up 2 of 3 done, plank 0 of 3 → push-up is still current.
        final s = _session(
          sets: [
            _set('a', 'push_up', reps: 10),
            _set('b', 'push_up', reps: 10),
          ],
        );
        expect(s.currentExerciseIndex(s.sets), 0);

        // All push-up sets done → plank current.
        final full = _session(
          sets: [
            _set('a', 'push_up', reps: 10),
            _set('b', 'push_up', reps: 10),
            _set('c', 'push_up', reps: 10),
            _set('d', 'plank', seconds: 30),
          ],
        );
        expect(full.currentExerciseIndex(full.sets), 1);
      },
    );

    test('isComplete when all exercises have all sets', () {
      final s = _session(
        sets: [
          _set('a', 'push_up', reps: 10),
          _set('b', 'push_up', reps: 10),
          _set('c', 'push_up', reps: 10),
          _set('d', 'plank', seconds: 30),
          _set('e', 'plank', seconds: 30),
          _set('f', 'plank', seconds: 30),
        ],
      );
      expect(s.isComplete, isTrue);
      expect(s.completedSetCount, 6);
    });

    test('duration excludes paused time; endedAt pins it', () {
      final base = DateTime.utc(2026, 9, 28, 8);
      final s = _session(startedAt: base, paused: const Duration(minutes: 30));
      // Active 40 min later, minus 30 min pause → 10 min.
      expect(
        s.duration(base.add(const Duration(minutes: 40))),
        const Duration(minutes: 10),
      );
      final done = s.copyWith(endedAt: base.add(const Duration(hours: 1)));
      expect(done.duration(DateTime.now()), const Duration(minutes: 30));
    });

    test('targetLabel renders rep and timed ranges', () {
      final rep = _session().exercises.first;
      expect(rep.targetLabel, '3 × 8–15');
      final timed = _session().exercises[1];
      expect(timed.targetLabel, '3 × 20s–60s');
    });

    test('skipped sets count separately and never pollute totals', () {
      final s = _session(
        sets: [
          _set('a', 'push_up', reps: 10),
          _set('b', 'push_up', skipped: true),
        ],
      );
      expect(s.completedSetCount, 2);
      expect(s.skippedSetCount, 1);
      expect(s.totalReps, 10);
    });

    test('session JSON round-trips (immutable records)', () {
      final s = _session(
        sets: [_set('a', 'push_up', reps: 10), _set('b', 'plank', seconds: 45)],
      );
      final restored = WorkoutSession.fromStorage(s.toStorage());
      expect(restored.id, s.id);
      expect(restored.exercises.length, 2);
      expect(restored.sets.length, 2);
      expect(restored.sets[1].seconds, 45);
      expect(restored.dayName, 'Day 1 - Push + Core');
    });
  });

  group('SetEntry', () {
    test('countsTowardRecords rejects skipped, zero, pain sets', () {
      expect(_set('a', 'x', reps: 8).countsTowardRecords, isTrue);
      expect(_set('b', 'x', reps: 0).countsTowardRecords, isFalse);
      expect(_set('c', 'x', skipped: true).countsTowardRecords, isFalse);
      expect(_set('d', 'x', reps: 8, pain: true).countsTowardRecords, isFalse);
    });
  });

  group('WorkoutPrDetector', () {
    test('detects new reps PR only from valid sets', () {
      final prior = _session(
        id: 'x',
        exercises: const [
          SessionExercise(
            exerciseId: 'push_up',
            name: 'Push-up',
            sets: 3,
            targetMin: 8,
            targetMax: 15,
          ),
        ],
        sets: [_set('a', 'push_up', reps: 12)],
      );
      final detector = WorkoutPrDetector([prior]);
      final current = _session(sets: [_set('b', 'push_up', reps: 15)]);
      final records = detector.detect(current);
      expect(
        records.where((r) => r.kind == RecordKind.maxSingle).single.value,
        15,
      );

      // Skipped "record" never fires.
      final cheater = _session(
        sets: [_set('c', 'push_up', reps: 999, skipped: true)],
      );
      expect(detector.detect(cheater), isEmpty);
    });

    test('timed exercises produce longestHold records', () {
      final prior = _session(
        id: 'x',
        exercises: const [
          SessionExercise(
            exerciseId: 'plank',
            name: 'Plank',
            sets: 3,
            targetSecondsMin: 20,
            targetSecondsMax: 60,
          ),
        ],
        sets: [_set('a', 'plank', seconds: 30)],
      );
      final detector = WorkoutPrDetector([prior]);
      final records = detector.detect(
        _session(sets: [_set('b', 'plank', seconds: 45)]),
      );
      expect(records.single.kind, RecordKind.longestHold);
      expect(records.single.value, 45);
    });
  });

  group('XpEstimate', () {
    test('completed sets and minutes drive XP; skipped sets excluded', () {
      final start = DateTime.utc(2026, 9, 28, 8);
      final s = _session(
        sets: [
          _set('a', 'push_up', reps: 10),
          _set('b', 'push_up', reps: 10),
          _set('c', 'push_up', skipped: true),
        ],
        startedAt: start,
        endedAt: start.add(const Duration(minutes: 10)),
      );
      // 2 valid sets → 10 XP; 10 min → 20 XP; workout bonus 25.
      expect(s.estimatedXp, 55);
    });
  });
}
