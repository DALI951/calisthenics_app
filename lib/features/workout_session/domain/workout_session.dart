import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

import '../../workouts/domain/workout_program.dart';
import 'set_entry.dart';

part 'workout_session.freezed.dart';

/// Where a training session currently is in its lifecycle.
enum WorkoutPhase {
  /// Warm-up intro step.
  warmup,

  /// Recording sets for an exercise.
  working,

  /// Rest between sets.
  resting,

  /// Session paused (time excluded from duration).
  paused,

  /// Finished — waiting to open the summary.
  finished,
}

/// The planned movement as it appeared when the session started. Target
/// ranges are SNAPSHOTTED so old sessions stay correct after program updates
/// (spec §60, §61).
@freezed
abstract class SessionExercise with _$SessionExercise {
  const factory SessionExercise({
    required String exerciseId,
    required String name,

    /// Total planned sets for this exercise in the session.
    required int sets,

    int? targetMin,
    int? targetMax,
    int? targetSecondsMin,
    int? targetSecondsMax,
    int? restSeconds,
    String? note,

    /// Original planned id BEFORE substitution (same when untouched).
    @Default(null) String? substitutedFrom,
  }) = _SessionExercise;

  const SessionExercise._();

  /// JSON is hand-rolled: freezed/json_serializable cannot resolve
  /// converters for models declared in OTHER libraries.
  factory SessionExercise.fromStorage(Map<String, Object?> json) =>
      SessionExercise(
        exerciseId: json['exerciseId'] as String,
        name: json['name'] as String,
        sets: json['sets'] as int,
        targetMin: json['targetMin'] as int?,
        targetMax: json['targetMax'] as int?,
        targetSecondsMin: json['targetSecondsMin'] as int?,
        targetSecondsMax: json['targetSecondsMax'] as int?,
        restSeconds: json['restSeconds'] as int?,
        note: json['note'] as String?,
        substitutedFrom: json['substitutedFrom'] as String?,
      );

  Map<String, Object?> toStorage() => {
    'exerciseId': exerciseId,
    'name': name,
    'sets': sets,
    'targetMin': targetMin,
    'targetMax': targetMax,
    'targetSecondsMin': targetSecondsMin,
    'targetSecondsMax': targetSecondsMax,
    'restSeconds': restSeconds,
    'note': note,
    'substitutedFrom': substitutedFrom,
  };

  factory SessionExercise.fromPlanned(
    PlannedExercise planned, {
    required String name,
  }) => SessionExercise(
    exerciseId: planned.exerciseId,
    name: name,
    sets: planned.sets,
    targetMin: planned.targetMin,
    targetMax: planned.targetMax,
    targetSecondsMin: planned.targetSecondsMin,
    targetSecondsMax: planned.targetSecondsMax,
    restSeconds: planned.restSeconds,
    note: planned.note,
  );

  /// "4 × 8–15" style label (reuses the planned target logic).
  String get targetLabel {
    if (targetSecondsMin != null && targetSecondsMax != null) {
      if (targetSecondsMin == targetSecondsMax) {
        return '$sets × ${targetSecondsMin}s';
      }
      return '$sets × ${targetSecondsMin}s–${targetSecondsMax}s';
    }
    if (targetMin != null && targetMax != null) {
      if (targetMin == targetMax) return '$sets × $targetMin';
      return '$sets × $targetMin–$targetMax';
    }
    if (targetMin != null) return '$sets × $targetMin+';
    return '$sets sets';
  }

  bool get isTimed => targetSecondsMin != null || targetSecondsMax != null;
}

/// A complete (or in-progress) workout session (spec §14). Persisted locally
/// on every change; Firestore sync lands in Phase 11 (idempotent, client ids).
@freezed
abstract class WorkoutSession with _$WorkoutSession {
  const factory WorkoutSession({
    /// Client-generated id — stable forever, prevents duplicate sync.
    required String id,
    required String programId,
    @Default(1) int programVersion,
    required String dayName,

    /// 1..7 cycle slot.
    required int dayNumber,

    /// UTC start.
    required DateTime startedAt,
    DateTime? endedAt,
    required List<SessionExercise> exercises,
    @Default(<SetEntry>[]) List<SetEntry> sets,
    @Default(WorkoutPhase.working) WorkoutPhase phase,

    /// Accumulated paused time (excluded from duration, spec §14).
    @Default(Duration.zero) Duration pausedTotal,
  }) = _WorkoutSession;

  const WorkoutSession._();

  factory WorkoutSession.fromStorage(Map<String, Object?> json) =>
      WorkoutSession(
        id: json['id'] as String,
        programId: json['programId'] as String,
        programVersion: json['programVersion'] as int? ?? 1,
        dayName: json['dayName'] as String,
        dayNumber: json['dayNumber'] as int,
        startedAt: DateTime.parse(json['startedAt'] as String),
        endedAt: json['endedAt'] == null
            ? null
            : DateTime.parse(json['endedAt'] as String),
        exercises: (json['exercises'] as List<dynamic>)
            .map(
              (e) => SessionExercise.fromStorage(
                (e as Map<Object?, Object?>).cast<String, Object?>(),
              ),
            )
            .toList(),
        sets: (json['sets'] as List<dynamic>? ?? const [])
            .map(
              (e) => SetEntry.fromStorage(
                (e as Map<Object?, Object?>).cast<String, Object?>(),
              ),
            )
            .toList(),
        phase: WorkoutPhase.values.firstWhere(
          (p) => p.name == json['phase'],
          orElse: () => WorkoutPhase.working,
        ),
        pausedTotal: Duration(microseconds: json['pausedTotal'] as int? ?? 0),
      );

  Map<String, Object?> toStorage() => {
    'id': id,
    'programId': programId,
    'programVersion': programVersion,
    'dayName': dayName,
    'dayNumber': dayNumber,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt?.toIso8601String(),
    'exercises': exercises.map((e) => e.toStorage()).toList(),
    'sets': sets.map((e) => e.toStorage()).toList(),
    'phase': phase.name,
    'pausedTotal': pausedTotal.inMicroseconds,
  };

  /// Duration: now - startedAt - pausedTotal while active; endedAt otherwise.
  Duration duration(DateTime now) {
    final end = endedAt ?? now;
    return end.difference(startedAt) - pausedTotal;
  }

  int get completedSetCount => sets.length;
  int get totalReps => sets
      .where((s) => !s.skipped && s.reps != null)
      .fold(0, (a, s) => a + (s.reps ?? 0));
  int get totalSeconds => sets
      .where((s) => !s.skipped && s.seconds != null)
      .fold(0, (a, s) => a + (s.seconds ?? 0));
  int get skippedSetCount => sets.where((s) => s.skipped).length;

  /// Index of the exercise currently being worked — the EARLIEST exercise
  /// whose set count is still below its target (scan forward; later
  /// exercises haven't started yet).
  int currentExerciseIndex(List<SetEntry> allSets) {
    for (var i = 0; i < exercises.length; i++) {
      final done = allSets
          .where((s) => s.exerciseId == exercises[i].exerciseId)
          .length;
      if (done < exercises[i].sets) return i;
    }
    return exercises.length - 1;
  }

  SetEntry? get lastSet => sets.isEmpty ? null : sets.last;

  /// Submissions for an exercise (all sets, including skipped).
  List<SetEntry> setsFor(String exerciseId) =>
      sets.where((s) => s.exerciseId == exerciseId).toList();

  bool get isComplete =>
      endedAt != null ||
      exercises.every((e) => setsFor(e.exerciseId).length >= e.sets);
}
