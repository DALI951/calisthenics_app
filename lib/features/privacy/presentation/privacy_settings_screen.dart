import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../data/privacy_providers.dart';
import '../domain/privacy_settings.dart';

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(title, style: AppTypography.body),
  );
}

/// Privacy controls (spec §36). Every switch is written in plain words, with
/// the consequence spelled out. Location is never collected.
class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s =
        ref.watch(privacySettingsControllerProvider).value ??
        const PrivacySettings();
    final controller = ref.read(privacySettingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppCard(
            child: Text(
              'You decide what friends can see. Turning something off here '
              'stops it everywhere in the app — there is no hidden second '
              'setting. Your location is never collected, ever.',
              style: AppTypography.bodySmall,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          const _Section('Training visibility'),
          Card(
            child: RadioGroup<TrainingVisibility>(
              groupValue: s.trainingVisibility,
              onChanged: (val) => val == null
                  ? null
                  : controller.save(s.copyWith(trainingVisibility: val)),
              child: Column(
                children: [
                  for (final v in TrainingVisibility.values)
                    RadioListTile<TrainingVisibility>(
                      value: v,
                      title: Text(
                        v == TrainingVisibility.friends ? 'Friends' : 'Nobody',
                        style: AppTypography.body,
                      ),
                      subtitle: Text(
                        v == TrainingVisibility.friends
                            ? 'Friends and challenge partners can see your '
                                  'training activity.'
                            : 'Your training stays on this phone. Challenges '
                                  'still work, they just show no names.',
                        style: AppTypography.caption,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          const _Section('Who can see what'),
          Card(
            child: Column(
              children: [
                _Toggle(
                  title: 'Online status',
                  subtitle: 'Whether the app is open at all.',
                  value: s.onlineStatusVisible,
                  onChanged: (v) =>
                      controller.save(s.copyWith(onlineStatusVisible: v)),
                ),
                _Toggle(
                  title: 'Training status',
                  subtitle:
                      'The live "training now" indicator. Turning this '
                      'off also hides the pulsing dot.',
                  value: s.trainingStatusVisible,
                  onChanged: (v) =>
                      controller.save(s.copyWith(trainingStatusVisible: v)),
                ),
                _Toggle(
                  title: 'Friend activity',
                  subtitle: 'What your friends are doing, in the friends list.',
                  value: s.friendActivityVisible,
                  onChanged: (v) =>
                      controller.save(s.copyWith(friendActivityVisible: v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          const _Section('Challenge invitations'),
          Card(
            child: RadioGroup<ChallengeInviteSource>(
              groupValue: s.challengeInvitesFrom,
              onChanged: (val) => val == null
                  ? null
                  : controller.save(s.copyWith(challengeInvitesFrom: val)),
              child: Column(
                children: [
                  for (final v in ChallengeInviteSource.values)
                    RadioListTile<ChallengeInviteSource>(
                      value: v,
                      title: Text(
                        v == ChallengeInviteSource.friendsOnly
                            ? 'Friends only'
                            : 'Nobody',
                        style: AppTypography.body,
                      ),
                      subtitle: Text(
                        v == ChallengeInviteSource.friendsOnly
                            ? 'Only people you already added may invite you.'
                            : 'Nobody can invite you to a challenge.',
                        style: AppTypography.caption,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Effective right now: live training is '
            '${s.showsLiveTraining ? 'visible' : 'hidden'}, and your training '
            'is ${s.showsTrainingToOthers ? 'visible to friends' : 'visible to nobody'}.',
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    value: value,
    onChanged: onChanged,
    title: Text(title, style: AppTypography.body),
    subtitle: Text(subtitle, style: AppTypography.caption),
  );
}
