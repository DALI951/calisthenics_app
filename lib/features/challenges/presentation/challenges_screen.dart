import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_shell.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../auth/data/auth_providers.dart';
import '../data/challenges_providers.dart';
import '../domain/challenge.dart';
import 'create_challenge_screen.dart';
import 'challenge_detail_screen.dart';

/// Challenge hub (spec §24): live challenges, invitations, history.
class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authControllerProvider).value != null;
    final all = ref.watch(myChallengesProvider).value ?? const <Challenge>[];
    final me = ref.watch(authControllerProvider).value?.id ?? '';

    final live = all
        .where((c) => !c.status.isOver && c.status != ChallengeStatus.declined)
        .toList();
    final invites = all
        .where(
          (c) => c.status == ChallengeStatus.pending && c.opponentUid == me,
        )
        .toList();
    final past = all.where((c) => c.status.isOver).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: ShellAppBar(
          title: 'Challenges',
          bottom: TabBar(
            tabs: [
              Tab(text: 'Live (${live.length})'),
              Tab(text: 'Invites (${invites.length})'),
              Tab(text: 'History'),
            ],
          ),
        ),
        floatingActionButton: signedIn && live.length < 3
            ? FloatingActionButton.extended(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CreateChallengeScreen(),
                  ),
                ),
                icon: const Icon(Icons.flag_outlined),
                label: const Text('New challenge'),
              )
            : null,
        body: !signedIn
            ? const AppEmptyState(
                title: 'Sign in to challenge',
                message: 'Challenges need an account and a training partner.',
                icon: Icons.lock_outline,
              )
            : TabBarView(
                children: [
                  _ChallengeList(
                    challenges: live,
                    me: me,
                    empty: AppEmptyState(
                      title: 'No live challenges',
                      message:
                          'Create one against a friend — consistency beats '
                          'max effort every time.',
                      icon: Icons.emoji_events_outlined,
                    ),
                  ),
                  _ChallengeList(
                    challenges: invites,
                    me: me,
                    empty: const AppEmptyState(
                      title: 'No invitations',
                      message: 'When a friend challenges you, it lands here.',
                      icon: Icons.sports_mma_outlined,
                    ),
                  ),
                  _ChallengeList(
                    challenges: past,
                    me: me,
                    empty: const AppEmptyState(
                      title: 'Nothing finished yet',
                      message: 'Completed challenges are archived here.',
                      icon: Icons.history,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ChallengeList extends StatelessWidget {
  const _ChallengeList({
    required this.challenges,
    required this.me,
    required this.empty,
  });

  final List<Challenge> challenges;
  final String me;
  final Widget empty;

  @override
  Widget build(BuildContext context) {
    if (challenges.isEmpty) return empty;
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: challenges.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final c = challenges[i];
        return ChallengeCard(
          challenge: c,
          me: me,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ChallengeDetailScreen(challengeId: c.id),
            ),
          ),
        );
      },
    );
  }
}

/// Spec §"ChallengeCard": ⚔️ title, status, period, progress hints.
class ChallengeCard extends StatelessWidget {
  const ChallengeCard({
    super.key,
    required this.challenge,
    required this.me,
    this.onTap,
  });

  final Challenge challenge;
  final String me;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final pending = challenge.status == ChallengeStatus.pending;
    return AppCard(
      onTap: onTap,
      highlight: challenge.status == ChallengeStatus.active,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                challenge.isHeadToHead ? '⚔️' : '🏁',
                style: AppTypography.title,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  challenge.title(me),
                  style: AppTypography.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'You vs @${challenge.opponentOf(me)}',
            style: AppTypography.caption.copyWith(color: secondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _StatusChip(status: challenge.status),
              const Spacer(),
              Text(
                pending ? 'Awaiting reply' : _remainingLabel(challenge),
                style: AppTypography.caption.copyWith(color: secondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _remainingLabel(Challenge c) {
    final left = c.endsAt.difference(DateTime.now().toUtc());
    if (left.isNegative) return 'Finished';
    if (left.inDays >= 1) return '${left.inDays}d left';
    return '${left.inHours}h left';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final ChallengeStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      ChallengeStatus.pending => (AppColors.textDisabled, 'Pending'),
      ChallengeStatus.accepted => (AppColors.accentLight, 'Accepted'),
      ChallengeStatus.active => (AppColors.success, 'Live'),
      ChallengeStatus.completed => (AppColors.success, 'Completed'),
      ChallengeStatus.expired => (AppColors.textDisabled, 'Expired'),
      ChallengeStatus.declined => (AppColors.textDisabled, 'Declined'),
      ChallengeStatus.cancelled => (AppColors.textDisabled, 'Cancelled'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
