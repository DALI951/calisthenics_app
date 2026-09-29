/// Synchronized workout state for "Train Together" (spec §22). This is a
/// SHARED workout experience, never surveillance: each side publishes only
/// the exercise, the set number and the phase. No camera, no heart rate, no
/// location.
enum LivePhase {
  /// Actively doing the set.
  working,

  /// I finished my set, waiting for my partner.
  waiting,

  /// Both finished — rest timer running.
  resting,

  /// Both are done with the current exercise.
  exerciseDone,

  /// Whole workout finished.
  finished,
}

/// One participant's published state.
class LiveAthleteState {
  const LiveAthleteState({
    required this.uid,
    required this.handle,
    required this.exerciseName,
    required this.setNumber,
    required this.totalSets,
    required this.phase,
    required this.updatedAt,
    this.online = true,
  });

  final String uid;
  final String handle;
  final String exerciseName;
  final int setNumber;
  final int totalSets;
  final LivePhase phase;
  final DateTime updatedAt;

  /// False when the client dropped off (RTDB onDisconnect removes the node).
  final bool online;

  bool get setComplete =>
      phase == LivePhase.waiting || phase == LivePhase.resting;

  LiveAthleteState copyWith({
    String? exerciseName,
    int? setNumber,
    int? totalSets,
    LivePhase? phase,
    bool? online,
  }) => LiveAthleteState(
    uid: uid,
    handle: handle,
    exerciseName: exerciseName ?? this.exerciseName,
    setNumber: setNumber ?? this.setNumber,
    totalSets: totalSets ?? this.totalSets,
    phase: phase ?? this.phase,
    updatedAt: updatedAt,
    online: online ?? this.online,
  );

  Map<String, Object?> toStorage() => {
    'uid': uid,
    'handle': handle,
    'exercise': exerciseName,
    'setNumber': setNumber,
    'totalSets': totalSets,
    'phase': phase.name,
    'at': updatedAt.millisecondsSinceEpoch,
  };

  static LiveAthleteState? fromStorage(Map<Object?, Object?> raw) {
    final at = raw['at'];
    final phase = raw['phase'];
    return LiveAthleteState(
      uid: raw['uid'] as String? ?? '',
      handle: raw['handle'] as String? ?? 'friend',
      exerciseName: raw['exercise'] as String? ?? '',
      setNumber: (raw['setNumber'] as num?)?.toInt() ?? 0,
      totalSets: (raw['totalSets'] as num?)?.toInt() ?? 0,
      phase: phase is String
          ? LivePhase.values.firstWhere(
              (p) => p.name == phase,
              orElse: () => LivePhase.working,
            )
          : LivePhase.working,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (at as num?)?.toInt() ?? 0,
        isUtc: true,
      ),
    );
  }
}

/// What both sides see right now (derived, never stored).
class LivePairState {
  const LivePairState({
    required this.me,
    required this.partner,
    required this.restSeconds,
    required this.restStartedAt,
  });

  final LiveAthleteState? me;
  final LiveAthleteState? partner;

  /// Rest length published by whoever is ahead (kept identical for both).
  final int restSeconds;
  final DateTime? restStartedAt;

  bool get partnerOnline => partner?.online ?? false;
  bool get partnerSetComplete => partner?.setComplete ?? false;
  bool get meSetComplete => me?.setComplete ?? false;

  /// Rest only starts when BOTH finished the set (spec §22) — the whole
  /// point of training side by side.
  bool get restRunning =>
      restStartedAt != null && meSetComplete && partnerSetComplete;

  Duration? get restRemaining {
    final started = restStartedAt;
    if (!restRunning || started == null) return null;
    final elapsed = DateTime.now().toUtc().difference(started);
    final left = Duration(seconds: restSeconds) - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  /// Progress label: "Push-ups — Set 2/4".
  String get exerciseLabel {
    final name = me?.exerciseName.isNotEmpty == true
        ? me!.exerciseName
        : partner?.exerciseName ?? '';
    if (name.isEmpty) return 'No exercise yet';
    final n = me?.setNumber ?? partner?.setNumber ?? 0;
    final t = me?.totalSets ?? partner?.totalSets ?? 0;
    return t == 0 ? name : '$name — Set $n/$t';
  }
}

/// A cheer sent by a partner (encouragement, spec §22).
class Cheer {
  const Cheer({
    required this.fromHandle,
    required this.emoji,
    required this.at,
  });
  final String fromHandle;
  final String emoji;
  final DateTime at;
}
