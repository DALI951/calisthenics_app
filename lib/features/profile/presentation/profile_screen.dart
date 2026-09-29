import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../auth/data/auth_providers.dart';
import '../../notifications/presentation/notification_settings_screen.dart';
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
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy',
            subtitle: 'Training visibility, online status (Phase 6)',
            onTap: null,
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
          AppSectionTitle('Coming in later phases'),
          AppCard(
            child: Column(
              children: [
                _ComingRow('Privacy controls', 'Training + online visibility'),
                _ComingRow('Notifications', 'Granular friend/challenge alerts'),
                _ComingRow('Units', 'kg/lb, km/mi'),
                _ComingRow('Account deletion', 'Erase all synced data'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
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

class _ComingRow extends StatelessWidget {
  const _ComingRow(this.title, this.subtitle);

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.body),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall.apply(color: secondary),
                ),
              ],
            ),
          ),
          AppChip(label: 'Soon'),
        ],
      ),
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
