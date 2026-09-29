import '../../workout_session/domain/workout_session.dart';

/// Time window for analytics (spec §19: 7 / 30 / 90 / all time).
enum AnalyticsRange {
  sevenDays('7d'),
  thirtyDays('30d'),
  ninetyDays('90d'),
  all('All');

  const AnalyticsRange(this.label);
  final String label;

  int get days => switch (this) {
    AnalyticsRange.sevenDays => 7,
    AnalyticsRange.thirtyDays => 30,
    AnalyticsRange.ninetyDays => 90,
    AnalyticsRange.all => 3650,
  };
}

/// One bar in the frequency chart: sessions + completed sets per day.
class FrequencyBucket {
  const FrequencyBucket({
    required this.day,
    required this.sessions,
    required this.sets,
  });

  final DateTime day; // local, midnight
  final int sessions;
  final int sets;
}

/// Deterministic aggregates for the consistency card.
class ConsistencyStats {
  const ConsistencyStats({
    required this.sessions,
    required this.activeDays,
    required this.totalMinutes,
    required this.avgSessionsPerWeek,
    required this.currentStreak,
    required this.longestStreak,
  });

  final int sessions;
  final int activeDays;
  final int totalMinutes;
  final double avgSessionsPerWeek;
  final int currentStreak;
  final int longestStreak;
}

/// One sample of ONE exercise across a session (counting sets only, §18).
class ExerciseTrendPoint {
  const ExerciseTrendPoint({
    required this.date,
    required this.bestSingle,
    required this.dayTotal,
  });

  final DateTime date;
  final int bestSingle;
  final int dayTotal;
}

class ExerciseTrend {
  const ExerciseTrend({
    required this.exerciseId,
    required this.name,
    required this.isTimed,
    required this.points,
    required this.sessionCount,
  });

  final String exerciseId;
  final String name;
  final bool isTimed;

  /// Chronological per-session samples.
  final List<ExerciseTrendPoint> points;
  final int sessionCount;

  int get bestEver =>
      points.fold(0, (a, p) => p.bestSingle > a ? p.bestSingle : a);

  String get unitLabel => isTimed ? 's' : 'reps';
}

/// Pure, deterministic analytics (spec §19: charts must be driven by this
/// data, NOT by widget-local math; timezone-safe: local calendar days).
abstract final class AnalyticsEngine {
  /// Day buckets [now - days, now] inclusive; days with no workout yield
  /// zero-session buckets so bar charts stay continuous.
  static List<FrequencyBucket> frequency(
    List<WorkoutSession> history,
    AnalyticsRange range, {
    DateTime? now,
  }) {
    final nowLocal = _localMidnight(now ?? DateTime.now());
    var start = nowLocal.subtract(Duration(days: range.days - 1));

    // Never render empty leading buckets: anchor the start at the earliest
    // session day when the window is longer than the training history
    // (keeps "All time" charts compact and correct).
    DateTime? earliest;
    for (final s in history) {
      final day = _localMidnight(s.startedAt);
      if (day.isAfter(nowLocal)) continue;
      if (earliest == null || day.isBefore(earliest)) earliest = day;
    }
    if (earliest != null && earliest.isAfter(start)) start = earliest;

    // day -> (sessions, sets)
    final setsByDay = <DateTime, ({int sessions, int sets})>{};
    for (final s in history) {
      final day = _localMidnight(s.startedAt);
      if (day.isBefore(start) || day.isAfter(nowLocal)) continue;
      final cur = setsByDay.putIfAbsent(day, () => (sessions: 0, sets: 0));
      setsByDay[day] = (
        sessions: cur.sessions + 1,
        sets: cur.sets + s.completedSetCount,
      );
    }

    final buckets = <FrequencyBucket>[];
    var cursor = start;
    while (!cursor.isAfter(nowLocal)) {
      final c = setsByDay[cursor] ?? (sessions: 0, sets: 0);
      buckets.add(
        FrequencyBucket(day: cursor, sessions: c.sessions, sets: c.sets),
      );
      cursor = cursor.add(const Duration(days: 1));
    }
    return buckets;
  }

  static ConsistencyStats consistency(
    List<WorkoutSession> history,
    AnalyticsRange range, {
    DateTime? now,
  }) {
    final nowLocal = _localMidnight(now ?? DateTime.now());
    final start = nowLocal.subtract(Duration(days: range.days - 1));

    final activeDays = <DateTime>{};
    var sessions = 0;
    var totalMinutes = 0;
    for (final s in history) {
      final day = _localMidnight(s.startedAt);
      if (day.isBefore(start) || day.isAfter(nowLocal)) continue;
      sessions++;
      activeDays.add(day);
      totalMinutes += s.duration(s.endedAt ?? s.startedAt).inMinutes;
    }

    final weeks = (range.days / 7).clamp(1.0, 999.0);
    final avg = sessions / weeks;

    return ConsistencyStats(
      sessions: sessions,
      activeDays: activeDays.length,
      totalMinutes: totalMinutes,
      avgSessionsPerWeek: double.parse(avg.toStringAsFixed(1)),
      currentStreak: _streakIn(history, range, now: nowLocal),
      longestStreak: _longestIn(activeDays),
    );
  }

  /// Chronological progression of ONE exercise within the range.
  static ExerciseTrend? exerciseTrend(
    List<WorkoutSession> history,
    String exerciseId,
    AnalyticsRange range, {
    DateTime? now,
  }) {
    final nowLocal = _localMidnight(now ?? DateTime.now());
    final start = nowLocal.subtract(Duration(days: range.days - 1));

    final samples = <ExerciseTrendPoint>[];
    var isTimed = false;
    String name = exerciseId;
    var sessionCount = 0;

    final inRange = history.where((s) {
      final day = _localMidnight(s.startedAt);
      return !day.isBefore(start) && !day.isAfter(nowLocal);
    }).toList()..sort((a, b) => a.startedAt.compareTo(b.startedAt));

    for (final s in inRange) {
      final ex = s.exercises
          .where((e) => e.exerciseId == exerciseId)
          .toList()
          .firstOrNull;
      final sets = s
          .setsFor(exerciseId)
          .where((set) => set.countsTowardRecords)
          .toList();
      if (ex == null || sets.isEmpty) continue;

      isTimed = ex.isTimed;
      name = ex.name;
      sessionCount++;
      var best = 0;
      var total = 0;
      for (final set in sets) {
        final v = isTimed ? (set.seconds ?? 0) : (set.reps ?? 0);
        total += v;
        if (v > best) best = v;
      }
      samples.add(
        ExerciseTrendPoint(
          date: _localMidnight(s.startedAt),
          bestSingle: best,
          dayTotal: total,
        ),
      );
    }

    if (samples.isEmpty) return null;
    return ExerciseTrend(
      exerciseId: exerciseId,
      name: name,
      isTimed: isTimed,
      points: samples,
      sessionCount: sessionCount,
    );
  }

  /// Top [n] exercises by how often they appear in the range (drives the
  /// exercise selector chips — deterministic).
  static List<ExerciseTrend> topExercises(
    List<WorkoutSession> history,
    AnalyticsRange range, {
    int n = 3,
    DateTime? now,
  }) {
    final counts = <String, int>{};
    for (final s in history) {
      final day = _localMidnight(s.startedAt);
      final start = _localMidnight(now ?? DateTime.now())
          .subtract(Duration(days: range.days - 1));
      final end = _localMidnight(now ?? DateTime.now());
      if (day.isBefore(start) || day.isAfter(end)) continue;
      for (final ex in s.exercises) {
        counts[ex.exerciseId] = (counts[ex.exerciseId] ?? 0) + 1;
      }
    }
    final ranked = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ranked
        .take(n)
        .map(
          (e) =>
              exerciseTrend(history, e.key, range, now: now) ??
              ExerciseTrend(
                exerciseId: e.key,
                name: e.key,
                isTimed: false,
                points: const [],
                sessionCount: 0,
              ),
        )
        .toList();
  }

  // ---- internals ----------------------------------------------------------

  static DateTime _localMidnight(DateTime t) {
    final l = t.toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  /// Current streak counted ONLY from training days inside the range (a
  /// workout before the window can still extend a streak that crosses it).
  static int _streakIn(
    List<WorkoutSession> history,
    AnalyticsRange range, {
    required DateTime now,
  }) {
    if (history.isEmpty) return 0;
    final allDays = <DateTime>{};
    for (final s in history) {
      allDays.add(_localMidnight(s.startedAt));
    }
    final cursorStart = now.subtract(Duration(days: range.days - 1));

    var cursor = now;
    if (!allDays.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!allDays.contains(cursor)) return 0;
    }

    var streak = 0;
    while (allDays.contains(cursor) && !cursor.isBefore(cursorStart)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static int _longestIn(Set<DateTime> days) {
    if (days.isEmpty) return 0;
    final sorted = days.toList()..sort();
    var longest = 0;
    var run = 0;
    DateTime? prev;
    for (final d in sorted) {
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
}
