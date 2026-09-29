import 'package:calisthenics_app/features/exercises/data/exercise_library.dart';
import 'package:calisthenics_app/features/exercises/domain/exercise_enums.dart';
import 'package:calisthenics_app/features/workouts/data/program_registry.dart';
import 'package:calisthenics_app/features/workouts/domain/workout_program.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExerciseLibrary', () {
    test('covers the spec §12 inventory with unique ids', () {
      final all = ExerciseLibrary.all;
      // V1 = the full spec list of 27 movements.
      expect(all.length, 27);
      final ids = all.map((e) => e.id).toSet();
      expect(ids.length, all.length, reason: 'ids must be unique');
    });

    test('every exercise has teachable content', () {
      for (final e in ExerciseLibrary.all) {
        expect(e.instructions, isNotEmpty, reason: '${e.id}: instructions');
        expect(e.techniqueCues, isNotEmpty, reason: '${e.id}: cues');
        expect(e.muscleGroups, isNotEmpty, reason: '${e.id}: muscles');
        expect(e.equipment, isNotEmpty, reason: '${e.id}: equipment');
        expect(
          e.recommendedRestSeconds,
          greaterThanOrEqualTo(30),
          reason: '${e.id}: rest',
        );
      }
    });

    test('progression ladder references only existing exercises', () {
      for (final e in ExerciseLibrary.all) {
        for (final id in [...e.easierVariations, ...e.harderVariations]) {
          expect(
            ExerciseLibrary.byId(id),
            isNotNull,
            reason: '${e.id} references missing exercise $id',
          );
        }
      }
    });

    test('ladder has no 2-cycles and no self-dual entries', () {
      for (final e in ExerciseLibrary.all) {
        final overlap = e.easierVariations
            .where(e.harderVariations.contains)
            .toList();
        expect(
          overlap,
          isEmpty,
          reason: '${e.id} lists the same variation as easier AND harder',
        );
        for (final id in e.easierVariations) {
          final target = ExerciseLibrary.byId(id)!;
          expect(
            target.easierVariations.contains(e.id),
            isFalse,
            reason: '${e.id} and $id both claim the other is easier',
          );
        }
      }
    });

    test('every category expected in the spec inventory', () {
      for (final c in ExerciseCategory.values) {
        expect(ExerciseLibrary.byCategory(c), isNotEmpty, reason: c.label);
      }
    });

    test('V1 seed only contains beginner + intermediate movements', () {
      // The full program (spec §9) is a BEGINNER program — advanced
      // variations arrive with the Phase-2 expansion. This guard keeps the
      // seed honest in the meantime.
      final difficulties = ExerciseLibrary.all.map((e) => e.difficulty).toSet();
      expect(difficulties, isNot(contains(ExerciseDifficulty.advanced)));
      expect(
        difficulties,
        containsAll([
          ExerciseDifficulty.beginner,
          ExerciseDifficulty.intermediate,
        ]),
      );
    });
  });

  group('ProgramRegistry (spec §9)', () {
    final program = ProgramRegistry.blank;

    test('is a 7-day cycle with days ordered 1..7', () {
      expect(program.days.length, 7);
      for (var i = 0; i < 7; i++) {
        expect(program.days[i].dayNumber, i + 1);
      }
    });

    test('ships no preset split — every day starts as rest', () {
      final trainings = program.days.where(
        (d) => d.type == ProgramDayType.training,
      );
      final rests = program.days.where((d) => d.type == ProgramDayType.rest);
      expect(trainings, isEmpty, reason: 'no forced training days');
      expect(rests.length, 7);
    });

    test('starts with nothing programmed in any day', () {
      expect(program.days.every((d) => d.exercises.isEmpty), isTrue);
      expect(
        program.days.every((d) => d.name == 'Rest'),
        isTrue,
      );
    });

    test(
      'training days reference existing exercises, no duplicates per day',
      () {
        for (final day in program.days) {
          if (day.type == ProgramDayType.rest) {
            expect(
              day.exercises,
              isEmpty,
              reason: 'rest day ${day.dayNumber} has no exercises',
            );
            continue;
          }
          expect(
            day.exercises,
            isNotEmpty,
            reason: 'day ${day.dayNumber} has exercises',
          );
          final ids = day.exercises.map((e) => e.exerciseId).toList();
          expect(
            ids.toSet().length,
            ids.length,
            reason: 'day ${day.dayNumber} has unique exercises',
          );
          for (final e in day.exercises) {
            expect(
              ExerciseLibrary.byId(e.exerciseId),
              isNotNull,
              reason: 'day ${day.dayNumber} references ${e.exerciseId}',
            );
            // Ranges must be sane (int? props don't promote — copy to locals).
            final min = e.targetMin;
            final max = e.targetMax;
            if (min != null && max != null) {
              expect(max, greaterThanOrEqualTo(min));
            }
            final secMin = e.targetSecondsMin;
            final secMax = e.targetSecondsMax;
            if (secMin != null && secMax != null) {
              expect(secMax, greaterThanOrEqualTo(secMin));
            }
          }
        }
      },
    );

    test("nextTrainingDayFrom is honest when no day is programmed", () {
      // Nothing is a training day, so it must not invent one.
      expect(() => program.nextTrainingDayFrom(3), throwsA(anything));
    });

    test('targetLabel renders like "4 × 8–15" and "3 × 20–40s"', () {
      const pushups = PlannedExercise(
        exerciseId: 'pushup',
        sets: 4,
        targetMin: 8,
        targetMax: 15,
      );
      expect(pushups.targetLabel, '4 × 8–15');
      const plank = PlannedExercise(
        exerciseId: 'plank',
        sets: 3,
        targetSecondsMin: 20,
        targetSecondsMax: 40,
      );
      expect(plank.targetLabel, '3 × 20–40s');
    });

    test('byId lookup finds the blank program', () {
      expect(
        ProgramRegistry.byId(ProgramRegistry.blankProgramId),
        same(program),
      );
    });
  });
}
