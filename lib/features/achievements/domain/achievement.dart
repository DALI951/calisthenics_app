/// Snapshot of everything the achievement engine may look at. Computed from
/// immutable history + challenges + friends — never from app opens (spec §26:
/// "training should be the source of progress").
class AchievementStats {
  const AchievementStats({
    this.workoutsCompleted = 0,
    this.setsCompleted = 0,
    this.challengesCompleted = 0,
    this.challengesStarted = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.weeksWithGoalMet = 0,
    this.bestPullups = 0,
    this.bestPushups = 0,
    this.bestPlankSeconds = 0,
    this.exercisesLearned = 0,
    this.hasTrainingPartner = false,
    this.trainTogetherWorkouts = 0,
  });

  final int workoutsCompleted;
  final int setsCompleted;
  final int challengesCompleted;
  final int challengesStarted;
  final int currentStreak;
  final int longestStreak;
  final int weeksWithGoalMet;
  final int bestPullups;
  final int bestPushups;
  final int bestPlankSeconds;
  final int exercisesLearned;
  final bool hasTrainingPartner;
  final int trainTogetherWorkouts;
}

/// A single, meaningful achievement (spec §25). No noise, no spam.
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.hint,
    required this.emoji,
    required this.target,
    required this.xp,
    this.hidden = false,
  });

  final String id;
  final String title;

  /// Shown while locked. Never spoils the surprise.
  final String hint;
  final String emoji;

  /// The value of [stat] required to unlock.
  final int target;
  final int xp;

  /// Secret achievements stay hidden until earned.
  final bool hidden;

  int progress(AchievementStats s) => switch (id) {
    'workouts_1' ||
    'workouts_10' ||
    'workouts_25' ||
    'workouts_50' ||
    'workouts_100' => s.workoutsCompleted,
    'sets_100' => s.setsCompleted,
    'pullup_1' => s.bestPullups,
    'pullup_10' => s.bestPullups,
    'pushup_25' => s.bestPushups,
    'pushup_50' => s.bestPushups,
    'plank_60' => s.bestPlankSeconds,
    'plank_120' => s.bestPlankSeconds,
    'streak_7' => s.longestStreak,
    'streak_30' => s.longestStreak,
    'challenge_1' => s.challengesCompleted,
    'challenge_5' => s.challengesCompleted,
    'partner' => s.trainTogetherWorkouts,
    'library_10' => s.exercisesLearned,
    'weekly_goal_4' => s.weeksWithGoalMet,
    _ => 0,
  };

  bool isEarned(AchievementStats s) => progress(s) >= target;
}

/// The catalogue (spec §25 examples, all training-based).
class Achievements {
  const Achievements._();

  static const all = <Achievement>[
    Achievement(
      id: 'workouts_1',
      title: 'First workout',
      hint: 'Finish your first workout',
      emoji: '🎉',
      target: 1,
      xp: 50,
    ),
    Achievement(
      id: 'workouts_10',
      title: '10 workouts',
      hint: 'Finish 10 workouts',
      emoji: '💪',
      target: 10,
      xp: 100,
    ),
    Achievement(
      id: 'workouts_25',
      title: '25 workouts',
      hint: 'Finish 25 workouts',
      emoji: '🔥',
      target: 25,
      xp: 150,
    ),
    Achievement(
      id: 'workouts_50',
      title: '50 workouts',
      hint: 'Finish 50 workouts',
      emoji: '⚡',
      target: 50,
      xp: 200,
    ),
    Achievement(
      id: 'workouts_100',
      title: '100 workouts',
      hint: 'Finish 100 workouts',
      emoji: '🏆',
      target: 100,
      xp: 300,
    ),
    Achievement(
      id: 'sets_100',
      title: '100 sets',
      hint: 'Log 100 real sets',
      emoji: '📋',
      target: 100,
      xp: 100,
    ),
    Achievement(
      id: 'pullup_1',
      title: 'First pull-up',
      hint: 'One clean pull-up',
      emoji: '🧗',
      target: 1,
      xp: 50,
    ),
    Achievement(
      id: 'pullup_10',
      title: '10 pull-ups',
      hint: 'Ten reps in one set',
      emoji: '🧗‍♂️',
      target: 10,
      xp: 100,
    ),
    Achievement(
      id: 'pushup_25',
      title: '25 push-ups',
      hint: '25 reps in one set',
      emoji: '💪',
      target: 25,
      xp: 50,
    ),
    Achievement(
      id: 'pushup_50',
      title: '50 push-ups',
      hint: '50 reps in one set',
      emoji: '🏋️',
      target: 50,
      xp: 100,
    ),
    Achievement(
      id: 'plank_60',
      title: 'One-minute plank',
      hint: 'Hold a plank for 60s',
      emoji: '⏱️',
      target: 60,
      xp: 50,
    ),
    Achievement(
      id: 'plank_120',
      title: 'Two-minute plank',
      hint: 'Hold a plank for 120s',
      emoji: '🧘',
      target: 120,
      xp: 100,
    ),
    Achievement(
      id: 'streak_7',
      title: '7-day streak',
      hint: 'Train 7 days in a row',
      emoji: '📅',
      target: 7,
      xp: 100,
    ),
    Achievement(
      id: 'streak_30',
      title: '30-day streak',
      hint: 'Train 30 days in a row',
      emoji: '🗓️',
      target: 30,
      xp: 250,
    ),
    Achievement(
      id: 'challenge_1',
      title: 'First challenge',
      hint: 'Complete your first challenge',
      emoji: '🎯',
      target: 1,
      xp: 75,
    ),
    Achievement(
      id: 'challenge_5',
      title: '5 challenges',
      hint: 'Complete 5 challenges',
      emoji: '🏅',
      target: 5,
      xp: 150,
    ),
    Achievement(
      id: 'partner',
      title: 'Training partner milestone',
      hint: 'Finish a workout alongside your partner',
      emoji: '🤝',
      target: 1,
      xp: 100,
    ),
    Achievement(
      id: 'library_10',
      title: 'Know your moves',
      hint: 'Open 10 exercise guides',
      emoji: '📖',
      target: 10,
      xp: 50,
    ),
    Achievement(
      id: 'weekly_goal_4',
      title: 'Four good weeks',
      hint: 'Hit your weekly goal 4 times',
      emoji: '🎖️',
      target: 4,
      xp: 150,
      hidden: true,
    ),
  ];

  static Achievement byId(String id) =>
      all.firstWhere((a) => a.id == id, orElse: () => all.first);
}
