import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_shell.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_empty_state.dart';

/// Challenges tab (spec §23). Creation/acceptance flows land in Phase 8;
/// the empty state is already the designed final state.
class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: ShellAppBar(title: 'Challenges'),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: AppEmptyState(
          title: 'No challenges yet',
          message:
              'Challenge a friend to a healthy competition — consistency, '
              'volume or a head-to-head milestone.',
          icon: Icons.emoji_events_outlined,
          actionLabel: 'Go to friends',
          onAction: () => context.go('/app/friends'),
        ),
      ),
    );
  }
}
