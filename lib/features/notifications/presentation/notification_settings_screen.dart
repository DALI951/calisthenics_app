import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../data/notification_providers.dart';
import '../domain/notification.dart';

/// Granular notification settings (spec §35). Every switch is honest about
/// what it sends and why it is off by default.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  static const _descriptions = <NotificationKind, String>{
    NotificationKind.friendRequest:
        'Someone added you — you should hear about it.',
    NotificationKind.challengeInvite: 'A friend invites you to a challenge.',
    NotificationKind.challengeEndingSoon:
        'A challenge you joined closes in 24h.',
    NotificationKind.challengeCompleted:
        'A challenge finished — here is the honest result.',
    NotificationKind.friendStartedTraining: 'Off by default: your friends do not need to know when you open the app.',
    NotificationKind.restTimerDone:
        'Your rest timer finished. Only while a workout is running.',
    NotificationKind.workoutReminder: 'Off by default: no nags to come train.',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(notificationSettingsControllerProvider).value ??
        NotificationSettings.defaults;

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppCard(
            child: Text(
              'Notifications are quiet by design: at most a few a day, never '
              'between 22:00 and 08:00, and never to make you feel behind.',
              style: AppTypography.bodySmall,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final kind in NotificationKind.values)
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: SwitchListTile(
                value: settings.isOn(kind),
                onChanged: (v) => ref
                    .read(notificationSettingsControllerProvider.notifier)
                    .set(kind, v),
                title: Text(_label(kind), style: AppTypography.body),
                subtitle: Text(
                  _descriptions[kind] ?? '',
                  style: AppTypography.caption,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _label(NotificationKind kind) => switch (kind) {
    NotificationKind.friendRequest => 'Friend requests',
    NotificationKind.challengeInvite => 'Challenge invitations',
    NotificationKind.challengeEndingSoon => 'Challenge ending soon',
    NotificationKind.challengeCompleted => 'Challenge completed',
    NotificationKind.friendStartedTraining => 'Friend started training',
    NotificationKind.restTimerDone => 'Rest timer finished',
    NotificationKind.workoutReminder => 'Workout reminder',
  };
}
