import 'package:calisthenics_app/features/exercises/domain/exercise_enums.dart';
import 'package:calisthenics_app/features/onboarding/domain/onboarding_answers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OnboardingAnswers defaults', () {
    test(
      'sensible defaults: some experience, Mon/Tue/Thu/Fri, no equipment',
      () {
        const a = OnboardingAnswers();
        expect(a.experienceLevel, ExperienceLevel.some);
        expect(a.trainingDays, {1, 2, 4, 5});
        expect(a.equipment, {Equipment.none});
        expect(a.goals, {TrainingGoal.consistency});
        expect(a.hasTrainingPartner, isFalse);
        expect(a.safetyAcknowledged, isFalse);
        expect(a.preferredUnits, UnitsPreference.metric);
        expect(a.notificationsEnabled, isTrue);
        expect(a.completedAt, isNull);
      },
    );

    test('json round-trips', () {
      final a = OnboardingAnswers(
        experienceLevel: ExperienceLevel.never,
        trainingDays: {3, 5},
        equipment: {Equipment.pullUpBar, Equipment.resistanceBands},
        goals: {TrainingGoal.firstPullUp, TrainingGoal.strength},
        hasTrainingPartner: true,
        safetyAcknowledged: true,
        preferredUnits: UnitsPreference.imperial,
        notificationsEnabled: false,
        completedAt: DateTime.utc(2026, 9, 28),
      );
      final restored = OnboardingAnswers.fromJson(a.toJson());
      expect(restored, a);
    });
  });

  group('OnboardingAnswers labels', () {
    test('daysLabel formats sorted weekdays', () {
      const a = OnboardingAnswers(); // {1,2,4,5}
      expect(a.daysLabel, 'Mon, Tue, Thu, Fri');
    });

    test('equipmentLabel collapses none', () {
      const none = OnboardingAnswers();
      expect(none.equipmentLabel, 'No equipment');

      const gear = OnboardingAnswers(
        equipment: {Equipment.pullUpBar, Equipment.benchOrChair},
      );
      // "No equipment" default is replaced when real gear chosen.
      expect(
        gear
            .copyWith(equipment: {Equipment.pullUpBar, Equipment.benchOrChair})
            .equipmentLabel,
        'Pull-up bar, Bench / chair',
      );
    });

    test('goalsLabel lists selected goals', () {
      const a = OnboardingAnswers(goals: {TrainingGoal.firstPullUp});
      expect(a.goalsLabel, 'Do my first pull-up');
    });
  });

  group('canRun (equipment awareness, spec §66)', () {
    test('no-equipment user can run bodyweight-only requirements', () {
      const a = OnboardingAnswers();
      expect(a.canRun([Equipment.none]), isTrue);
      expect(a.canRun([Equipment.pullUpBar]), isFalse);
    });

    test('gear covers all requirements', () {
      const a = OnboardingAnswers(
        equipment: {Equipment.pullUpBar, Equipment.parallelBars},
      );
      expect(a.canRun([Equipment.pullUpBar, Equipment.parallelBars]), isTrue);
    });
  });
}
