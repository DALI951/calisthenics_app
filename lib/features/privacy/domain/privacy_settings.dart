/// Privacy controls (spec §36). The user's explicit choice, enforced in the
/// UI — the app never quietly exposes training data. Location is never
/// collected at all.
enum TrainingVisibility {
  /// Friends and challenge partners can see your training.
  friends,

  /// Nobody sees it. Challenges still work — they just show no names.
  nobody,
}

class PrivacySettings {
  const PrivacySettings({
    this.trainingVisibility = TrainingVisibility.friends,
    this.onlineStatusVisible = true,
    this.trainingStatusVisible = true,
    this.friendActivityVisible = true,
    this.challengeInvitesFrom = ChallengeInviteSource.friendsOnly,
  });

  final TrainingVisibility trainingVisibility;

  /// "Online status" — being online at all.
  final bool onlineStatusVisible;

  /// "Training status" — actively mid-workout right now.
  final bool trainingStatusVisible;

  /// "Friend activity" — what your friends are doing in the friends list.
  final bool friendActivityVisible;

  final ChallengeInviteSource challengeInvitesFrom;

  /// Single decision point the rest of the app asks.
  bool get showsTrainingToOthers =>
      trainingVisibility == TrainingVisibility.friends;

  /// The one rule: a hidden training status also hides the pulsing dot, even
  /// if online status is visible. No half-hidden "he is definitely training".
  bool get showsLiveTraining => onlineStatusVisible && trainingStatusVisible;

  PrivacySettings copyWith({
    TrainingVisibility? trainingVisibility,
    bool? onlineStatusVisible,
    bool? trainingStatusVisible,
    bool? friendActivityVisible,
    ChallengeInviteSource? challengeInvitesFrom,
  }) => PrivacySettings(
    trainingVisibility: trainingVisibility ?? this.trainingVisibility,
    onlineStatusVisible: onlineStatusVisible ?? this.onlineStatusVisible,
    trainingStatusVisible: trainingStatusVisible ?? this.trainingStatusVisible,
    friendActivityVisible: friendActivityVisible ?? this.friendActivityVisible,
    challengeInvitesFrom: challengeInvitesFrom ?? this.challengeInvitesFrom,
  );

  Map<String, Object?> toStorage() => {
    'trainingVisibility': trainingVisibility.name,
    'onlineStatusVisible': onlineStatusVisible,
    'trainingStatusVisible': trainingStatusVisible,
    'friendActivityVisible': friendActivityVisible,
    'challengeInvitesFrom': challengeInvitesFrom.name,
  };

  static PrivacySettings fromStorage(Map<Object?, Object?> raw) {
    T pick<T extends Enum>(List<T> values, String? name, T fallback) =>
        values.firstWhere((v) => v.name == name, orElse: () => fallback);
    return PrivacySettings(
      trainingVisibility: pick(
        TrainingVisibility.values,
        raw['trainingVisibility'] as String?,
        TrainingVisibility.friends,
      ),
      onlineStatusVisible: (raw['onlineStatusVisible'] as bool?) ?? true,
      trainingStatusVisible: (raw['trainingStatusVisible'] as bool?) ?? true,
      friendActivityVisible: (raw['friendActivityVisible'] as bool?) ?? true,
      challengeInvitesFrom: pick(
        ChallengeInviteSource.values,
        raw['challengeInvitesFrom'] as String?,
        ChallengeInviteSource.friendsOnly,
      ),
    );
  }
}

enum ChallengeInviteSource {
  /// Only people who are already your friends may invite you.
  friendsOnly,

  /// Nobody may invite you.
  nobody,
}
