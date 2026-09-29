import 'package:calisthenics_app/features/challenges/domain/challenge.dart';
import 'package:calisthenics_app/features/challenges/domain/challenge_engine.dart';
import 'package:calisthenics_app/features/exercises/data/exercise_library.dart';
import 'package:calisthenics_app/features/workout_session/domain/set_entry.dart';
import 'package:calisthenics_app/features/workout_session/domain/workout_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 29, 12);
  final start = now.subtract(const Duration(days: 3));
  final end = now.add(const Duration(days: 4));

  Challenge challenge({
    ChallengeType type = ChallengeType.consistency,
    int target = 3,
    String? exerciseId,
    String? dayName,
    DateTime? startsAt,
    DateTime? endsAt,
    ChallengeStatus status = ChallengeStatus.active,
  }) => Challenge(
    id: 'ch_1',
    creatorUid: 'me',
    creatorHandle: 'dali',
    opponentUid: 'ayoub',
    opponentHandle: 'ayoub',
    type: type,
    target: target,
    startsAt: startsAt ?? start,
    endsAt: endsAt ?? end,
    createdAt: start,
    exerciseId: exerciseId,
    exerciseName: exerciseId == null
        ? null
        : ExerciseLibrary.byId(exerciseId)?.name,
    dayName: dayName,
    status: status,
  );

  WorkoutSession session({
    required String id,
    int daysAgo = 1,
    String dayName = 'Push + Core',
    List<SetEntry> sets = const [],
  }) {
    final started = now.subtract(Duration(days: daysAgo));
    return WorkoutSession(
      id: id,
      programId: 'beginner4',
      programVersion: 1,
      dayName: dayName,
      dayNumber: 1,
      startedAt: started,
      endedAt: started.add(const Duration(minutes: 45)),
      phase: WorkoutPhase.finished,
      exercises: const [],
      sets: sets,
    );
  }

  SetEntry set(String exerciseId, {int reps = 0, int seconds = 0}) => SetEntry(
    id: 's_$exerciseId$reps$seconds',
    exerciseId: exerciseId,
    setNumber: 1,
    reps: reps == 0 ? null : reps,
    seconds: seconds == 0 ? null : seconds,
    completedAt: now,
  );

  // ---- safety guardrails (spec §23) -------------------------------------

  test('validateTarget rejects zero and absurd targets', () {
    expect(
      ChallengeEngine.validateTarget(
        type: ChallengeType.consistency,
        target: 0,
      ),
      isNotNull,
    );
    // 22 workouts in a period = max-effort cult behavior. Refused.
    expect(
      ChallengeEngine.validateTarget(
        type: ChallengeType.consistency,
        target: 22,
      ),
      isNotNull,
    );
    expect(
      ChallengeEngine.validateTarget(
        type: ChallengeType.consistency,
        target: 3,
      ),
      isNull,
    );
  });

  test('validateTarget caps progression by metric (no max-out planks)', () {
    expect(
      ChallengeEngine.validateTarget(
        type: ChallengeType.progression,
        target: 301,
        metric: ExerciseMetricLike.seconds,
      ),
      isNotNull,
    );
    expect(
      ChallengeEngine.validateTarget(
        type: ChallengeType.progression,
        target: 101,
      ),
      isNotNull,
    );
    expect(
      ChallengeEngine.validateTarget(
        type: ChallengeType.progression,
        target: 60,
        metric: ExerciseMetricLike.seconds,
      ),
      isNull,
    );
  });

  test('validatePeriod only allows 3/7/14/30 days', () {
    expect(ChallengeEngine.validatePeriod(7), isNull);
    expect(ChallengeEngine.validatePeriod(5), isNotNull);
  });

  // ---- progress -----------------------------------------------------------

  test('consistency progress counts completed sessions in the window', () {
    final c = challenge(target: 3);
    final history = [
      session(id: 'a', daysAgo: 1),
      session(id: 'b', daysAgo: 2),
      session(id: 'c', daysAgo: 99), // outside window
    ];
    final p = ChallengeEngine.progressFor(
      c,
      'me',
      history,
      metric: ExerciseMetricLike.reps,
      now: now,
    );
    expect(p.value, 2);
    expect(p.evidenceSessionIds, ['a', 'b']);
    expect(p.completed, isFalse);
  });

  test('volume progress sums reps and ignores pain-reported sets', () {
    final c = challenge(type: ChallengeType.volume, target: 50);
    final painful = SetEntry(
      id: 'pain',
      exerciseId: 'push-up',
      setNumber: 2,
      reps: 30,
      painReported: true,
      completedAt: now,
    );
    final history = [
      session(
        id: 'a',
        sets: [set('push-up', reps: 20), painful, set('squat', reps: 15)],
      ),
    ];
    final p = ChallengeEngine.progressFor(
      c,
      'me',
      history,
      metric: ExerciseMetricLike.reps,
      now: now,
    );
    expect(p.value, 35); // pain-reported 30 excluded
    expect(p.completed, isFalse);
  });

  test('progression progress = best set, evidence attached', () {
    final c = challenge(
      type: ChallengeType.progression,
      target: 30,
      exerciseId: 'push-up',
    );
    final history = [
      session(id: 'a', sets: [set('push-up', reps: 12)]),
      session(id: 'b', sets: [set('push-up', reps: 27)]),
    ];
    final p = ChallengeEngine.progressFor(
      c,
      'me',
      history,
      metric: ChallengeEngine.metricFor(c),
      now: now,
    );
    expect(p.value, 27);
    expect(p.evidenceSessionIds, ['a', 'b']);
    expect(p.fraction, closeTo(0.9, 0.001));
  });

  test('time progress sums session minutes', () {
    final c = challenge(type: ChallengeType.time, target: 180);
    final p = ChallengeEngine.progressFor(
      c,
      'me',
      [session(id: 'a'), session(id: 'b')],
      metric: ExerciseMetricLike.reps,
      now: now,
    );
    expect(p.value, 90);
  });

  test('workoutCompletion matches day name case-insensitively', () {
    final c = challenge(
      type: ChallengeType.workoutCompletion,
      target: 1,
      dayName: 'Push + Core',
    );
    final hit = ChallengeEngine.progressFor(
      c,
      'me',
      [session(id: 'a', dayName: 'push + core')],
      metric: ExerciseMetricLike.reps,
      now: now,
    );
    final miss = ChallengeEngine.progressFor(
      c,
      'me',
      [session(id: 'b', dayName: 'Legs')],
      metric: ExerciseMetricLike.reps,
      now: now,
    );
    expect(hit.value, 1);
    expect(miss.value, 0);
  });

  // ---- state machine ------------------------------------------------------

  test('canTransition enforces the spec state machine', () {
    expect(
      ChallengeEngine.canTransition(
        ChallengeStatus.pending,
        ChallengeStatus.accepted,
      ),
      isTrue,
    );
    expect(
      ChallengeEngine.canTransition(
        ChallengeStatus.pending,
        ChallengeStatus.active,
      ),
      isFalse,
    );
    expect(
      ChallengeEngine.canTransition(
        ChallengeStatus.completed,
        ChallengeStatus.active,
      ),
      isFalse,
    );
    expect(
      ChallengeEngine.canTransition(
        ChallengeStatus.active,
        ChallengeStatus.completed,
      ),
      isTrue,
    );
  });

  test('effectiveStatus walks accepted → active → expired over time', () {
    final c = challenge(status: ChallengeStatus.accepted);
    expect(
      ChallengeEngine.effectiveStatus(
        c,
        c.startsAt.subtract(const Duration(days: 1)),
      ),
      ChallengeStatus.accepted,
    );
    expect(ChallengeEngine.effectiveStatus(c, now), ChallengeStatus.active);
    expect(
      ChallengeEngine.effectiveStatus(
        c,
        c.endsAt.add(const Duration(hours: 1)),
      ),
      ChallengeStatus.expired,
    );
  });

  // ---- settlement ---------------------------------------------------------

  test('settle: target reached → completed, higher value takes it', () {
    final c = challenge(target: 20);
    final progress = {
      'me': _p(c, 'me', 25, now),
      'ayoub': _p(c, 'ayoub', 18, now),
    };
    final settled = ChallengeEngine.settle(c, progress, now: now);
    expect(settled.status, ChallengeStatus.completed);
    expect(settled.result!.winnerUid, 'me');
    expect(settled.result!.decidedBy, 'engine-v1');
    expect(settled.result!.isDraw, isFalse);
  });

  test('settle: equal progress → draw, no loser language', () {
    final c = challenge(target: 10);
    final progress = {
      'me': _p(c, 'me', 14, now),
      'ayoub': _p(c, 'ayoub', 14, now),
    };
    final settled = ChallengeEngine.settle(c, progress, now: now);
    expect(settled.status, ChallengeStatus.completed);
    expect(settled.result!.isDraw, isTrue);
    expect(settled.result!.winnerUid, isNull);
  });

  test('settle: nobody reached target by deadline → expired, no winner', () {
    final c = challenge(
      target: 100,
      endsAt: now.subtract(const Duration(hours: 1)),
    );
    final progress = {
      'me': _p(c, 'me', 40, now),
      'ayoub': _p(c, 'ayoub', 30, now),
    };
    final settled = ChallengeEngine.settle(c, progress, now: now);
    expect(settled.status, ChallengeStatus.expired);
    expect(settled.result!.winnerUid, isNull);
    expect(settled.result!.isDraw, isFalse);
  });

  test('settle: head-to-head always has a winner unless tied', () {
    final c = challenge(
      type: ChallengeType.headToHead,
      target: 9999,
      endsAt: now.subtract(const Duration(hours: 1)),
    );
    final progress = {
      'me': _p(c, 'me', 120, now),
      'ayoub': _p(c, 'ayoub', 260, now),
    };
    final settled = ChallengeEngine.settle(c, progress, now: now);
    expect(settled.result!.winnerUid, 'ayoub');
  });

  test('settle is idempotent — result never recomputed', () {
    final c = challenge(
      target: 20,
      endsAt: now.subtract(const Duration(hours: 1)),
    );
    final progress = {
      'me': _p(c, 'me', 25, now),
      'ayoub': _p(c, 'ayoub', 18, now),
    };
    final once = ChallengeEngine.settle(c, progress, now: now);
    final twice = ChallengeEngine.settle(
      once,
      progress,
      now: now.add(const Duration(days: 1)),
    );
    expect(twice.result!.decidedAt, once.result!.decidedAt);
    expect(twice.status, once.status);
  });

  // ---- storage round-trip -------------------------------------------------

  test('challenge survives storage round-trip', () {
    final c =
        challenge(
          type: ChallengeType.progression,
          target: 60,
          exerciseId: 'plank',
          status: ChallengeStatus.completed,
        ).copyWith(
          result: ChallengeResult(
            winnerUid: 'me',
            isDraw: false,
            finalValues: const {'me': 65, 'ayoub': 40},
            decidedAt: now,
            decidedBy: 'engine-v1',
          ),
        );
    final back = Challenge.fromStorage(c.toStorage());
    expect(back.type, ChallengeType.progression);
    expect(back.exerciseId, 'plank');
    expect(back.status, ChallengeStatus.completed);
    expect(back.result!.winnerUid, 'me');
    expect(back.result!.finalValues['me'], 65);
  });

  test('progress survives storage round-trip with evidence', () {
    final back = ChallengeProgress.fromStorage(
      _p(challenge(target: 3), 'me', 3, now).toStorage(),
    );
    expect(back.uid, 'me');
    expect(back.value, 3);
    expect(back.evidenceSessionIds, isNotEmpty);
  });
}

ChallengeProgress _p(Challenge c, String uid, int value, DateTime now) =>
    ChallengeProgress(
      challengeId: c.id,
      uid: uid,
      value: value,
      target: c.target,
      unitLabel: 'reps',
      evidenceSessionIds: const ['s1'],
      updatedAt: now,
    );
