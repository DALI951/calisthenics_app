import 'dart:async';
import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_ids.dart';
import '../../exercises/data/exercise_library.dart';
import '../../presence/data/presence_providers.dart';
import '../../workouts/domain/workout_program.dart';
import '../domain/set_entry.dart';
import '../domain/workout_session.dart';
import '../data/workout_history_repository.dart';

part 'workout_session_controller.g.dart';

/// Drives the live workout (spec §14): start → sets → rest → next → summary.
///
/// The session is persisted to SharedPreferences on EVERY change (spec:
/// "never lose workout progress because the user accidentally navigates
/// away" — draft survives process death too). Completed sessions go to
/// [WorkoutHistoryRepository] as immutable records.
@Riverpod(keepAlive: true)
class WorkoutSessionController extends _$WorkoutSessionController {
  static const _draftKey = '${AppIds.prefPrefix}session.draft.v1';

  @override
  WorkoutSession? build() => null;

  /// Starts a program day. Warm-up phase first (spec §29).
  WorkoutSession start(WorkoutProgram program, ProgramDay day) {
    final session = WorkoutSession(
      id: 'ws_${DateTime.now().microsecondsSinceEpoch}_${DateTime.now().millisecond}',
      programId: program.id,
      programVersion: program.version,
      dayName: day.name,
      dayNumber: day.dayNumber,
      startedAt: DateTime.now().toUtc(),
      phase: WorkoutPhase.warmup,
      exercises: day.exercises
          .map(
            (p) => SessionExercise.fromPlanned(
              p,
              name: ExerciseLibrary.byId(p.exerciseId)?.name ?? p.exerciseId,
            ),
          )
          .toList(),
    );
    state = session;
    _save(session);
    // Live presence for friends (spec §22) — best-effort, never blocks.
    unawaited(
      ref
          .read(presenceRepositoryProvider)
          .goOnlineForTraining(
            dayName: day.name,
            exerciseName: session.exercises.isEmpty
                ? ''
                : session.exercises.first.name,
          ),
    );
    return session;
  }

  /// Pushes the current exercise to friends when it changes (throttled —
  /// only on exercise switch, not on every set).
  void _touchPresence() {
    final s = state;
    if (s == null || s.phase == WorkoutPhase.finished) return;
    final idx = s.currentExerciseIndex(s.sets);
    if (idx < 0 || idx >= s.exercises.length) return;
    final name = s.exercises[idx].name;
    if (name == _lastPresenceExercise) return;
    _lastPresenceExercise = name;
    unawaited(
      ref
          .read(presenceRepositoryProvider)
          .goOnlineForTraining(dayName: s.dayName, exerciseName: name),
    );
  }

  String? _lastPresenceExercise;

  /// Restores a killed-session draft if one exists (called on app start).
  Future<WorkoutSession?> restoreDraft() async {
    if (state != null) return state;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null) return null;
    try {
      final restored = WorkoutSession.fromStorage(
        jsonDecode(raw) as Map<String, Object?>,
      );
      if (restored.phase == WorkoutPhase.finished || restored.endedAt != null) {
        await prefs.remove(_draftKey);
        return null;
      }
      state = restored;
      return restored;
    } catch (_) {
      return null;
    }
  }

  void beginWorking() {
    final s = state;
    if (s == null) return;
    state = s.copyWith(phase: WorkoutPhase.working);
    _save(s);
  }

  /// Current exercise (by submitted-set count) and the next set number.
  ({SessionExercise exercise, int setNumber}) get current {
    final s = state!;
    final idx = s.currentExerciseIndex(s.sets);
    final ex = s.exercises[idx];
    final done = s.setsFor(ex.exerciseId).length;
    return (exercise: ex, setNumber: done + 1);
  }

  /// Whether this exercise has no more sets to record.
  bool _exerciseComplete(SessionExercise ex) =>
      state!.setsFor(ex.exerciseId).length >= ex.sets;

  Future<void> recordSet({
    int? reps,
    int? seconds,
    int assistedReps = 0,
    String? note,
    bool painReported = false,
  }) async {
    final s = state;
    if (s == null) return;
    final cur = current;
    final entry = SetEntry(
      id: 'set_${DateTime.now().microsecondsSinceEpoch}_${_rand()}',
      exerciseId: cur.exercise.exerciseId,
      setNumber: cur.setNumber,
      reps: reps,
      seconds: seconds,
      assistedReps: assistedReps,
      note: note,
      painReported: painReported,
      completedAt: DateTime.now().toUtc(),
    );
    final sets = [...s.sets, entry];

    final exerciseStillLeft = _exerciseComplete(cur.exercise);
    WorkoutPhase phase;
    if (_allExercisesDone(sets)) {
      phase = WorkoutPhase.finished;
    } else if (exerciseStillLeft) {
      phase = WorkoutPhase.resting;
    } else {
      phase = WorkoutPhase.working;
    }

    state = s.copyWith(sets: sets, phase: phase);
    _save(state!);
    _touchPresence();
  }

  void skipSet() {
    final s = state;
    if (s == null) return;
    final cur = current;
    final entry = SetEntry(
      id: 'set_${DateTime.now().microsecondsSinceEpoch}_${_rand()}',
      exerciseId: cur.exercise.exerciseId,
      setNumber: cur.setNumber,
      skipped: true,
      completedAt: DateTime.now().toUtc(),
    );
    final sets = [...s.sets, entry];
    final phase = _allExercisesDone(sets)
        ? WorkoutPhase.finished
        : _exerciseComplete(cur.exercise)
        ? WorkoutPhase.resting
        : WorkoutPhase.working;
    state = s.copyWith(sets: sets, phase: phase);
    _save(state!);
    _touchPresence();
  }

  /// Undo the last recorded set (spec §14).
  void undoLastSet() {
    final s = state;
    if (s == null || s.sets.isEmpty) return;
    final sets = [...s.sets]..removeLast();
    state = s.copyWith(sets: sets, phase: WorkoutPhase.working);
    _save(state!);
    _touchPresence();
  }

  /// Swap the CURRENT exercise for a different library movement (spec §14).
  void substituteExercise(String newExerciseId) {
    final s = state;
    if (s == null) return;
    final cur = current;
    final replacement = ExerciseLibrary.byId(newExerciseId);
    if (replacement == null || replacement.id == cur.exercise.exerciseId) {
      return;
    }

    final exercises = s.exercises.map((e) {
      if (e.exerciseId != cur.exercise.exerciseId) return e;
      return SessionExercise(
        exerciseId: replacement.id,
        name: replacement.name,
        sets: e.sets,
        targetMin: e.targetMin,
        targetMax: e.targetMax,
        targetSecondsMin: e.targetSecondsMin,
        targetSecondsMax: e.targetSecondsMax,
        restSeconds: e.restSeconds,
        note: 'Substituted from ${cur.exercise.name}',
        substitutedFrom: cur.exercise.exerciseId,
      );
    }).toList();
    state = s.copyWith(exercises: exercises);
    _save(state!);
    _lastPresenceExercise = null; // force refresh with the new name
    _touchPresence();
  }

  /// Start the rest timer for the CURRENT exercise/set.
  ({int seconds, String exerciseId, int setNumber}) restConfig() {
    final cur = current;
    return (
      seconds: cur.exercise.restSeconds ?? 90,
      exerciseId: cur.exercise.exerciseId,
      setNumber: cur.setNumber,
    );
  }

  void _advanceAfterRest() {
    final s = state;
    if (s == null) return;
    if (_allExercisesDone(s.sets)) {
      state = s.copyWith(phase: WorkoutPhase.finished);
      return;
    }
    state = s.copyWith(phase: WorkoutPhase.working);
  }

  /// Rest finished (snoozed or skipped) — back to working (or finished).
  void restDone() => _advanceAfterRest();

  /// User pressed "start next set" early.
  void nextSetNow() => _advanceAfterRest();

  void pauseWorkout() {
    final s = state;
    if (s == null || s.phase == WorkoutPhase.paused) return;
    state = s.copyWith(phase: WorkoutPhase.paused, pausedTotal: s.pausedTotal);
    _save(state!);
  }

  void resumeWorkout() {
    final s = state;
    if (s == null || s.phase != WorkoutPhase.paused) return;
    state = s.copyWith(phase: WorkoutPhase.working);
    _save(state!);
  }

  /// Finishes the workout: immutable record → history, clear the draft,
  /// expose the completed session for the summary screen.
  Future<WorkoutSession> finish() async {
    final s = state;
    if (s == null) throw StateError('No active session');
    final di = DateTime.now();
    final completed = s.copyWith(
      phase: WorkoutPhase.finished,
      endedAt: di.toUtc(),
    );
    state = null;
    _lastPresenceExercise = null;
    await _clearDraft();
    unawaited(ref.read(presenceRepositoryProvider).stopTraining());
    await ref.read(workoutHistoryRepositoryProvider.notifier).add(completed);
    ref.read(lastCompletedSessionProvider.notifier).state = completed;
    return completed;
  }

  /// Abandon entirely (confirmed by UI) — no record created.
  Future<void> discard() async {
    state = null;
    _lastPresenceExercise = null;
    await _clearDraft();
    unawaited(ref.read(presenceRepositoryProvider).stopTraining());
  }

  bool _allExercisesDone(List<SetEntry> sets) => state!.exercises.every(
    (e) => sets.where((s) => s.exerciseId == e.exerciseId).length >= e.sets,
  );

  void _save(WorkoutSession s) {
    // Fire-and-forget: the in-memory state is the source of truth; the
    // draft is a safety net for process death.
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString(_draftKey, jsonEncode(s.toStorage())),
    );
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  String _rand() => DateTime.now().microsecond.toString();
}

/// The just-finished session, consumed by the summary screen once.
@Riverpod(keepAlive: true)
class LastCompletedSession extends _$LastCompletedSession {
  @override
  WorkoutSession? build() => null;
}

/// Rest timer (spec §15, §70): TIMESTAMP-based — `restUntil` survives
/// rebuilds, navigation, backgrounding and suspension. A lightweight ticker
/// in the UI just re-renders; remaining is always computed from now.
@Riverpod(keepAlive: true)
class RestTimerController extends _$RestTimerController {
  static const _key = '${AppIds.prefPrefix}session.rest.v1';

  @override
  RestTimerState? build() => null;

  void start(
    int seconds, {
    required String exerciseId,
    required int setNumber,
  }) {
    final now = DateTime.now();
    state = RestTimerState(
      exerciseId: exerciseId,
      setNumber: setNumber,
      restUntil: now.add(Duration(seconds: seconds)),
      totalSeconds: seconds,
      pausedRemaining: null,
    );
    _save(state!);
  }

  void addSeconds(int delta) {
    final t = state;
    if (t == null) return;
    if (t.pausedRemaining != null) {
      var next = t.pausedRemaining! + Duration(seconds: delta);
      if (next.isNegative) next = Duration.zero;
      if (next > const Duration(hours: 1)) next = const Duration(hours: 1);
      state = t.copyWith(pausedRemaining: next);
    } else {
      if (t.restUntil.isBefore(DateTime.now())) return;
      final restUntil = t.restUntil.add(Duration(seconds: delta));
      state = t.copyWith(restUntil: restUntil);
    }
    _save(state!);
  }

  void pause() {
    final t = state;
    if (t == null || t.pausedRemaining != null) return;
    final remaining = t.restUntil.difference(DateTime.now());
    state = t.copyWith(
      pausedRemaining: remaining.isNegative ? Duration.zero : remaining,
    );
    _save(state!);
  }

  void resume() {
    final t = state;
    if (t == null || t.pausedRemaining == null) return;
    state = t.copyWith(
      restUntil: DateTime.now().add(t.pausedRemaining!),
      pausedRemaining: null,
    );
    _save(state!);
  }

  void skip() {
    state = null;
    _clear();
  }

  void _save(RestTimerState t) {
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString(_key, jsonEncode(t.toJson())),
    );
  }

  Future<void> _clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

/// Immutable rest timer state (spec §15).
class RestTimerState {
  const RestTimerState({
    required this.exerciseId,
    required this.setNumber,
    required this.restUntil,
    required this.totalSeconds,
    this.pausedRemaining,
  });

  final String exerciseId;
  final int setNumber;
  final DateTime restUntil;
  final int totalSeconds;

  /// Set while paused; null = running. Mutually exclusive with [restUntil]
  /// being authoritative.
  final Duration? pausedRemaining;

  Duration remainingAt(DateTime now) {
    final p = pausedRemaining;
    if (p != null) return p;
    final d = restUntil.difference(now);
    return d.isNegative ? Duration.zero : d;
  }

  bool get isPaused => pausedRemaining != null;

  static const _unset = Object();

  /// [pausedRemaining] uses an explicit-null sentinel: clearing the pause
  /// really clears it (a plain `??` fallback could not).
  RestTimerState copyWith({
    DateTime? restUntil,
    Object? pausedRemaining = _unset,
  }) => RestTimerState(
    exerciseId: exerciseId,
    setNumber: setNumber,
    restUntil: restUntil ?? this.restUntil,
    totalSeconds: totalSeconds,
    pausedRemaining: identical(pausedRemaining, _unset)
        ? this.pausedRemaining
        : pausedRemaining as Duration?,
  );

  Map<String, Object?> toJson() => {
    'exerciseId': exerciseId,
    'setNumber': setNumber,
    'restUntil': restUntil.toIso8601String(),
    'totalSeconds': totalSeconds,
    'pausedRemainingMs': pausedRemaining?.inMilliseconds,
  };

  factory RestTimerState.fromJson(Map<String, Object?> json) => RestTimerState(
    exerciseId: json['exerciseId'] as String,
    setNumber: json['setNumber'] as int,
    restUntil: DateTime.parse(json['restUntil'] as String),
    totalSeconds: json['totalSeconds'] as int,
    pausedRemaining: json['pausedRemainingMs'] == null
        ? null
        : Duration(milliseconds: json['pausedRemainingMs'] as int),
  );
}

/// 1-second tick that only triggers UI rebuilds — never the source of
/// truth for time (spec §70).
@Riverpod(keepAlive: true)
class RestTicker extends _$RestTicker {
  @override
  Stream<int> build() {
    return Stream<int>.periodic(const Duration(seconds: 1), (i) => i);
  }
}
