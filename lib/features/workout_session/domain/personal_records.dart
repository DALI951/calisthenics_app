import 'set_entry.dart';
import 'workout_session.dart';

/// Which aspect of a movement a record measures (spec §18).
enum RecordKind {
  maxSingle('max single reps', 'Max reps'),
  longestHold('longest hold', 'Longest hold'),
  dayTotal('most reps in a day', 'Day total');

  const RecordKind(this.label, this.shortLabel);
  final String label;
  final String shortLabel;
}

/// A detected personal record: never from incomplete or invalid sets (§18).
class PersonalRecord {
  const PersonalRecord({
    required this.exerciseId,
    required this.exerciseName,
    required this.kind,
    required this.value,
  });

  final String exerciseId;
  final String exerciseName;
  final RecordKind kind;

  /// Reps (maxSingle/dayTotal) or seconds (longestHold).
  final int value;

  String get display => kind == RecordKind.longestHold
      ? '$exerciseName — ${value}s'
      : '$exerciseName — $value reps';

  String get kindLabel => kind.shortLabel;
}

/// Deterministic PR detector (pure Dart, unit-tested later in Phase 4).
///
/// A record only counts from sets where [SetEntry.countsTowardRecords] is
/// true — skipped, zero and pain-reported sets never create records (§18).
class WorkoutPrDetector {
  WorkoutPrDetector(this.priorSessions);

  /// All sessions completed BEFORE [session] (any order, same program).
  final List<WorkoutSession> priorSessions;

  /// Returns one PersonalRecord per exercise/kind that BEAT every prior best.
  List<PersonalRecord> detect(WorkoutSession session) {
    final records = <PersonalRecord>[];
    for (final ex in session.exercises) {
      final sets = session
          .setsFor(ex.exerciseId)
          .where((s) => s.countsTowardRecords)
          .toList();
      if (sets.isEmpty) continue;
      final isTimed = ex.isTimed;

      // Best single set.
      final currentBest = sets
          .map((s) => isTimed ? (s.seconds ?? 0) : (s.reps ?? 0))
          .reduce((a, b) => a > b ? a : b);
      if (currentBest > _previousBest(ex.exerciseId, isTimed)) {
        records.add(
          PersonalRecord(
            exerciseId: ex.exerciseId,
            exerciseName: ex.name,
            kind: isTimed ? RecordKind.longestHold : RecordKind.maxSingle,
            value: currentBest,
          ),
        );
      }

      // Day total (rep-based movements only, §18 “best workout” sense).
      if (!isTimed) {
        final total = session
            .setsFor(ex.exerciseId)
            .fold(0, (a, s) => a + (s.reps ?? 0));
        final prevTotal = priorSessions.fold(0, (a, s) {
          final t = s
              .setsFor(ex.exerciseId)
              .fold(0, (x, set) => x + (set.reps ?? 0));
          return t > a ? t : a;
        });
        if (total > prevTotal) {
          records.add(
            PersonalRecord(
              exerciseId: ex.exerciseId,
              exerciseName: ex.name,
              kind: RecordKind.dayTotal,
              value: total,
            ),
          );
        }
      }
    }
    return records;
  }

  int _previousBest(String exerciseId, bool isTimed) {
    var best = 0;
    for (final s in priorSessions) {
      for (final set in s.setsFor(exerciseId)) {
        if (!set.countsTowardRecords) continue;
        final v = isTimed ? (set.seconds ?? 0) : (set.reps ?? 0);
        if (v > best) best = v;
      }
    }
    return best;
  }
}

/// Honest, deterministic XP estimate (spec §26: training is the source of
/// progress). 5 XP per completed set + 2 per full minute + 25 workout bonus.
extension XpEstimate on WorkoutSession {
  int get estimatedXp {
    final completedSets = sets.where((s) => !s.skipped).length;
    final minutes = duration(DateTime.now()).inMinutes;
    return completedSets * 5 + minutes * 2 + 25;
  }
}
