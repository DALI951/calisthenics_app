import 'package:calisthenics_app/features/progress/domain/records_engine.dart';
import 'package:calisthenics_app/features/workout_session/domain/personal_records.dart';
import 'package:calisthenics_app/features/workout_session/domain/set_entry.dart';
import 'package:calisthenics_app/features/workout_session/domain/workout_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecordsEngine (spec §18 — lifetime / recent / current program)', () {
    test('aggregates best single, day total and count across history', () {
      final history = <WorkoutSession>[
        _session(
          id: 's1',
          programId: 'beginner',
          day: 20,
          exName: 'Push-ups',
          values: const [10, 12],
        ),
        _session(
          id: 's2',
          programId: 'beginner',
          day: 21,
          exName: 'Push-ups',
          values: const [14, 11],
        ),
      ];

      final records =
          RecordsEngine.build(history, now: DateTime.utc(2026, 9, 30));
      final r = records['pushup-standard']!;
      expect(r.bestSingle, 14);
      expect(r.bestDayTotal, 25); // 14 + 11 in the best session
      expect(r.sessionCount, 2);
      expect(r.lastPerformedAt, DateTime.utc(2026, 9, 21, 10));
    });

    test('timed exercises fill hold seconds, not day totals', () {
      final history = <WorkoutSession>[
        _session(
          id: 's1',
          programId: 'beginner',
          day: 20,
          exName: 'Plank',
          seconds: const [40, 55],
        ),
      ];
      final records =
          RecordsEngine.build(history, now: DateTime.utc(2026, 9, 30));
      final r = records['plank']!;
      expect(r.isTimed, isTrue);
      expect(r.bestHoldSeconds, 55);
      expect(r.bestSingle, 55);
      expect(r.bestDayTotal, 0); // reps-only metric
    });

    test('recent window = last 30 days; older sets not counted', () {
      final history = <WorkoutSession>[
        _session(
          id: 'old',
          programId: 'beginner',
          month: 7, // July 1 — way outside the 30-day window
          day: 1,
          exName: 'Push-ups',
          values: const [20],
        ),
        _session(
          id: 'new',
          programId: 'beginner',
          day: 25,
          exName: 'Push-ups',
          values: const [8],
        ),
      ];
      final records = RecordsEngine.build(
        history,
        now: DateTime.utc(2026, 9, 30),
      );
      final r = records['pushup-standard']!;
      expect(r.bestSingle, 20); // lifetime keeps the old big one
      expect(r.recentBestSingle, 8); // but recent sees only the new one
    });

    test('current program scoping uses the most recent programId', () {
      final history = <WorkoutSession>[
        _session(
          id: 'oldProg',
          programId: 'beginner',
          day: 20,
          exName: 'Push-ups',
          values: const [19],
        ),
        _session(
          id: 'newProg',
          programId: 'beginner_v2',
          day: 25,
          exName: 'Push-ups',
          values: const [13],
        ),
      ];
      final r = RecordsEngine.build(history, now: DateTime.utc(2026, 9, 30))[
          'pushup-standard']!;
      expect(r.thisProgramBestSingle, 13); // v1's 19 does not leak in
    });

    test('skipped / pain / zero sets never create records', () {
      final history = <WorkoutSession>[
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
            ),
          ],
          sets: [
            SetEntry(
              id: 'a1',
              exerciseId: 'pushup-standard',
              setNumber: 1,
              reps: 0,
              completedAt: DateTime.utc(2026, 9, 20, 9, 1),
            ),
            SetEntry(
              id: 'a2',
              exerciseId: 'pushup-standard',
              setNumber: 2,
              skipped: true,
              completedAt: DateTime.utc(2026, 9, 20, 9, 2),
            ),
            SetEntry(
              id: 'a3',
              exerciseId: 'pushup-standard',
              setNumber: 3,
              reps: 3,
              painReported: true,
              completedAt: DateTime.utc(2026, 9, 20, 9, 3),
            ),
          ],
        ),
      ];
      final records =
          RecordsEngine.build(history, now: DateTime.utc(2026, 9, 30));
      expect(records.containsKey('pushup-standard'), isFalse);
    });

    test('recordsForSession detects PRs vs prior sessions only', () {
      final history = <WorkoutSession>[
        _session(
          id: 's1',
          programId: 'beginner',
          day: 20,
          exName: 'Push-ups',
          values: const [10, 12],
        ),
        _session(
          id: 's2',
          programId: 'beginner',
          day: 22,
          exName: 'Push-ups',
          values: const [13, 14],
        ),
      ];
      final prs = recordsForSession(history, history[1]);
      expect(prs.where((p) => p.exerciseId == 'pushup-standard'), isNotEmpty);
      final maxSingle =
          prs.where((p) => p.kind == RecordKind.maxSingle).toList();
      expect(maxSingle, hasLength(1));
      expect(maxSingle.first.value, 14);
    });
  });
}

WorkoutSession _session({
  required String id,
  required String programId,
  int month = 9,
  required int day,
  required String exName,
  List<int> values = const [],
  List<int> seconds = const [],
}) {
  final isTimed = seconds.isNotEmpty;
  return WorkoutSession(
    id: id,
    programId: programId,
    dayName: 'Day $day',
    dayNumber: day,
    startedAt: DateTime.utc(2026, month, day, 10),
    endedAt: DateTime.utc(2026, month, day, 10, 20),
    exercises: [
      SessionExercise(
        exerciseId: isTimed ? 'plank' : 'pushup-standard',
        name: exName,
        sets: values.length > seconds.length ? values.length : seconds.length,
        targetSecondsMin: isTimed ? 30 : null,
        targetSecondsMax: isTimed ? 120 : null,
      ),
    ],
    sets: [
      for (var i = 0; i < (isTimed ? seconds.length : values.length); i++)
        SetEntry(
          id: '$id-$i',
          exerciseId: isTimed ? 'plank' : 'pushup-standard',
          setNumber: i + 1,
          reps: isTimed ? null : values[i],
          seconds: isTimed ? seconds[i] : null,
          completedAt: DateTime.utc(2026, month, day, 10, i + 1),
        ),
    ],
  );
}