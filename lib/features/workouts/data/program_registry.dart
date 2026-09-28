import '../../exercises/data/exercise_library.dart';
import '../../exercises/domain/exercise_enums.dart';
import '../domain/workout_program.dart';

/// Program definitions are DATA (spec §61), never hardcoded in widgets.
///
/// V1 = the Beginner 4-day program from spec §9 (Days 1–2 train, Day 3 rest,
/// Day 4 train, Day 5 full body, Days 6–7 rest — 4 training days per cycle).
abstract final class ProgramRegistry {
  static const String beginnerProgramId = 'beginner-4day-v1';

  static final WorkoutProgram beginner = WorkoutProgram(
    id: beginnerProgramId,
    name: 'Beginner 4-Day',
    version: 1,
    description:
        'The starting program: push, pull, legs and one full-body day. '
        'Progressions adapt each exercise to you.',
    days: [
      ProgramDay(
        dayNumber: 1,
        type: ProgramDayType.training,
        name: 'Push + Core',
        focus: 'Chest, shoulders, triceps, abs',
        exercises: [
          PlannedExercise(
            exerciseId: 'pushup-standard',
            sets: 4,
            targetMin: 8,
            targetMax: 15,
            restSeconds: 90,
          ),
          PlannedExercise(
            exerciseId: 'pushup-diamond',
            sets: 3,
            targetMin: 6,
            targetMax: 12,
            restSeconds: 90,
          ),
          PlannedExercise(
            exerciseId: 'dips',
            sets: 3,
            targetMin: 6,
            targetMax: 12,
            restSeconds: 120,
          ),
          PlannedExercise(
            exerciseId: 'pushup-pike',
            sets: 3,
            targetMin: 6,
            targetMax: 10,
            restSeconds: 90,
          ),
          PlannedExercise(
            exerciseId: 'hanging-knee-raise',
            sets: 3,
            targetMin: 10,
            targetMax: 15,
            restSeconds: 90,
          ),
        ],
      ),
      ProgramDay(
        dayNumber: 2,
        type: ProgramDayType.training,
        name: 'Pull + Core',
        focus: 'Back, biceps, core',
        exercises: [
          PlannedExercise(
            exerciseId: 'pullup-standard',
            sets: 4,
            targetMin: 5,
            targetMax: 10,
            restSeconds: 120,
            note: 'Use the assisted or negative variation if needed',
          ),
          PlannedExercise(
            exerciseId: 'australian-row',
            sets: 3,
            targetMin: 8,
            targetMax: 12,
            restSeconds: 90,
          ),
          PlannedExercise(
            exerciseId: 'chinup',
            sets: 3,
            targetMin: 5,
            targetMax: 10,
            restSeconds: 120,
          ),
          PlannedExercise(
            exerciseId: 'superman-hold',
            sets: 3,
            targetSecondsMin: 20,
            targetSecondsMax: 40,
            restSeconds: 60,
          ),
          PlannedExercise(
            exerciseId: 'plank',
            sets: 3,
            targetSecondsMin: 30,
            targetSecondsMax: 60,
            restSeconds: 60,
          ),
        ],
      ),
      ProgramDay(
        dayNumber: 3,
        type: ProgramDayType.rest,
        name: 'Rest',
        note: 'Recovery matters. Light walk, gentle mobility or easy stretching — no scoring today.',
      ),
      ProgramDay(
        dayNumber: 4,
        type: ProgramDayType.training,
        name: 'Legs + Core',
        focus: 'Quads, glutes, hamstrings, calves',
        exercises: [
          PlannedExercise(
            exerciseId: 'squat-bodyweight',
            sets: 4,
            targetMin: 15,
            targetMax: 20,
            restSeconds: 90,
          ),
          PlannedExercise(
            exerciseId: 'bulgarian-split-squat',
            sets: 3,
            targetMin: 8,
            targetMax: 12,
            restSeconds: 120,
            note: 'Each side',
          ),
          PlannedExercise(
            exerciseId: 'glute-bridge',
            sets: 3,
            targetMin: 12,
            targetMax: 15,
            restSeconds: 60,
          ),
          PlannedExercise(
            exerciseId: 'calf-raise',
            sets: 3,
            targetMin: 15,
            targetMax: 20,
            restSeconds: 60,
          ),
          PlannedExercise(
            exerciseId: 'side-plank',
            sets: 3,
            targetSecondsMin: 20,
            targetSecondsMax: 40,
            restSeconds: 60,
            note: 'Each side',
          ),
        ],
      ),
      ProgramDay(
        dayNumber: 5,
        type: ProgramDayType.training,
        name: 'Full Body',
        focus: 'Everything, one round after another',
        exercises: [
          PlannedExercise(
            exerciseId: 'pullup-standard',
            sets: 4,
            targetMin: 5,
            targetMax: 10,
            restSeconds: 90,
            note: '3–4 rounds total',
          ),
          PlannedExercise(
            exerciseId: 'pushup-standard',
            sets: 4,
            targetMin: 8,
            targetMax: 15,
            restSeconds: 90,
          ),
          PlannedExercise(
            exerciseId: 'squat-bodyweight',
            sets: 4,
            targetMin: 15,
            targetMax: 20,
            restSeconds: 90,
          ),
          PlannedExercise(
            exerciseId: 'dips',
            sets: 4,
            targetMin: 6,
            targetMax: 12,
            restSeconds: 120,
          ),
          PlannedExercise(
            exerciseId: 'plank',
            sets: 4,
            targetSecondsMin: 30,
            targetSecondsMax: 60,
            restSeconds: 60,
          ),
        ],
      ),
      ProgramDay(
        dayNumber: 6,
        type: ProgramDayType.rest,
        name: 'Rest',
        note: 'Recovery matters. Light walk, gentle mobility or easy stretching — no scoring today.',
      ),
      ProgramDay(
        dayNumber: 7,
        type: ProgramDayType.rest,
        name: 'Rest',
        note: 'Refuel and sleep well. Your next Push + Core day is waiting.',
      ),
    ],
  );

  static final Map<String, WorkoutProgram> _byId = {beginner.id: beginner};

  static WorkoutProgram? byId(String id) => _byId[id];

  static List<WorkoutProgram> get all => List.unmodifiable(_byId.values);

  /// Equipment-aware day selection (spec §66): if key equipment is missing,
  /// the session engine substitutes from the exercise progression ladder.
  static List<String> requiredEquipmentFor(ProgramDay day) {
    final ids = day.exercises.map((e) => e.exerciseId).toSet();
    final needed = <Equipment>{};
    for (final id in ids) {
      final exercise = ExerciseLibrary.byId(id);
      if (exercise == null) continue;
      needed.addAll(exercise.equipment);
    }
    return needed.map((e) => e.label).toList();
  }
}
