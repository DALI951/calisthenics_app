import '../../exercises/data/exercise_library.dart';
import '../../workout_session/domain/workout_session.dart';
import 'challenge.dart';

/// Pure challenge logic (spec §23): progress derived from IMMUTABLE workout
/// history, deterministic settlement, and SAFETY guardrails that refuse
/// dangerous max-effort targets.
class ChallengeEngine {
  const ChallengeEngine._();

  /// Safety caps — a challenge may never ask for more than a sustainable,
  /// beginner-friendly effort (spec §23 "do not build dangerous max-effort
  /// challenges" / "avoid rewarding unsafe behavior or ignoring pain").
  static int maxTarget(
    ChallengeType type, {
    ExerciseMetricLike metric = ExerciseMetricLike.reps,
  }) => switch (type) {
    ChallengeType.consistency => 21,
    ChallengeType.workoutCompletion => 7,
    ChallengeType.volume => 20000,
    ChallengeType.progression => metric.isSeconds ? 300 : 100,
    ChallengeType.time => 600,
    ChallengeType.headToHead => 20000,
  };

  /// Returns a human error message, or null when the target is safe.
  static String? validateTarget({
    required ChallengeType type,
    required int target,
    ExerciseMetricLike metric = ExerciseMetricLike.reps,
  }) {
    if (target <= 0) {
      return 'Pick a target greater than zero.';
    }
    final cap = maxTarget(type, metric: metric);
    if (target > cap) {
      return 'Keep it sustainable — cap for ${type.label.toLowerCase()} '
          'challenges is $cap ${metric.isSeconds ? 'seconds' : 'reps'}.';
    }
    return null;
  }

  /// Challenge period in days (min 1, max 30).
  static const periodOptions = [3, 7, 14, 30];
  static String? validatePeriod(int days) =>
      periodOptions.contains(days) ? null : 'Pick a 3, 7, 14 or 30 day period.';

  static ChallengeStatus effectiveStatus(Challenge c, DateTime now) {
    if (c.status.isOver) return c.status;
    if (c.status == ChallengeStatus.pending) return ChallengeStatus.pending;
    if (now.isBefore(c.startsAt)) return ChallengeStatus.accepted;
    if (now.isAfter(c.endsAt)) return ChallengeStatus.expired;
    return ChallengeStatus.active;
  }

  /// Legal state machine (spec §24, §"challenge state transitions").
  static bool canTransition(ChallengeStatus from, ChallengeStatus to) {
    const allowed = {
      ChallengeStatus.pending: {
        ChallengeStatus.accepted,
        ChallengeStatus.declined,
        ChallengeStatus.cancelled,
      },
      ChallengeStatus.accepted: {
        ChallengeStatus.active,
        ChallengeStatus.completed,
        ChallengeStatus.expired,
        ChallengeStatus.cancelled,
      },
      ChallengeStatus.active: {
        ChallengeStatus.completed,
        ChallengeStatus.expired,
        ChallengeStatus.cancelled,
      },
    };
    return allowed[from]?.contains(to) ?? false;
  }

  /// Progress for [uid] inside the challenge window, with session evidence.
  /// Sessions are counted only when they are real records (ended, started
  /// inside the window) and pain-reported sets never count (spec §27).
  static ChallengeProgress progressFor(
    Challenge c,
    String uid,
    List<WorkoutSession> history, {
    required ExerciseMetricLike metric,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now().toUtc();
    final window = history
        .where(
          (s) =>
              s.endedAt != null &&
              !s.startedAt.isBefore(c.startsAt) &&
              s.startedAt.isAfter(c.endsAt) == false,
        )
        .toList();

    var value = 0;
    final evidence = <String>[];

    switch (c.type) {
      case ChallengeType.consistency:
        value = window.length;
        evidence.addAll(window.map((s) => s.id));
      case ChallengeType.workoutCompletion:
        final hit = window.where(
          (s) =>
              c.dayName == null ||
              s.dayName.toLowerCase() == c.dayName!.toLowerCase(),
        );
        value = hit.isEmpty ? 0 : 1;
        evidence.addAll(hit.map((s) => s.id));
      case ChallengeType.volume:
      case ChallengeType.headToHead:
        for (final s in window) {
          for (final set in s.sets) {
            if (!set.countsTowardRecords) {
              continue;
            }
            if (c.exerciseId != null && set.exerciseId != c.exerciseId) {
              continue;
            }
            value += set.reps ?? 0;
          }
        }
        evidence.addAll(window.map((s) => s.id));
      case ChallengeType.progression:
        var best = 0;
        for (final s in window) {
          for (final set in s.sets) {
            if (set.exerciseId != c.exerciseId) continue;
            if (!set.countsTowardRecords) continue;
            if (set.primaryValue > best) best = set.primaryValue;
          }
        }
        value = best;
        evidence.addAll(window.map((s) => s.id));
      case ChallengeType.time:
        value = window.fold(0, (acc, s) => acc + s.duration(clock).inMinutes);
        evidence.addAll(window.map((s) => s.id));
    }

    return ChallengeProgress(
      challengeId: c.id,
      uid: uid,
      value: value,
      target: c.target,
      unitLabel: c.type.unit(metric),
      evidenceSessionIds: evidence,
      updatedAt: clock,
    );
  }

  /// Metric of the scoped exercise, for unit labels.
  static ExerciseMetricLike metricFor(Challenge c) {
    final ex = c.exerciseId == null
        ? null
        : ExerciseLibrary.byId(c.exerciseId!);
    return ex?.metric.name == 'seconds'
        ? ExerciseMetricLike.seconds
        : ExerciseMetricLike.reps;
  }

  /// Settles a challenge. Deterministic: winner = higher verified progress,
  /// tie = draw (no "winner/loser" language, spec §24). Nobody can be
  /// declared the winner without evidence — pass the progress map computed
  /// by [progressFor].
  static Challenge settle(
    Challenge c,
    Map<String, ChallengeProgress> progress, {
    required DateTime now,
  }) {
    if (c.result != null) return c; // settled once, never recomputed
    final status = effectiveStatus(c, now);
    final reached = progress.values.where((p) => p.completed).toList();
    final everyoneDone =
        progress.isNotEmpty && progress.values.every((p) => p.completed);

    // A target-based challenge ends the moment the target is reached — no
    // need to wait out the full period (spec §24 "challenge completion").
    final targetHit = c.type.targetBased && reached.isNotEmpty;
    final periodOver = status == ChallengeStatus.expired;
    if (!targetHit && !periodOver) return c.copyWith(status: status);

    final leader = _leader(progress);
    // Head-to-head is decided BY the comparison when the period closes;
    // target-based challenges are decided by reaching the target.
    final comparison = c.type == ChallengeType.headToHead;
    final decided = targetHit || everyoneDone || (comparison && periodOver);
    return c.copyWith(
      status: decided ? ChallengeStatus.completed : ChallengeStatus.expired,
      result: ChallengeResult(
        // No target reached → no winner, ever. An expired challenge just
        // reports the numbers both sides banked.
        winnerUid: decided ? leader?.uid : null,
        isDraw: decided && leader == null,
        finalValues: {for (final e in progress.entries) e.key: e.value.value},
        decidedAt: now,
        decidedBy: 'engine-v1',
      ),
    );
  }

  /// Highest verified progress, or null when tied (a draw — never a
  /// manufactured winner).
  static ChallengeProgress? _leader(Map<String, ChallengeProgress> progress) {
    if (progress.isEmpty) return null;
    final sorted = progress.values.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.first;
    if (sorted.length > 1 && sorted[1].value == top.value) return null;
    return top;
  }
}
