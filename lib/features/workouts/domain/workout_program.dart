import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

part 'workout_program.freezed.dart';
part 'workout_program.g.dart';

/// A single planned exercise inside a program day.
@freezed
abstract class PlannedExercise with _$PlannedExercise {
  const factory PlannedExercise({
    required String exerciseId,

    /// Total sets.
    required int sets,

    /// Target range per set (reps).
    int? targetMin,

    /// Target range per set (reps).
    int? targetMax,

    /// Target seconds when metric is time.
    int? targetSecondsMin,
    int? targetSecondsMax,

    /// Rest after completing this movement's sets (or per-set when set).
    @Default(90) int restSeconds,

    /// Human note ("3 rounds", "each side").
    String? note,
  }) = _PlannedExercise;

  const PlannedExercise._();

  factory PlannedExercise.fromJson(Map<String, Object?> json) =>
      _$PlannedExerciseFromJson(json);

  /// Display string like "4 × 8–15" or "3 × 20–40s".
  String get targetLabel {
    if (targetSecondsMin != null && targetSecondsMax != null) {
      if (targetSecondsMin == targetSecondsMax) {
        return '$sets × ${targetSecondsMin}s';
      }
      return '$sets × $targetSecondsMin–$targetSecondsMax'
          's';
    }
    if (targetMin != null && targetMax != null) {
      if (targetMin == targetMax) return '$sets × $targetMin';
      return '$sets × $targetMin–$targetMax';
    }
    if (targetMin != null) return '$sets × $targetMin+';
    return '$sets sets';
  }
}

/// One training/rest day of the program (spec §9: the 4-day split).
enum ProgramDayType {
  training('Training'),
  rest('Rest');

  const ProgramDayType(this.label);
  final String label;
}

@freezed
abstract class ProgramDay with _$ProgramDay {
  const factory ProgramDay({
    /// 1..7 (weekday slot in the 7-day cycle).
    required int dayNumber,
    required ProgramDayType type,

    /// "Push + Core", "Pull + Core", "Legs + Core", "Full Body", "Rest".
    required String name,
    String? focus,
    @Default(<PlannedExercise>[]) List<PlannedExercise> exercises,
    String? note,
  }) = _ProgramDay;

  const ProgramDay._();

  factory ProgramDay.fromJson(Map<String, Object?> json) =>
      _$ProgramDayFromJson(json);

  ProgramDay? get asTraining => type == ProgramDayType.training ? this : null;
}

/// A named program (Beginner 4-day, later Intermediate/Advanced...).
@freezed
abstract class WorkoutProgram with _$WorkoutProgram {
  const factory WorkoutProgram({
    required String id,
    required String name,
    required int version,

    /// 7 entries, dayNumber 1..7 in order.
    required List<ProgramDay> days,
    String? description,
    @Default(<String>[]) List<String> prerequisiteProgramIds,
  }) = _WorkoutProgram;

  const WorkoutProgram._();

  factory WorkoutProgram.fromJson(Map<String, Object?> json) =>
      _$WorkoutProgramFromJson(json);

  /// Day matching `weekdaySlot` (1..7). Days repeat every 7-day cycle.
  ProgramDay dayAt(int weekdaySlot) {
    for (final d in days) {
      if (d.dayNumber == weekdaySlot) return d;
    }
    return days.first;
  }

  /// The training day for `weekdaySlot`, or the next one if it's a rest day
  /// (self-inclusive: a training day maps to itself, e.g. "what trains today").
  /// The next training day on or after [weekdaySlot], wrapping the week.
  ///
  /// Throws when the week has no training day at all — an empty program is a
  /// real state now that there is no preset, and silently returning a rest day
  /// would send the athlete to an empty session.
  ProgramDay nextTrainingDayFrom(int weekdaySlot) {
    for (var i = 0; i < 7; i++) {
      final slot = ((weekdaySlot - 1 + i) % 7) + 1;
      final day = dayAt(slot);
      if (day.type == ProgramDayType.training) return day;
    }
    throw StateError(
      'This week has no training days yet. Build a session or programme a day.',
    );
  }

  /// First training day in the week, or null when nothing is programmed.
  ProgramDay? get firstTrainingDay {
    for (final d in days) {
      if (d.type == ProgramDayType.training && d.exercises.isNotEmpty) {
        return d;
      }
    }
    return null;
  }
}
