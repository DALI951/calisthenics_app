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
    final program = ProgramRegistry.beginner;

    test('is a 7-day cycle with days ordered 1..7', () {
      expect(program.days.length, 7);
      for (var i = 0; i < 7; i++) {
        expect(program.days[i].dayNumber, i + 1);
      }
    });

    test('4 training + 3 rest days', () {
      final trainings = program.days.where(
        (d) => d.type == ProgramDayType.training,
      );
      final rests = program.days.where((d) => d.type == ProgramDayType.rest);
      expect(trainings.length, 4);
      expect(rests.length, 3);
    });

    test('hits the exact spec split: Push, Pull, Rest, Legs, Full Body, Rest, Rest', () {
      final names = program.days
          .map((d) => '${d.dayNumber}:${d.name}')
          .join(' | ');
      expect(program.dayAt(1).name, 'Push + Core');
      expect(program.dayAt(2).name, 'Pull + Core');
      expect(program.dayAt(3).name, 'Rest');
      expect(program.dayAt(4).name, 'Legs + Core');
      expect(program.dayAt(5).name, 'Full Body');
      expect(program.dayAt(6).name, 'Rest');
      expect(program.dayAt(7).name, 'Rest');
      expect(names, isNotEmpty);
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

    test("nextTrainingDayFrom skips rest days", () {
      // day 3 is rest → next training day is day 4.
      expect(program.nextTrainingDayFrom(3).dayNumber, 4);
      // day 7 is rest → wraps to day 1.
      expect(program.nextTrainingDayFrom(7).dayNumber, 1);
      // a training day returns itself.
      expect(program.nextTrainingDayFrom(1).dayNumber, 1);
    });

    test('targetLabel renders like "4 × 8–15" and "3 × 20–40s"', () {
      final pushups = program.dayAt(1).exercises.first;
      expect(pushups.sets, 4);
      expect(pushups.targetLabel, '4 × 8–15');
      final plank = program.dayAt(2).exercises[4];
      expect(plank.targetLabel, '3 × 30–60s');
    });

    test('byId lookup finds the beginner program', () {
      expect(
        ProgramRegistry.byId(ProgramRegistry.beginnerProgramId),
        same(program),
      );
    });
  });
}
