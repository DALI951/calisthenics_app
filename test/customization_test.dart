import 'package:calisthenics_app/features/progression/domain/personal_maxes.dart';
import 'package:calisthenics_app/features/workouts/data/active_program_controller.dart';
import 'package:calisthenics_app/features/workouts/data/program_registry.dart';
import 'package:calisthenics_app/features/workouts/domain/workout_program.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The program is the user's, not the app's: it must be editable, it must
/// survive a restart, and the built-in program must never be mutated.
void main() {
  const programKey = 'calisthenics.program.custom.v1';
  const maxesKey = 'calisthenics.personal.maxes.v1';

  ProviderContainer boot([Map<String, Object> prefs = const {}]) {
    SharedPreferences.setMockInitialValues(Map<String, Object>.of(prefs));
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  group('program customization', () {
    test('starts EMPTY when nothing is saved — no preset training', () async {
      final c = boot();
      final p = await c.read(activeProgramControllerProvider.future);
      expect(p, ProgramRegistry.blank);
      // The whole point: nothing is programmed until the athlete programmes it.
      expect(p.days.every((d) => d.exercises.isEmpty), isTrue);
      expect(p.days.every((d) => d.type == ProgramDayType.rest), isTrue);
    });

    test('the shared blank program is never mutated by an edit', () async {
      final c = boot();
      await c.read(activeProgramControllerProvider.future);
      c.read(activeProgramControllerProvider.notifier)
          .updateDay(1, (d) => d.copyWith(
                type: ProgramDayType.training,
                name: 'Legs',
                exercises: const [
                  PlannedExercise(exerciseId: 'squat', sets: 4, targetMin: 5),
                ],
              ));
      final p = await c.read(activeProgramControllerProvider.future);
      expect(
        p.days.firstWhere((d) => d.dayNumber == 1).exercises.length,
        1,
      );
      expect(ProgramRegistry.blank.days.first.exercises, isEmpty,
          reason: 'the global default must stay clean');
    });

    test('a day can be turned into a rest day and back', () async {
      final c = boot();
      await c.read(activeProgramControllerProvider.future);
      final notifier = c.read(activeProgramControllerProvider.notifier);

      notifier.setDayType(1, ProgramDayType.rest);
      var p = await c.read(activeProgramControllerProvider.future);
      expect(
        p.days.firstWhere((d) => d.dayNumber == 1).type,
        ProgramDayType.rest,
      );

      notifier.setDayType(1, ProgramDayType.training);
      p = await c.read(activeProgramControllerProvider.future);
      expect(
        p.days.firstWhere((d) => d.dayNumber == 1).type,
        ProgramDayType.training,
      );
    });

    test('days can be reordered', () async {
      final c = boot();
      await c.read(activeProgramControllerProvider.future);
      final notifier = c.read(activeProgramControllerProvider.notifier);
      final before = (await c.read(activeProgramControllerProvider.future)).days
          .firstWhere((d) => d.dayNumber == 1)
          .name;

      notifier.moveDay(1, 1);
      final p = await c.read(activeProgramControllerProvider.future);
      // The old day 1 now sits at slot 2.
      expect(p.days.firstWhere((d) => d.dayNumber == 2).name, before);
      expect(p.days.map((d) => d.dayNumber), [1, 2, 3, 4, 5, 6, 7]);
    });

    test('edits persist across a restart', () async {
      final c = boot();
      await c.read(activeProgramControllerProvider.future);
      c.read(activeProgramControllerProvider.notifier).renameDay(2, 'Arms day');
      // Let the fire-and-forget write land.
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final saved = (await SharedPreferences.getInstance()).getString(
        programKey,
      );
      expect(saved, isNotNull);

      // A brand new container reads the edit back.
      final c2 = boot({programKey: saved!});
      final p2 = await c2.read(activeProgramControllerProvider.future);
      expect(p2.days.firstWhere((d) => d.dayNumber == 2).name, 'Arms day');
    });

    test('reset brings the original program back', () async {
      final c = boot();
      await c.read(activeProgramControllerProvider.future);
      final notifier = c.read(activeProgramControllerProvider.notifier);
      notifier.renameDay(1, 'Something else');
      notifier.setDayType(1, ProgramDayType.rest);

      notifier.resetToDefault();
      final p = await c.read(activeProgramControllerProvider.future);
      expect(
        p.days.firstWhere((d) => d.dayNumber == 1).name,
        ProgramRegistry.blank.days.firstWhere((d) => d.dayNumber == 1).name,
      );
    });

    test('a corrupt saved program never blocks training', () async {
      final c = boot({programKey: 'not json {{{'});
      final p = await c.read(activeProgramControllerProvider.future);
      expect(p.id, ProgramRegistry.blank.id);
    });

    test('a day can be edited exercise by exercise', () async {
      final c = boot();
      await c.read(activeProgramControllerProvider.future);
      final notifier = c.read(activeProgramControllerProvider.notifier);
      // Nothing is pre-programmed, so the athlete adds the day first.
      notifier.updateDay(
        1,
        (d) => d.copyWith(
          type: ProgramDayType.training,
          exercises: const [
            PlannedExercise(exerciseId: 'pushup', sets: 3, targetMin: 8),
            PlannedExercise(exerciseId: 'dip', sets: 3, targetMin: 6),
          ],
        ),
      );
      final first = (await c.read(activeProgramControllerProvider.future)).days
          .firstWhere((d) => d.dayNumber == 1)
          .exercises
          .first;

      notifier.updateDay(
        1,
        (d) => d.copyWith(
          exercises: [
            for (final e in d.exercises)
              if (e.exerciseId == first.exerciseId)
                e.copyWith(sets: e.sets + 2, restSeconds: 120)
              else
                e,
          ],
        ),
      );

      final p = await c.read(activeProgramControllerProvider.future);
      final edited = p.days
          .firstWhere((d) => d.dayNumber == 1)
          .exercises
          .firstWhere((e) => e.exerciseId == first.exerciseId);
      expect(edited.sets, first.sets + 2);
      expect(edited.restSeconds, 120);
    });

    test('exercises can be removed from a day', () async {
      final c = boot();
      await c.read(activeProgramControllerProvider.future);
      final notifier = c.read(activeProgramControllerProvider.notifier);
      notifier.updateDay(
        1,
        (d) => d.copyWith(
          exercises: const [
            PlannedExercise(exerciseId: 'pushup', sets: 3, targetMin: 8),
            PlannedExercise(exerciseId: 'dip', sets: 3, targetMin: 6),
          ],
        ),
      );
      final target = (await c.read(activeProgramControllerProvider.future)).days
          .firstWhere((d) => d.dayNumber == 1)
          .exercises
          .first
          .exerciseId;

      notifier.updateDay(
        1,
        (d) => d.copyWith(
          exercises: d.exercises.where((e) => e.exerciseId != target).toList(),
        ),
      );

      final p = await c.read(activeProgramControllerProvider.future);
      expect(
        p.days
            .firstWhere((d) => d.dayNumber == 1)
            .exercises
            .any((e) => e.exerciseId == target),
        isFalse,
      );
    });
  });

  group('personal maxes', () {
    test('persist and are used to scale working sets', () async {
      final c = boot();
      await c.read(personalMaxesControllerProvider.future);
      final notifier = c.read(personalMaxesControllerProvider.notifier);

      notifier.set(MaxSkill.pushups, 20);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final maxes = await c.read(personalMaxesControllerProvider.future);
      expect(maxes.valueFor(MaxSkill.pushups), 20);
      // 70% of 20 = 14 — heavier than a fixed absolute number.
      expect(maxes.workingTarget(MaxSkill.pushups, 0.7), 14);
      expect(
        SharedPreferences.getInstance().then((p) => p.getString(maxesKey)),
        completion(isNotNull),
      );
    });

    test('never targets more than the declared max', () async {
      final c = boot();
      await c.read(personalMaxesControllerProvider.future);
      c.read(personalMaxesControllerProvider.notifier).set(MaxSkill.pullups, 3);
      final maxes = await c.read(personalMaxesControllerProvider.future);
      expect(maxes.workingTarget(MaxSkill.pullups, 0.9), 3);
    });

    test('falls back conservatively when no max is declared', () async {
      final maxes = PersonalMaxes.empty;
      expect(maxes.workingTarget(MaxSkill.pushups, 0.9), 8);
      expect(maxes.workingTarget(MaxSkill.plank, 0.9), 30);
    });

    test('seeding from history only fills gaps', () async {
      final c = boot();
      await c.read(personalMaxesControllerProvider.future);
      final notifier = c.read(personalMaxesControllerProvider.notifier);
      notifier.set(MaxSkill.pullups, 5);
      notifier.seedFromHistory({MaxSkill.pullups: 12, MaxSkill.pushups: 30});

      final maxes = await c.read(personalMaxesControllerProvider.future);
      expect(maxes.valueFor(MaxSkill.pullups), 5, reason: 'declared wins');
      expect(maxes.valueFor(MaxSkill.pushups), 30);
    });

    test('setting zero clears a skill', () async {
      final c = boot();
      await c.read(personalMaxesControllerProvider.future);
      final notifier = c.read(personalMaxesControllerProvider.notifier);
      notifier.set(MaxSkill.dips, 10);
      notifier.set(MaxSkill.dips, 0);
      final maxes = await c.read(personalMaxesControllerProvider.future);
      expect(maxes.valueFor(MaxSkill.dips), isNull);
    });

    test('corrupt stored maxes load as empty', () async {
      final c = boot({maxesKey: 'nope'});
      final maxes = await c.read(personalMaxesControllerProvider.future);
      expect(maxes.isEmpty, isTrue);
    });
  });
}
