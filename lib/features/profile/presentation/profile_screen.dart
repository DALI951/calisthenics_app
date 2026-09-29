import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/update/update_providers.dart';
import '../../../core/widgets/app_card.dart';
import '../../achievements/data/achievement_stats_provider.dart';
import '../../achievements/data/achievements_providers.dart';
import '../../achievements/domain/achievement.dart';
import '../../achievements/domain/achievement_engine.dart';
import '../../auth/data/account_deletion_providers.dart';
import '../../auth/data/auth_providers.dart';
import '../../notifications/presentation/notification_settings_screen.dart';
import '../../privacy/presentation/privacy_settings_screen.dart';
import '../../workout_session/data/workout_history_repository.dart';
import '../../workout_session/domain/personal_records.dart';
import '../../workout_session/domain/workout_session.dart';
import '../presentation/profile_providers.dart';

/// Profile: identity, real training numbers, then every setting in one place.
///
/// Design rules held here: ONE accent (red) reserved for actions and progress,
/// a single type scale, hairline-separated rows instead of a stack of boxes,
/// and no number on this screen that isn't derived from real training data.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final history =
        ref.watch(workoutHistoryRepositoryProvider).value ??
        const <WorkoutSession>[];
    final stats = ref.watch(achievementStatsProvider).value;
    final unlocked =
        ref.watch(unlockedAchievementsProvider).value ??
        const <UnlockedAchievement>[];

    // Real XP, derived from sessions only — never from opening the app.
    final xp = XpEngine.totalFromSessions(history.map((s) => s.estimatedXp));
    final level = XpEngine.levelForXp(xp);
    final progress = XpEngine.levelProgress(xp);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: const [_AppVersion()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        children: [
          _IdentityCard(
            initial: user?.initial ?? 'A',
            name: user?.displayLabel ?? 'Athlete',
            email: user?.email,
            level: level,
            progress: progress,
            xp: xp,
            toNextLevel: XpEngine.xpToNextLevel(xp),
          ),
          const SizedBox(height: AppSpacing.md),

          // Real numbers. Honest zeros, never a fake "Lv 1" placeholder.
          Row(
            children: [
              Expanded(
                child: _Stat(
                  value: '${stats?.workoutsCompleted ?? history.length}',
                  label: 'Workouts',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _Stat(
                  value: '${stats?.currentStreak ?? 0}',
                  label: 'Day streak',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _Stat(
                  value: '${stats?.setsCompleted ?? 0}',
                  label: 'Sets',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // Personal bests — the numbers that actually motivate progression.
          const AppSectionTitle('Personal bests'),
          _BestsCard(
            pushups: stats?.bestPushups ?? 0,
            pullups: stats?.bestPullups ?? 0,
            plankSeconds: stats?.bestPlankSeconds ?? 0,
            hasAny: (stats?.workoutsCompleted ?? history.length) > 0,
            onTap: () => context.push('/app/progress/history'),
          ),
          const SizedBox(height: AppSpacing.xl),

          const AppSectionTitle('Your training'),
          _SettingsGroup(
            children: [
              _SettingsRow(
                icon: Icons.emoji_events_outlined,
                title: 'Achievements',
                subtitle: unlocked.isEmpty
                    ? 'Earned by training — never by opening the app'
                    : '${unlocked.length} of ${Achievements.all.length} unlocked',
                onTap: () => context.push('/app/progress/achievements'),
              ),
              _SettingsRow(
                icon: Icons.straighten,
                title: 'My maxes',
                subtitle: 'Set your top push-ups, pull-ups and more',
                onTap: () => context.push('/profile/maxes'),
              ),
              _SettingsRow(
                icon: Icons.insights_outlined,
                title: 'Progress',
                subtitle: 'Charts, streaks and consistency',
                onTap: () => context.push('/app/progress'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          const AppSectionTitle('Settings'),
          _SettingsGroup(
            children: [
              _SettingsRow(
                icon: Icons.palette_outlined,
                title: 'Appearance',
                subtitle: 'Theme mode',
                onTap: () => context.push('/profile/settings'),
              ),
              _SettingsRow(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy',
                subtitle: 'Who can see your training',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PrivacySettingsScreen(),
                  ),
                ),
              ),
              _SettingsRow(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Choose exactly what may ping you',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NotificationSettingsScreen(),
                  ),
                ),
              ),
              const _UpdateSettingsRow(),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // Destructive actions live together, at the bottom, in danger red —
          // never mixed in with the everyday settings.
          const AppSectionTitle('Account'),
          _SettingsGroup(
            children: [
              _SettingsRow(
                icon: Icons.logout,
                title: 'Sign out',
                danger: true,
                onTap: () => _confirmSignOut(context, ref),
              ),
              _SettingsRow(
                icon: Icons.delete_outline,
                title: 'Delete account',
                subtitle: 'History, profile and sign-in',
                danger: true,
                onTap: () => _confirmDeleteAccount(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
  final out = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Sign out?'),
      content: const Text('Your history stays on this account.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Stay signed in'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Sign out'),
        ),
      ],
    ),
  );
  if (out == true) {
    await ref.read(authControllerProvider.notifier).signOut();
  }
}

/// Two deliberate confirmations for an irreversible action, then an honest
/// report of what was actually removed.
Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete your account?'),
      content: const Text(
        'This permanently removes your history, achievements and profile. '
        'There is no undo and no backup.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Keep my account'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Delete everything'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final report = await ref.read(accountDeletionServiceProvider).run();
  await ref.read(authControllerProvider.notifier).signOut();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Account deleted'),
      content: Text(report.describe()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// Identity + the one progress bar worth having: XP toward the next level.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.initial,
    required this.name,
    required this.email,
    required this.level,
    required this.progress,
    required this.xp,
    required this.toNextLevel,
  });

  final String initial;
  final String name;
  final String? email;
  final int level;
  final double progress;
  final int xp;
  final int toNextLevel;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.accent,
                child: Text(
                  initial,
                  style: AppTypography.title.copyWith(
                    color: AppColors.onAccent,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTypography.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (email != null)
                      Text(
                        email!,
                        style: AppTypography.bodySmall.apply(color: secondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Text('Level $level', style: AppTypography.label),
              const Spacer(),
              Text(
                '$xp XP · $toNextLevel to level ${level + 1}',
                style: AppTypography.caption.apply(color: secondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.surfaceRaised,
              valueColor: const AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
    child: StatBlock(value: value, label: label),
  );
}

/// Best set per skill. Empty state is explicit — "no workouts yet" instead of
/// three silent zeros.
class _BestsCard extends StatelessWidget {
  const _BestsCard({
    required this.pushups,
    required this.pullups,
    required this.plankSeconds,
    required this.hasAny,
    required this.onTap,
  });

  final int pushups;
  final int pullups;
  final int plankSeconds;
  final bool hasAny;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: hasAny
          ? Row(
              children: [
                _Best(value: '$pushups', label: 'Push-ups'),
                _Divider(),
                _Best(value: '$pullups', label: 'Pull-ups'),
                _Divider(),
                _Best(value: '${plankSeconds}s', label: 'Plank'),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Text(
                    'Your best push-ups, pull-ups and plank show up here once '
                    'you log a set.',
                    style: AppTypography.bodySmall.apply(color: secondary),
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
    );
  }
}

class _Best extends StatelessWidget {
  const _Best({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppTypography.statNumber),
          const SizedBox(height: AppSpacing.xxs),
          Text(label, style: AppTypography.caption.apply(color: secondary)),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: AppColors.hairline);
}

/// One card, hairline-separated rows — no stack of separate boxes.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            const Divider(
              height: 1,
              thickness: 1,
              color: AppColors.hairline,
              indent: AppSpacing.lg,
            ),
          children[i],
        ],
      ],
    ),
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final tint = danger ? AppColors.danger : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: tint),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.body.apply(
                      color: danger ? AppColors.danger : null,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle!,
                      style: AppTypography.caption.apply(color: secondary),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Quiet: speaks only when tapped, or when there is genuinely something new.
class _UpdateSettingsRow extends ConsumerWidget {
  const _UpdateSettingsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateControllerProvider);
    final (icon, subtitle) = switch (state) {
      UpdateChecking() => (Icons.sync, 'Checking for updates…'),
      UpdateDone(hasUpdate: true) => (Icons.system_update, 'Update available'),
      UpdateDone(failed: true) => (Icons.cloud_off, 'Update check failed'),
      UpdateDone() => (Icons.verified, 'You are on the latest release'),
      UpdateDownloading() => (Icons.downloading, 'Downloading update…'),
      UpdateReadyToInstall() => (Icons.install_mobile, 'Ready to install'),
      UpdateFailed() => (Icons.error_outline, 'Update failed'),
      UpdateIdle() => (Icons.system_update_alt, 'Check for updates'),
    };
    return _SettingsRow(
      icon: icon,
      title: 'App updates',
      subtitle: subtitle,
      onTap: state is UpdateChecking
          ? null
          : () => ref.read(updateControllerProvider.notifier).check(),
    );
  }
}

/// Version in the app bar — the updater's "what am I running" answer.
class _AppVersion extends ConsumerWidget {
  const _AppVersion();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) {
        final v = snap.data;
        if (v == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          child: Center(
            child: Text(
              'v${v.version}',
              style: AppTypography.caption.apply(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Settings screen (real working controls only).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode =
        ref.watch(themeModeControllerProvider).value ?? ThemeMode.system;

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppCard(
            child: RadioGroup<ThemeMode>(
              groupValue: themeMode,
              onChanged: (mode) {
                if (mode != null) {
                  ref.read(themeModeControllerProvider.notifier).set(mode);
                }
              },
              child: Column(
                children: [
                  _ThemeOption(
                    label: 'System',
                    description: 'Follow the phone setting',
                    value: ThemeMode.system,
                    onTap: () => ref
                        .read(themeModeControllerProvider.notifier)
                        .set(ThemeMode.system),
                  ),
                  _ThemeOption(
                    label: 'Dark',
                    description: 'The Calisthenics look',
                    value: ThemeMode.dark,
                    onTap: () => ref
                        .read(themeModeControllerProvider.notifier)
                        .set(ThemeMode.dark),
                  ),
                  _ThemeOption(
                    label: 'Light',
                    description: 'High-contrast bright mode',
                    value: ThemeMode.light,
                    onTap: () => ref
                        .read(themeModeControllerProvider.notifier)
                        .set(ThemeMode.light),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.description,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String description;
  final ThemeMode value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: AppTypography.body),
      subtitle: Text(description, style: AppTypography.bodySmall),
      trailing: Radio<ThemeMode>(value: value),
      onTap: onTap,
    );
  }
}

class AppSectionTitle extends StatelessWidget {
  const AppSectionTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title,
        style: AppTypography.label.apply(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
