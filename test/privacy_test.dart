import 'package:calisthenics_app/features/privacy/domain/privacy_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults are social but honest', () {
    const s = PrivacySettings();
    expect(s.trainingVisibility, TrainingVisibility.friends);
    expect(s.onlineStatusVisible, isTrue);
    expect(s.trainingStatusVisible, isTrue);
    expect(s.friendActivityVisible, isTrue);
    expect(s.challengeInvitesFrom, ChallengeInviteSource.friendsOnly);
  });

  test('hiding training status also hides the live dot', () {
    const hidden = PrivacySettings(trainingStatusVisible: false);
    expect(hidden.onlineStatusVisible, isTrue);
    expect(
      hidden.showsLiveTraining,
      isFalse,
      reason: 'no half-hidden "he is definitely training" state',
    );
  });

  test('hiding online status hides live training too', () {
    const s = PrivacySettings(onlineStatusVisible: false);
    expect(s.showsLiveTraining, isFalse);
  });

  test('nobody visibility shares no training', () {
    const s = PrivacySettings(trainingVisibility: TrainingVisibility.nobody);
    expect(s.showsTrainingToOthers, isFalse);
    // Online status is a separate, explicit switch.
    expect(s.onlineStatusVisible, isTrue);
  });

  test('settings round-trip through storage', () {
    const s = PrivacySettings(
      trainingVisibility: TrainingVisibility.nobody,
      onlineStatusVisible: false,
      trainingStatusVisible: false,
      friendActivityVisible: false,
      challengeInvitesFrom: ChallengeInviteSource.nobody,
    );
    final back = PrivacySettings.fromStorage(
      s.toStorage().cast<Object?, Object?>(),
    );
    expect(back.trainingVisibility, TrainingVisibility.nobody);
    expect(back.onlineStatusVisible, isFalse);
    expect(back.trainingStatusVisible, isFalse);
    expect(back.friendActivityVisible, isFalse);
    expect(back.challengeInvitesFrom, ChallengeInviteSource.nobody);
  });

  test('garbage storage falls back to safe, working defaults', () {
    final back = PrivacySettings.fromStorage(const {
      'trainingVisibility': 'nonsense',
    });
    expect(back.trainingVisibility, TrainingVisibility.friends);
    expect(back.onlineStatusVisible, isTrue);
  });
}
