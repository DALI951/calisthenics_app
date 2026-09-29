/// Challenge system (spec §23). Challenges are HEALTHY competition between
/// friends: consistent effort wins, never dangerous max-out attempts.
enum ChallengeType {
  /// "Complete N workouts in the period."
  consistency,

  /// "Complete program day X in the period."
  workoutCompletion,

  /// "Total reps across the period (optionally one exercise)."
  volume,

  /// "Hit a milestone for one exercise in the period (25 push-ups, 60s plank)."
  progression,

  /// "Total training minutes in the period."
  time,

  /// "Compare improvement over the period — higher progress at the end."
  headToHead;

  String get label => switch (this) {
    ChallengeType.consistency => 'Consistency',
    ChallengeType.workoutCompletion => 'Workout day',
    ChallengeType.volume => 'Volume',
    ChallengeType.progression => 'Progression',
    ChallengeType.time => 'Training time',
    ChallengeType.headToHead => 'Head to head',
  };

  String get description => switch (this) {
    ChallengeType.consistency => 'Complete N workouts in the period.',
    ChallengeType.workoutCompletion =>
      'Finish a program day inside '
          'the period.',
    ChallengeType.volume => 'Bank total reps in the period.',
    ChallengeType.progression =>
      'Hit a milestone for one exercise in the period.',
    ChallengeType.time => 'Train for N minutes in the period.',
    ChallengeType.headToHead => 'Whoever improves more by the end takes it.',
  };

  /// Unit label for progress text.
  String unit(ExerciseMetricLike metric) => switch (this) {
    ChallengeType.consistency || ChallengeType.workoutCompletion => 'workouts',
    ChallengeType.volume => 'reps',
    ChallengeType.progression => metric.isSeconds ? 'seconds' : 'reps',
    ChallengeType.time => 'minutes',
    ChallengeType.headToHead => 'reps',
  };

  bool get needsExercise =>
      this == ChallengeType.progression || this == ChallengeType.volume;

  /// Only these two can end early with a winner (target reached); the rest
  /// are decided when the period closes.
  bool get targetBased =>
      this != ChallengeType.headToHead &&
      this != ChallengeType.workoutCompletion;
}

/// Tiny local mirror of `ExerciseMetric` so the domain layer stays free of
/// feature imports (spec §15 layered design).
enum ExerciseMetricLike {
  reps,
  seconds;

  bool get isSeconds => this == ExerciseMetricLike.seconds;
}

enum ChallengeStatus {
  pending,
  accepted,
  active,
  completed,
  expired,
  declined,
  cancelled;

  bool get isOver => switch (this) {
    ChallengeStatus.completed ||
    ChallengeStatus.expired ||
    ChallengeStatus.declined ||
    ChallengeStatus.cancelled => true,
    _ => false,
  };

  bool get isLive =>
      this == ChallengeStatus.accepted || this == ChallengeStatus.active;
}

/// Immutable challenge definition (stored in Firestore `challenges/{id}`).
class Challenge {
  const Challenge({
    required this.id,
    required this.creatorUid,
    required this.creatorHandle,
    required this.opponentUid,
    required this.opponentHandle,
    required this.type,
    required this.target,
    required this.startsAt,
    required this.endsAt,
    required this.createdAt,
    this.exerciseId,
    this.exerciseName,
    this.dayName,
    this.status = ChallengeStatus.pending,
    this.result,
  });

  final String id;
  final String creatorUid;
  final String creatorHandle;
  final String opponentUid;
  final String opponentHandle;
  final ChallengeType type;
  final int target;
  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime createdAt;
  final String? exerciseId;
  final String? exerciseName;
  final String? dayName;
  final ChallengeStatus status;
  final ChallengeResult? result;

  bool get isHeadToHead => type == ChallengeType.headToHead;

  String title(String meUid) => switch (type) {
    ChallengeType.consistency => '$target workouts in $_periodDays days',
    ChallengeType.workoutCompletion => 'Complete ${dayName ?? "a workout"}',
    ChallengeType.volume =>
      exerciseId == null
          ? '$target reps in $_periodDays days'
          : '${_scopeLabel()} · $target reps',
    ChallengeType.progression => '${_scopeLabel()} → $target',
    ChallengeType.time => '$target training minutes',
    ChallengeType.headToHead => 'Who improves more in $_periodDays days?',
  };

  String _scopeLabel() =>
      exerciseName ??
      exerciseId ??
      (type == ChallengeType.workoutCompletion
          ? dayName ?? 'workout'
          : 'all exercises');

  int get _periodDays => endsAt.difference(startsAt).inDays.clamp(1, 999);

  String opponentOf(String uid) =>
      uid == creatorUid ? opponentHandle : creatorHandle;
  String opponentUidOf(String uid) =>
      uid == creatorUid ? opponentUid : creatorUid;

  Challenge copyWith({ChallengeStatus? status, ChallengeResult? result}) =>
      Challenge(
        id: id,
        creatorUid: creatorUid,
        creatorHandle: creatorHandle,
        opponentUid: opponentUid,
        opponentHandle: opponentHandle,
        type: type,
        target: target,
        startsAt: startsAt,
        endsAt: endsAt,
        createdAt: createdAt,
        exerciseId: exerciseId,
        exerciseName: exerciseName,
        dayName: dayName,
        status: status ?? this.status,
        result: result ?? this.result,
      );

  Map<String, Object?> toStorage() => {
    'id': id,
    'creatorUid': creatorUid,
    'creatorHandle': creatorHandle,
    'opponentUid': opponentUid,
    'opponentHandle': opponentHandle,
    'type': type.name,
    'target': target,
    'startsAt': startsAt.toIso8601String(),
    'endsAt': endsAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    if (exerciseId != null) 'exerciseId': exerciseId,
    if (exerciseName != null) 'exerciseName': exerciseName,
    if (dayName != null) 'dayName': dayName,
    'status': status.name,
    if (result != null) 'result': result!.toStorage(),
  };

  static Challenge fromStorage(Map<String, Object?> m) => Challenge(
    id: m['id']! as String,
    creatorUid: m['creatorUid']! as String,
    creatorHandle: m['creatorHandle']! as String,
    opponentUid: m['opponentUid']! as String,
    opponentHandle: m['opponentHandle']! as String,
    type: ChallengeType.values.byName(m['type']! as String),
    target: (m['target']! as num).toInt(),
    startsAt: DateTime.parse(m['startsAt']! as String).toUtc(),
    endsAt: DateTime.parse(m['endsAt']! as String).toUtc(),
    createdAt: DateTime.parse(m['createdAt']! as String).toUtc(),
    exerciseId: m['exerciseId'] as String?,
    exerciseName: m['exerciseName'] as String?,
    dayName: m['dayName'] as String?,
    status: ChallengeStatus.values.byName((m['status'] ?? 'pending') as String),
    result: m['result'] == null
        ? null
        : ChallengeResult.fromStorage(m['result']! as Map<String, Object?>),
  );
}

/// Progress for ONE participant. Never declared by the opponent: each client
/// writes only its own progress doc, derived from its immutable history
/// (spec §23 "clients cannot arbitrarily declare challenge victories").
class ChallengeProgress {
  const ChallengeProgress({
    required this.challengeId,
    required this.uid,
    required this.value,
    required this.target,
    required this.unitLabel,
    required this.evidenceSessionIds,
    required this.updatedAt,
  });

  final String challengeId;
  final String uid;
  final int value;
  final int target;
  final String unitLabel;

  /// Ids of the sessions this progress was derived from — the audit trail.
  final List<String> evidenceSessionIds;
  final DateTime updatedAt;

  bool get completed => value >= target;
  double get fraction =>
      target <= 0 ? 0 : (value / target).clamp(0.0, 1.0).toDouble();

  Map<String, Object?> toStorage() => {
    'challengeId': challengeId,
    'uid': uid,
    'value': value,
    'target': target,
    'unitLabel': unitLabel,
    'evidence': evidenceSessionIds,
    'updatedAt': updatedAt.toIso8601String(),
  };

  static ChallengeProgress fromStorage(Map<String, Object?> m) =>
      ChallengeProgress(
        challengeId: m['challengeId']! as String,
        uid: m['uid']! as String,
        value: (m['value']! as num).toInt(),
        target: (m['target']! as num).toInt(),
        unitLabel: m['unitLabel'] as String? ?? '',
        evidenceSessionIds: [
          for (final e in (m['evidence'] as List<dynamic>? ?? const []))
            e as String,
        ],
        updatedAt: DateTime.parse(m['updatedAt']! as String).toUtc(),
      );
}

/// Verified outcome, decided by [ChallengeEngine] from evidence.
class ChallengeResult {
  const ChallengeResult({
    required this.winnerUid,
    required this.isDraw,
    required this.finalValues,
    required this.decidedAt,
    required this.decidedBy,
  });

  final String? winnerUid;
  final bool isDraw;
  final Map<String, int> finalValues;
  final DateTime decidedAt;

  /// `'engine-v1'` — provenance tag. Clients cannot set this to something
  /// else; Phase 12 rules reject unknown values.
  final String decidedBy;

  Map<String, Object?> toStorage() => {
    'winnerUid': winnerUid,
    'isDraw': isDraw,
    'finalValues': finalValues,
    'decidedAt': decidedAt.toIso8601String(),
    'decidedBy': decidedBy,
  };

  static ChallengeResult fromStorage(Map<String, Object?> m) => ChallengeResult(
    winnerUid: m['winnerUid'] as String?,
    isDraw: (m['isDraw'] ?? false) as bool,
    finalValues: {
      for (final e in (m['finalValues'] as Map? ?? const {}).entries)
        e.key as String: (e.value as num).toInt(),
    },
    decidedAt: DateTime.parse(m['decidedAt']! as String).toUtc(),
    decidedBy: m['decidedBy'] as String? ?? 'engine-v1',
  );
}
