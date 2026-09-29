import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/update/update_providers.dart';
import '../../auth/data/account_deletion_providers.dart';
import '../../auth/data/auth_providers.dart';
import '../../notifications/presentation/notification_settings_screen.dart';
import '../../privacy/presentation/privacy_settings_screen.dart';
import '../presentation/profile_providers.dart';

/// Profile: identity, level/XP, stats, settings entry (spec §44).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Identity card
          AppCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.accent,
                  child: Text(
                    user?.initial ?? 'A',
                    style: AppTypography.title.copyWith(
                      color: AppColors.onAccent,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayLabel ?? 'Athlete',
                        style: AppTypography.title,
                      ),
                      if (user?.email != null) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          user!.email!,
                          style: AppTypography.bodySmall.apply(
                            color: secondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Level + stats
          Row(
            children: [
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: StatBlock(value: 'Lv 1', label: 'Level · 0 XP'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: StatBlock(value: '0', label: 'Workouts'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: StatBlock(value: '0', label: 'Streak'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          AppSectionTitle('Achievements'),
          AppCard(
            child: Row(
              children: [
                const Icon(
                  Icons.emoji_events_outlined,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Unlock your first achievements by completing workouts.',
                    style: AppTypography.bodySmall.apply(color: secondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          AppSectionTitle('Settings'),
          _SettingsTile(
            icon: Icons.palette_outlined,
            title: 'Appearance',
            subtitle: 'Theme mode',
            onTap: () => context.push('/profile/settings'),
          ),
          _UpdateSettingsTile(
            onCheck: () => ref.read(updateControllerProvider.notifier).check(),
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy',
            subtitle: 'Who can see your training',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PrivacySettingsScreen(),
              ),
            ),
          ),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Choose exactly what may ping you',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NotificationSettingsScreen(),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          AppSectionTitle('Account'),
          _SettingsTile(
            icon: Icons.logout,
            title: 'Sign out',
            subtitle: '',
            onTap: () async {
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) context.go('/auth');
            },
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
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
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppSectionTitle('Appearance'),
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
          const SizedBox(height: AppSpacing.md),
          AppSectionTitle('Account deletion'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Deletes your training history, your synced profile and your '
                  'sign-in. Challenges you and your partner share stay visible '
                  'to them until the server purge runs — we never quietly '
                  'delete something out from under a challenge.',
                  style: AppTypography.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () => _confirmDeleteAccount(context, ref),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete my account'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

/// Version + a manual update check. Quiet: it only speaks when you tap it, or
/// when there is genuinely a newer build.
class _UpdateSettingsTile extends ConsumerWidget {
  const _UpdateSettingsTile({required this.onCheck});
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateControllerProvider);
    final (icon, subtitle) = switch (state) {
      UpdateChecking() => (Icons.sync, 'Checking for updates…'),
      UpdateDone(hasUpdate: true) => (Icons.system_update, 'Update available'),
      UpdateDone(failed: true) => (Icons.cloud_off, 'Update check failed'),
      UpdateDone() => (Icons.verified, 'You are on the latest release'),
      UpdateDownloading() => (Icons.downloading, 'Downloading update…'),
      UpdateReadyToInstall() => (
        Icons.install_mobile,
        'Update ready to install',
      ),
      UpdateFailed() => (Icons.error_outline, 'Update failed'),
      UpdateIdle() => (Icons.system_update_alt, 'Check for updates'),
    };
    return _SettingsTile(
      icon: icon,
      title: 'App updates',
      subtitle: subtitle,
      onTap: state is UpdateChecking ? null : onCheck,
    );
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
  ref.read(authControllerProvider.notifier).signOut();
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

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.body),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.apply(color: secondary),
                  ),
                ],
              ],
            ),
          ),
          if (onTap != null)
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
