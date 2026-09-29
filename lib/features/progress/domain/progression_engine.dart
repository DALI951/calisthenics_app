import '../../exercises/domain/exercise.dart';
import '../../workout_session/domain/workout_session.dart';

/// What the progression engine recommends for one exercise (spec §11).
enum ProgressionOutcome {
  /// Keep the current target — performance is inside/under the range.
  keepTarget,

  /// Consistently at the top of the range — nudge the target UP within
  /// the allowed ceiling (never above the hard cap).
  raiseTarget,

  /// Hitting the ceiling with consistency — suggest the next HARDER
  /// variation from the ladder (§10).
  readyToStep,
}

/// Deterministic outcome of [ProgressionEngine.evaluate].
class ProgressionAdvice {
  const ProgressionAdvice({
    required this.outcome,
    this.newTargetMax,
    this.harderExercise,
    required this.message,
  });

  final ProgressionOutcome outcome;

  /// Suggested new targetMax when [outcome] == raiseTarget (targetMin
  /// stays; the range widens upward, capped at [maxCeiling]).
  final int? newTargetMax;

  /// The exercise to step up to when [outcome] == readyToStep.
  final Exercise? harderExercise;

  /// Human-friendly message ("Ready to progress?", "Keep going…").
  final String message;

  bool get readyToStep => outcome == ProgressionOutcome.readyToStep;
  bool get raise => outcome == ProgressionOutcome.raiseTarget;
}

/// Deterministic, testable progression engine (spec §11: "must be
/// deterministic and testable", "do not hardcode progression logic in
/// widgets").
///
/// Input: the VALID, non-painful sets of the LAST sessions for one
/// exercise (exclude pain/skipped sets upstream — §28: never push through
/// pain). Output: an advice with a stable rule set:
///
///   avg(per-set value) >= 0.95 * targetMax  →  consistently at top
///     · at the ceiling and a harder variation exists → readyToStep
///     · otherwise → raiseTarget (targetMax + [raiseStep], capped)
///   avg in [targetMin, targetMax)              → keepTarget ("in range")
///   avg < targetMin and avg > 0                → keepTarget (consistency msg)
class ProgressionEngine {
  const ProgressionEngine({this.raiseStep = 2, this.maxCeiling = 15});

  /// How many units targetMax jumps per raise (within the ceiling).
  final int raiseStep;

  /// Absolute cap for any raise (tied to the spec's 8–15 default range).
  final int maxCeiling;

  /// [recentSetsPerSession] — one entry per recent session, each a list of
  /// per-set values (reps or seconds). [sets] is the planned set count.
  ///
  /// [targetMin]/[targetMax] come from the CURRENT planned exercise at the
  /// moment the session started (spec §60 snapshot).
  /// [harder] is the candidate from `exercise.harderVariations` (already
  /// resolved to an [Exercise] by the caller), nullable when none exists.
  ProgressionAdvice evaluate({
    required List<List<int>> recentSetsPerSession,
    required int sets,
    required int targetMin,
    required int targetMax,
    required Exercise? harder,
  }) {
    // Flatten all valid per-set values from the recent sessions.
    final values = <int>[];
    for (final sessionSets in recentSetsPerSession) {
      for (final v in sessionSets) {
        if (v <= 0) continue;
        values.add(v);
        if (values.length >= maxCeiling * sets * 2) break; // sanity guard
      }
    }

    if (values.isEmpty) {
      return ProgressionAdvice(
        outcome: ProgressionOutcome.keepTarget,
        message:
            'Complete a few workouts and the app will watch for '
            'readiness to progress.',
      );
    }

    final avg = values.reduce((a, b) => a + b) / values.length;

    const String keepMsg =
        'Keep improving technique and consistency — you are well placed '
        'to progress soon.';

    final atTop = avg >= targetMax * 0.95;
    if (!atTop) {
      return ProgressionAdvice(
        outcome: ProgressionOutcome.keepTarget,
        message: keepMsg,
      );
    }

    // Consistently at the top.
    if (harder != null) {
      return ProgressionAdvice(
        outcome: ProgressionOutcome.readyToStep,
        harderExercise: harder,
        message: 'Ready to progress? Try ${harder.name}.',
      );
    }

    final capped = (targetMax + raiseStep).clamp(targetMin + 1, maxCeiling);
    if (capped > targetMax) {
      return ProgressionAdvice(
        outcome: ProgressionOutcome.raiseTarget,
        newTargetMax: capped,
        message:
            'Excellent consistency! Target raised to $targetMin–$capped '
            'reps per set.',
      );
    }

    return ProgressionAdvice(
      outcome: ProgressionOutcome.keepTarget,
      message: keepMsg,
    );
  }
}

/// Convenience: extract valid per-set values from completed sessions for
/// one exerciseId (skips pain/skipped/zero sets — §18/§28 semantics).
List<List<int>> validSetsByExercise(
  List<WorkoutSession> sessions,
  String exerciseId,
) {
  return sessions
      .map(
        (s) => s
            .setsFor(exerciseId)
            .where((set) => set.countsTowardRecords)
            .map((set) => set.primaryValue)
            .toList(),
      )
      .where((l) => l.isNotEmpty)
      .toList();
}
