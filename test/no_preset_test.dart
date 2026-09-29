import 'package:calisthenics_app/features/workouts/data/program_registry.dart';
import 'package:calisthenics_app/features/workouts/data/session_starter.dart';
import 'package:calisthenics_app/features/workouts/domain/workout_program.dart';
import 'package:flutter_test/flutter_test.dart';

/// He asked for no preset training and to build the plan each session. These
/// tests hold that promise: the app ships nothing programmed, and anything the
/// athlete builds is a normal day that the session controller can run.
void main() {
  group('no preset training', () {
    test('the shipped week is completely empty', () {
      expect(ProgramRegistry.blank.days.length, 7);
      expect(ProgramRegistry.blank.days.every((d) => d.exercises.isEmpty), isTrue);
      expect(
        ProgramRegistry.blank.days.every(
          (d) => d.type == ProgramDayType.rest,
        ),
        isTrue,
      );
    });

    test('no day is pre-labelled as a split (no Push/Pull/Legs)', () {
      final names = ProgramRegistry.blank.days.map((d) => d.name).toSet();
      expect(
        names.intersection({'Push + Core', 'Pull + Core', 'Legs + Core'}),
        isEmpty,
      );
    });

    test('asking for a training day fails honestly, not with an empty one', () {
      expect(
        () => ProgramRegistry.blank.nextTrainingDayFrom(1),
        throwsA(isA<StateError>()),
      );
    });

    test('firstTrainingDay is null when nothing is programmed', () {
      expect(ProgramRegistry.blank.firstTrainingDay, isNull);
    });
  });

  group('build the plan each session', () {
    final pushups = PlannedExercise(
      exerciseId: 'pushup',
      sets: 4,
      targetMin: 8,
      targetMax: 12,
    );
    final squats = PlannedExercise(
      exerciseId: 'squat',
      sets: 3,
      targetMin: 15,
      targetMax: 20,
    );

    test('a hand-built list becomes a runnable training day', () {
      final day = buildSessionDay([pushups, squats]);
      expect(day.type, ProgramDayType.training);
      expect(day.exercises.length, 2);
      expect(day.exercises.first.exerciseId, 'pushup');
      // Day 1 of an ad-hoc session, not day 4 of a preset week.
      expect(day.dayNumber, 1);
    });

    test('the built day carries the sets and reps that were chosen', () {
      final day = buildSessionDay([pushups]);
      expect(day.exercises.first.sets, 4);
      expect(day.exercises.first.targetMin, 8);
      expect(day.exercises.first.targetLabel, contains('4'));
    });

    test('a timed movement keeps seconds and not reps', () {
      final plank = PlannedExercise(
        exerciseId: 'plank',
        sets: 3,
        targetSecondsMin: 45,
        targetSecondsMax: 45,
      );
      final day = buildSessionDay([plank]);
      expect(day.exercises.first.targetSecondsMin, 45);
      expect(day.exercises.first.targetMin, isNull);
    });

    test('an empty build still produces a valid (but empty) day', () {
      final day = buildSessionDay([]);
      expect(day.exercises, isEmpty);
      expect(day.type, ProgramDayType.training);
    });

    test('an ad-hoc session is tagged so history can tell it apart', () {
      expect(SessionStarter.adHocProgramId, 'ad-hoc-session');
    });
  });
}
