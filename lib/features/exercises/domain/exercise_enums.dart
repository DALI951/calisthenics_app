/// Exercise taxonomy — drives filters, analytics and challenges.
enum ExerciseCategory {
  push('Push'),
  pull('Pull'),
  legs('Legs'),
  core('Core');

  const ExerciseCategory(this.label);
  final String label;
}

/// Difficulty levels used by the progression engine and UI.
enum ExerciseDifficulty {
  beginner('Beginner', 1),
  intermediate('Intermediate', 2),
  advanced('Advanced', 3);

  const ExerciseDifficulty(this.label, this.level);
  final String label;
  final int level;

  static ExerciseDifficulty? fromLevel(int level) {
    for (final d in values) {
      if (d.level == level) return d;
    }
    return null;
  }
}

/// Muscle groups (for charts: distribution, PR tracking).
enum MuscleGroup {
  chest('Chest'),
  shoulders('Shoulders'),
  triceps('Triceps'),
  back('Back'),
  biceps('Biceps'),
  core('Core'),
  quads('Quads'),
  glutes('Glutes'),
  hamstrings('Hamstrings'),
  calves('Calves');

  const MuscleGroup(this.label);
  final String label;
}

/// Equipment options (onboarding + exercise filter + program adaptation).
enum Equipment {
  none('No equipment'),
  pullUpBar('Pull-up bar'),
  parallelBars('Parallel bars'),
  resistanceBands('Resistance bands'),
  benchOrChair('Bench / chair');

  const Equipment(this.label);
  final String label;
}

/// How the movement is measured.
enum ExerciseMetric {
  reps('Reps'),
  time('Time');

  const ExerciseMetric(this.label);
  final String label;
}

/// Tags for search + customization.
enum ExerciseTag {
  beginnerFriendly('Beginner friendly'),
  jointFriendly('Joint friendly'),
  coreStability('Core stability'),
  explosive('Explosive'),
  isometric('Isometric'),
  balance('Balance');

  const ExerciseTag(this.label);
  final String label;
}
