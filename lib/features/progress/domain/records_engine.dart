import '../../workout_session/domain/personal_records.dart';
import '../../workout_session/domain/workout_session.dart';

/// Aggregated records for ONE exercise (spec §18).
class ExerciseRecords {
  const ExerciseRecords({
    required this.exerciseId,
    required this.exerciseName,
    this.bestSingle = 0,
    this.bestDayTotal = 0,
    this.bestHoldSeconds = 0,
    this.recentBestSingle = 0,
    this.thisProgramBestSingle = 0,
    this.lastPerformedAt,
    this.sessionCount = 0,
  });

  final String exerciseId;
  final String exerciseName;

  /// Lifetime best single set (reps, or seconds for timed holds).
  final int bestSingle;

  /// Most reps across one session (rep-based only).
  final int bestDayTotal;

  /// Longest single hold (timed exercises only).
  final int bestHoldSeconds;

  /// Best single set within the last 30 days.
  final int recentBestSingle;

  /// Best single set within the CURRENT program.
  final int thisProgramBestSingle;

  final DateTime? lastPerformedAt;
  final int sessionCount;

  /// The value that dominates for display: hold seconds beat reps.
  bool get isTimed => bestHoldSeconds > 0;

  String get labelValue => isTimed ? '${bestHoldSeconds}s' : '$bestSingle reps';
}

/// Deterministic snapshot of lifetime + recent + current-program records
/// built from IMMUTABLE history (spec §18/§60). Pure function — feeds the
/// history screen, PR section, Phase 5 analytics and Phase 10 achievements.
class RecordsEngine {
  const RecordsEngine._();

  /// Builds records for every exercise seen across [history] (any order).
  static Map<String, ExerciseRecords> build(
    List<WorkoutSession> history, {
    DateTime? now,
  }) {
    final nowUtc = now ?? DateTime.now().toUtc();
    final cutoff = nowUtc.subtract(const Duration(days: 30));

    // Latest seen program id (newest session decides "current program").
    String? currentProgramId;
    {
      WorkoutSession? newest;
      for (final s in history) {
        if (newest == null || s.startedAt.isAfter(newest.startedAt)) {
          newest = s;
        }
      }
      currentProgramId = newest?.programId;
    }

    final byExercise = <String, _Counter>{};
    for (final s in history) {
      for (final ex in s.exercises) {
        final sets = s
            .setsFor(ex.exerciseId)
            .where((set) => set.countsTowardRecords)
            .toList();
        if (sets.isEmpty) continue;

        final isTimed = ex.isTimed;
        final c = byExercise.putIfAbsent(ex.exerciseId, () => _Counter());
        c.name = ex.name;
        c.sessionCount++;
        if (c.lastPerformedAt == null ||
            s.startedAt.isAfter(c.lastPerformedAt!)) {
          c.lastPerformedAt = s.startedAt;
        }

        for (final set in sets) {
          final v = isTimed ? (set.seconds ?? 0) : (set.reps ?? 0);
          if (v > c.bestSingle) c.bestSingle = v;
          if (isTimed && v > c.bestHoldSeconds) c.bestHoldSeconds = v;
          if (s.startedAt.isAfter(cutoff) && v > c.recentBestSingle) {
            c.recentBestSingle = v;
          }
          if (s.programId == currentProgramId && v > c.thisProgramBestSingle) {
            c.thisProgramBestSingle = v;
          }
        }
        if (!isTimed) {
          final dayTotal = s
              .setsFor(ex.exerciseId)
              .fold(0, (a, x) => a + (x.reps ?? 0));
          if (dayTotal > c.bestDayTotal) c.bestDayTotal = dayTotal;
        }
      }
    }

    return {
      for (final e in byExercise.entries)
        e.key: ExerciseRecords(
          exerciseId: e.key,
          exerciseName: e.value.name,
          bestSingle: e.value.bestSingle,
          bestDayTotal: e.value.bestDayTotal,
          bestHoldSeconds: e.value.bestHoldSeconds,
          recentBestSingle: e.value.recentBestSingle,
          thisProgramBestSingle: e.value.thisProgramBestSingle,
          lastPerformedAt: e.value.lastPerformedAt,
          sessionCount: e.value.sessionCount,
        ),
    };
  }
}

class _Counter {
  String name = '';
  int bestSingle = 0;
  int bestDayTotal = 0;
  int bestHoldSeconds = 0;
  int recentBestSingle = 0;
  int thisProgramBestSingle = 0;
  DateTime? lastPerformedAt;
  int sessionCount = 0;
}

/// The [PersonalRecord] set a session created (reuses WorkoutPrDetector
/// with the session's prior history) — used by the history detail view.
List<PersonalRecord> recordsForSession(
  List<WorkoutSession> history,
  WorkoutSession session,
) {
  final prior = history
      .where(
        (s) => s.id != session.id && s.startedAt.isBefore(session.startedAt),
      )
      .toList();
  return WorkoutPrDetector(prior).detect(session);
}
