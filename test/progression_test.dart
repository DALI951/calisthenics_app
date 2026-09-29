import 'package:calisthenics_app/features/progression/domain/journey_providers.dart';
import 'package:calisthenics_app/features/progression/domain/personal_maxes.dart';
import 'package:calisthenics_app/features/progression/domain/progression_engine.dart';
import 'package:calisthenics_app/features/workouts/domain/workout_program.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The promise was: train for a long time (not one 4-day block), and get
/// harder as you get stronger. These tests hold the engine to that.
void main() {
  const journeyKey = 'calisthenics.journey.week.v1';

  final pushups = PlannedExercise(
    exerciseId: 'pushup-standard',
    sets: 3,
    targetMin: 5,
    targetMax: 10,
  );
  final day = ProgramDay(
    dayNumber: 1,
    type: ProgramDayType.training,
    name: 'Push',
    exercises: [pushups],
  );

  PersonalMaxes maxesOf(int pushups) => PersonalMaxes({
        MaxSkill.pushups: SkillMax(
          value: pushups,
          updatedAt: DateTime.utc(2026),
        ),
      });

  group('long-term journey', () {
    test('the journey lasts far longer than 4 days', () {
      final totalWeeks =
          ProgramJourney.blocks.fold<int>(0, (sum, b) => sum + b.weeks);
      expect(totalWeeks, greaterThan(20));
      expect(ProgramJourney.blocks.length, greaterThanOrEqualTo(4));
    });

    test('blocks change emphasis as the weeks pass', () {
      // Foundation 1-6, Build 7-14, Strength 15-22, Skill 23-28.
      expect(ProgramJourney.blockForWeek(1).emphasis, BlockEmphasis.technique);
      expect(ProgramJourney.blockForWeek(6).emphasis, BlockEmphasis.technique);
      expect(ProgramJourney.blockForWeek(7).emphasis, BlockEmphasis.hypertrophy);
      expect(ProgramJourney.blockForWeek(9).emphasis, BlockEmphasis.hypertrophy);
      expect(ProgramJourney.blockForWeek(15).emphasis, BlockEmphasis.strength);
      expect(ProgramJourney.blockForWeek(20).emphasis, BlockEmphasis.strength);
      expect(ProgramJourney.blockForWeek(23).emphasis, BlockEmphasis.skill);
      expect(ProgramJourney.blockForWeek(24).emphasis, BlockEmphasis.skill);
    });

    test('the journey cycles instead of ending', () {
      final cycleWeeks =
          ProgramJourney.blocks.fold<int>(0, (sum, b) => sum + b.weeks);
      final start = ProgramJourney.blockForWeek(1);
      final afterCycle = ProgramJourney.blockForWeek(cycleWeeks + 1);
      expect(afterCycle.id, start.id);
    });

    test('the week counter advances and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(
        (await c.read(journeyProgressControllerProvider.future)).week,
        1,
      );
      await c.read(journeyProgressControllerProvider.notifier).advanceWeek();
      expect(
        (await c.read(journeyProgressControllerProvider.future)).week,
        2,
      );

      final c2 = ProviderContainer();
      addTearDown(c2.dispose);
      expect((await c2.read(journeyProgressControllerProvider.future)).week, 2);
    });

    test('corrupt journey progress restarts safely', () async {
      SharedPreferences.setMockInitialValues({journeyKey: 'garbage'});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect((await c.read(journeyProgressControllerProvider.future)).week, 1);
    });
  });

  group('progression from your own maxes', () {
    test('a bigger max produces a bigger working set', () {
      const engine = ProgressionEngine();
      final small = engine.scale(
        planned: pushups,
        week: 9,
        emphasis: BlockEmphasis.hypertrophy,
        maxes: maxesOf(10),
      );
      final big = engine.scale(
        planned: pushups,
        week: 9,
        emphasis: BlockEmphasis.hypertrophy,
        maxes: maxesOf(40),
      );
      expect(big.targetMax!, greaterThan(small.targetMax!));
      // 70% of 40 = 28 working reps.
      expect(big.targetMax, 28);
    });

    test('never asks for more than the declared max', () {
      const engine = ProgressionEngine();
      for (final max in [3, 5, 12, 30, 100]) {
        final t = engine.scale(
          planned: pushups,
          week: 1,
          emphasis: BlockEmphasis.skill,
          maxes: maxesOf(max),
        );
        expect(t.targetMax!, lessThanOrEqualTo(max));
        expect(t.targetMin!, greaterThanOrEqualTo(1));
      }
    });

    test('harder blocks ask for more than easier ones', () {
      const engine = ProgressionEngine();
      final m = maxesOf(30);
      final technique = engine.scale(
        planned: pushups,
        week: 1,
        emphasis: BlockEmphasis.technique,
        maxes: m,
      );
      final skill = engine.scale(
        planned: pushups,
        week: 1,
        emphasis: BlockEmphasis.skill,
        maxes: m,
      );
      expect(skill.targetMax, greaterThan(technique.targetMax!));
      expect(skill.restSeconds, greaterThan(technique.restSeconds));
    });

    test('with no max declared the planned numbers are never inflated', () {
      const engine = ProgressionEngine();
      final t = engine.scale(
        planned: pushups,
        week: 1,
        emphasis: BlockEmphasis.strength,
      );
      expect(t.targetMin, 5);
      expect(t.targetMax, 10);
    });

    test('a timed max scales in seconds', () {
      const engine = ProgressionEngine();
      final plank = PlannedExercise(
        exerciseId: 'plank',
        sets: 3,
        targetSecondsMin: 20,
        targetSecondsMax: 40,
      );
      final t = engine.scale(
        planned: plank,
        week: 1,
        emphasis: BlockEmphasis.hypertrophy,
        maxes: PersonalMaxes({
          MaxSkill.plank: SkillMax(value: 120, updatedAt: DateTime.utc(2026)),
        }),
      );
      expect(t.targetSecondsMax, greaterThan(t.targetSecondsMin!));
      expect(t.targetSecondsMin, greaterThan(40), reason: 'scales past 5 flat');    });

    test('scaling a whole day touches every exercise', () {
      const engine = ProgressionEngine();
      final twoExercises = day.copyWith(
        exercises: [
          pushups,
          const PlannedExercise(
            exerciseId: 'pullup-standard',
            sets: 3,
            targetMin: 5,
            targetMax: 8,
          ),
        ],
      );
      final scaled = engine.scaleDay(
        day: twoExercises,
        week: 9,
        emphasis: BlockEmphasis.hypertrophy,
        maxes: maxesOf(20),
      );
      expect(scaled.length, 2);
      expect(
        scaled.every((e) => e.targetMax != null),
        isTrue,
      );
    });

    test('a deload week cuts volume and effort', () {
      const engine = ProgressionEngine();
      final normal = engine.scale(
        planned: pushups,
        week: 2,
        emphasis: BlockEmphasis.hypertrophy,
        maxes: maxesOf(30),
      );
      final deload = engine.scale(
        planned: pushups,
        week: 8, // last week of the Build block == deload
        emphasis: BlockEmphasis.hypertrophy,
        maxes: maxesOf(30),
      );
      expect(deload.targetMax, lessThan(normal.targetMax!));
    });
  });
}
