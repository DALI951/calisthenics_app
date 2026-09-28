import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

import 'exercise_enums.dart';

part 'exercise.freezed.dart';
part 'exercise.g.dart';

/// The structured exercise model (spec §12).
///
/// Everything is data — no UI logic here. Versioned so historical workouts
/// that referenced an older definition stay correct (spec §60).
@freezed
abstract class Exercise with _$Exercise {
  const factory Exercise({
    required String id,
    required String name,
    required ExerciseCategory category,
    required List<MuscleGroup> muscleGroups,

    /// Base difficulty of THIS variation.
    @Default(ExerciseDifficulty.beginner) ExerciseDifficulty difficulty,
    required List<Equipment> equipment,

    /// Ordered steps, user-readable.
    required List<String> instructions,

    /// Short technique cues ("elbows in", "flat back"...).
    required List<String> techniqueCues,

    /// Common mistakes to warn against.
    @Default(<String>[]) List<String> commonMistakes,

    /// Ids of easier variations (progression ladder goes DOWN here).
    @Default(<String>[]) List<String> easierVariations,

    /// Ids of harder variations (progression ladder goes UP here).
    @Default(<String>[]) List<String> harderVariations,

    /// Movements you should be comfortable with first.
    @Default(<String>[]) List<String> prerequisites,

    /// reps or time.
    @Default(ExerciseMetric.reps) ExerciseMetric metric,

    /// Recommended break between sets, seconds.
    @Default(90) int recommendedRestSeconds,

    /// Safety notes — never encouraging pushing through pain.
    @Default(<String>[]) List<String> safetyNotes,

    /// Media reference for demonstrations (asset path or URL, later phase).
    String? mediaReference,

    /// Searchable tags.
    @Default(<ExerciseTag>[]) List<ExerciseTag> tags,

    /// Bumped whenever TECHNIQUE/SAFETY content changes materially.
    @Default(1) int contentVersion,
  }) = _Exercise;

  const Exercise._();

  factory Exercise.fromJson(Map<String, Object?> json) =>
      _$ExerciseFromJson(json);

  String get metricLabel => metric.label;

  String get primaryMuscle =>
      muscleGroups.isEmpty ? 'Full body' : muscleGroups.first.label;

  /// Whether two progressions point at each other (sanity check helper).
  bool references(String exerciseId) =>
      easierVariations.contains(exerciseId) ||
      harderVariations.contains(exerciseId);
}
