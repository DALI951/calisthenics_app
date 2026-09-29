import 'package:calisthenics_app/features/progress/domain/analytics_engine.dart';
import 'package:calisthenics_app/features/workout_session/domain/set_entry.dart';
import 'package:calisthenics_app/features/workout_session/domain/workout_session.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reference month: Sept 2026. `now` fixed at 2026-09-30 12:00 local;
/// the test machine TZ decides local conversions — all fixtures use
/// midday-UTC timestamps which are the same local day in most TZs, and the
/// engine's day math is local-midnight based, so stays deterministic.
final _now = DateTime(2026, 9, 30, 12);

void main() {
  group('AnalyticsEngine.frequency (spec §19)', () {
    test('buckets only sessions inside the window, zeros in gaps', () {
      final history = [
        _s('a', day: 29, values: const [10, 11, 12]), // in 7d window
        _s('b', day: 28), // in
        _s('c', day: 20), // OUTSIDE (11 days ago)
      ];

      final buckets = AnalyticsEngine.frequency(
        history,
        AnalyticsRange.sevenDays,
        now: _now,
      );
      expect(buckets, hasLength(7));
      expect(buckets[0].sessions, 0); // Sept 24 — leading empty day
      expect(buckets[4].sessions, 1); // Sept 28
      expect(buckets[5].sessions, 1); // Sept 29
      expect(buckets[5].sets, 3);
    });

    test('all range starts at the earliest session day', () {
      final history = [_s('old', day: 1), _s('new', day: 28)];
      final all = AnalyticsEngine.frequency(
        history,
        AnalyticsRange.all,
        now: _now,
      );
      // 30 buckets: Sept 1 .. Sept 30 inclusive.
      expect(all, hasLength(30));
      expect(all.first.sessions, 1);
    });
  });

  group('AnalyticsEngine.consistency', () {
    test('aggregates sessions, active days, minutes, weekly average', () {
      final history = [
        _s('a', day: 29, minutes: 12),
        _s('b', day: 29, minutes: 8), // two sessions same day
        _s('c', day: 22), // outside 7d
      ];
      final c = AnalyticsEngine.consistency(
        history,
        AnalyticsRange.sevenDays,
        now: _now,
      );
      expect(c.sessions, 2);
      expect(c.activeDays, 1);
      expect(c.totalMinutes, 20);
      expect(c.avgSessionsPerWeek, 2.0);
    });

    test('current streak counts only within-range training days', () {
      final history = [
        _s('a', day: 28),
        _s('b', day: 29),
        _s('c', day: 30),
        _s('old', day: 1), // outside
      ];
      final c = AnalyticsEngine.consistency(
        history,
        AnalyticsRange.sevenDays,
        now: _now,
      );
      expect(c.currentStreak, 3);
      expect(c.longestStreak, 3);
    });
  });

  group('AnalyticsEngine.exerciseTrend', () {
    test('chronological best-single samples, counting sets only', () {
      final history = [
        _s('a', day: 28, ex: 'pushup-standard', values: [8, 10]),
        _s('b', day: 30, ex: 'pushup-standard', values: [11, 12]),
      ];
      final trend = AnalyticsEngine.exerciseTrend(
        history,
        'pushup-standard',
        AnalyticsRange.sevenDays,
        now: _now,
      )!;
      expect(trend.sessionCount, 2);
      expect(trend.points, hasLength(2));
      expect(trend.points[0].bestSingle, 10);
      expect(trend.points[1].bestSingle, 12);
      expect(trend.points[1].dayTotal, 23);
      expect(trend.bestEver, 12);
    });

    test('holds trend uses seconds', () {
      final history = [
        _s('a', day: 29, ex: 'plank', seconds: [40, 55]),
      ];
      final trend = AnalyticsEngine.exerciseTrend(
        history,
        'plank',
        AnalyticsRange.sevenDays,
        now: _now,
      )!;
      expect(trend.isTimed, isTrue);
      expect(trend.points.single.bestSingle, 55);
      expect(trend.unitLabel, 's');
    });

    test('topExercises ranks by frequency and returns trends', () {
      final history = [
        _s('a', day: 28, ex: 'pushup-standard', values: [10]),
        _s('b', day: 29, ex: 'pushup-standard', values: [11]),
        _s('c', day: 30, ex: 'plank', seconds: [30]),
      ];
      final top = AnalyticsEngine.topExercises(
        history,
        AnalyticsRange.sevenDays,
        n: 3,
        now: _now,
      );
      expect(top.first.exerciseId, 'pushup-standard');
      expect(top.first.sessionCount, 2);
      expect(top, hasLength(2)); // only 2 distinct exercises exist
    });
  });
}

WorkoutSession _s(
  String id, {
  required int day,
  int minutes = 12,
  String ex = 'pushup-standard',
  List<int> values = const [],
  List<int> seconds = const [],
}) {
  final isTimed = seconds.isNotEmpty;
  final start = DateTime.utc(2026, 9, day, 10);
  return WorkoutSession(
    id: id,
    programId: 'beginner',
    dayName: 'Day $day',
    dayNumber: day,
    startedAt: start,
    endedAt: start.add(Duration(minutes: minutes)),
    exercises: [
      SessionExercise(
        exerciseId: ex,
        name: isTimed ? 'Plank' : 'Push-ups',
        sets: values.length > seconds.length ? values.length : seconds.length,
        targetSecondsMin: isTimed ? 30 : null,
        targetSecondsMax: isTimed ? 120 : null,
      ),
    ],
    sets: [
      for (var i = 0; i < (isTimed ? seconds.length : values.length); i++)
        SetEntry(
          id: '$id-$i',
          exerciseId: ex,
          setNumber: i + 1,
          reps: isTimed ? null : (values.isEmpty ? 10 : values[i]),
          seconds: isTimed ? seconds[i] : null,
          completedAt: start.add(Duration(minutes: i + 1)),
        ),
    ],
  );
}
