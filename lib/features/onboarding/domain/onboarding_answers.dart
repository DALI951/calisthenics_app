import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

import '../../exercises/domain/exercise_enums.dart';

part 'onboarding_answers.freezed.dart';
part 'onboarding_answers.g.dart';

/// Experience level (spec §8: drives adaptive progression starting point).
enum ExperienceLevel {
  never(
    'Never trained',
    'We\'ll start easy with progressions you can do from day one.',
  ),
  some(
    'Some experience',
    'You know the basics — we\'ll keep form first, volume smart.',
  ),
  regular(
    'I train regularly',
    'Good base. The program will still start light and scale fast.',
  );

  const ExperienceLevel(this.label, this.description);
  final String label;
  final String description;
}

/// What the user wants out of the program.
enum TrainingGoal {
  strength('Build strength'),
  firstPullUp('Do my first pull-up'),
  pushUpMastery('Master push-ups'),
  consistency('Build a consistent habit'),
  generalHealth('Feel better overall');

  const TrainingGoal(this.label);
  final String label;
}

/// Units preference (spec §8, §79).
enum UnitsPreference {
  metric('Metric (kg, seconds)'),
  imperial('Imperial (lb)');

  const UnitsPreference(this.label);
  final String label;
}

/// Everything collected during onboarding (spec §8). Stored on the profile
/// and used by the adaptive systems (equipment-aware days, progression start).
@freezed
abstract class OnboardingAnswers with _$OnboardingAnswers {
  const factory OnboardingAnswers({
    @Default(ExperienceLevel.some) ExperienceLevel experienceLevel,

    /// Preferred training weekdays, 1=Monday..7=Sunday (for reminders and
    /// the "what should I do today" gate).
    @Default({1, 2, 4, 5}) Set<int> trainingDays,

    /// Equipment available at home — drives substitutions (spec §66).
    @Default({Equipment.none}) Set<Equipment> equipment,

    @Default(<TrainingGoal>{TrainingGoal.consistency}) Set<TrainingGoal> goals,

    /// "Two friends who train together" — the app's core use case.
    @Default(false) bool hasTrainingPartner,

    /// Safety acknowledgement (spec §8): never forced, but clearly offered.
    @Default(false) bool safetyAcknowledged,

    @Default(UnitsPreference.metric) UnitsPreference preferredUnits,

    @Default(true) bool notificationsEnabled,

    /// When onboarding completed (UTC).
    DateTime? completedAt,
  }) = _OnboardingAnswers;

  const OnboardingAnswers._();

  factory OnboardingAnswers.fromJson(Map<String, Object?> json) =>
      _$OnboardingAnswersFromJson(json);

  static const int currentVersion = 1;

  String get experienceLabel => experienceLevel.label;

  String get daysLabel {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final sorted = trainingDays.toList()..sort();
    if (sorted.isEmpty) return 'No days selected';
    return sorted.map((d) => names[d - 1]).join(', ');
  }

  String get equipmentLabel {
    if (equipment.isEmpty) return 'No equipment';
    if (equipment.length == 1 && equipment.first == Equipment.none) {
      return 'No equipment';
    }
    final labels = equipment
        .where((e) => e != Equipment.none)
        .map((e) => e.label)
        .toList();
    return labels.isEmpty ? 'No equipment' : labels.join(', ');
  }

  String get goalsLabel {
    if (goals.isEmpty) return 'No goals yet';
    return goals.map((g) => g.label).join(', ');
  }

  /// Whether every key equipment need is covered (used for gear warnings).
  bool canRun(List<Equipment> required) =>
      required.every((e) => e == Equipment.none || equipment.contains(e));
}
