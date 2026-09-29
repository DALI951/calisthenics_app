import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../data/challenges_providers.dart';
import '../domain/challenge.dart';
import '../domain/challenge_engine.dart';

/// Challenge detail (spec §24): both progress bars, time remaining,
/// accept/decline/cancel, healthy copy — never "winner/loser".
class ChallengeDetailScreen extends ConsumerWidget {
  const ChallengeDetailScreen({super.key, required this.challengeId});

  final String challengeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(challengeViewProvider(challengeId)).value;

    if (view == null || view.missing || view.challenge == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final c = view.challenge!;
    final myUid = view.myUid;
    final opp = c.opponentUidOf(myUid);
    final oppHandle = c.opponentOf(myUid);
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final myValue = view.valueOf(myUid) ?? 0;
    final oppValue = view.valueOf(opp) ?? 0;
    final unit =
        view.myProgress?.unitLabel ?? c.type.unit(ChallengeEngine.metricFor(c));

    return Scaffold(
      appBar: AppBar(
        title: Text(c.isHeadToHead ? '⚔️ Head to head' : '🏁 Challenge'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(c.title(myUid), style: AppTypography.title),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'You vs @$oppHandle · ${c.type.label}',
            style: AppTypography.caption.copyWith(color: secondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          _ProgressRow(
            label: 'You',
            value: myValue,
            target: c.target,
            unit: unit,
            highlight: true,
          ),
          const SizedBox(height: AppSpacing.md),
          _ProgressRow(
            label: '@$oppHandle',
            value: oppValue,
            target: c.target,
            unit: unit,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Row(
              children: [
                Icon(
                  c.status == ChallengeStatus.active
                      ? Icons.timer_outlined
                      : Icons.info_outline,
                  color: AppColors.accentLight,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(_statusLine(c), style: AppTypography.body),
                ),
              ],
            ),
          ),
          if (c.result != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppCard(
              highlight: true,
              child: Text(
                c.result!.isDraw
                    ? 'Dead heat — you both showed up. 🤝'
                    : c.result!.winnerUid == myUid
                    ? 'You took this one. Both of you showed up. 💪'
                    : '@$oppHandle took this one. You still showed up. 💪',
                style: AppTypography.body,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _Actions(view: view),
        ],
      ),
    );
  }

  String _statusLine(Challenge c) {
    switch (c.status) {
      case ChallengeStatus.pending:
        return 'Waiting for @${c.opponentHandle} to accept.';
      case ChallengeStatus.accepted:
        return 'Starts ${c.startsAt.toIso8601String().substring(0, 10)}.';
      case ChallengeStatus.active:
        final left = c.endsAt.difference(DateTime.now().toUtc());
        return '${left.inHours > 0 ? '${left.inHours} hours' : '${left.inMinutes} minutes'} remaining.';
      case ChallengeStatus.completed:
        return 'Finished — nice work from both sides.';
      case ChallengeStatus.expired:
        return 'Time is up. Start a new one whenever.';
      case ChallengeStatus.declined:
        return 'Declined.';
      case ChallengeStatus.cancelled:
        return 'Cancelled.';
    }
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.value,
    required this.target,
    required this.unit,
    this.highlight = false,
  });

  final String label;
  final int value;
  final int target;
  final String unit;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final frac = target <= 0
        ? 0.0
        : (value / target).clamp(0.0, 1.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTypography.title),
            Text(
              '$value / $target $unit',
              style: AppTypography.body.copyWith(
                color: highlight ? AppColors.accentLight : secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: frac,
            minHeight: 10,
            backgroundColor: secondary.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(
              highlight ? AppColors.accentLight : AppColors.success,
            ),
          ),
        ),
      ],
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.view});
  final ChallengeView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = view.challenge!;
    final repo = ref.read(challengeRepositoryProvider);
    if (c.status == ChallengeStatus.pending && view.isOpponent) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _set(repo, c, ChallengeStatus.declined),
              child: const Text('Decline'),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: FilledButton(
              onPressed: () => _set(repo, c, ChallengeStatus.accepted),
              child: const Text('Accept'),
            ),
          ),
        ],
      );
    }
    if (c.status == ChallengeStatus.pending && view.isCreator) {
      return OutlinedButton(
        onPressed: () => _set(repo, c, ChallengeStatus.cancelled),
        child: const Text('Cancel challenge'),
      );
    }
    if (c.status.isLive) {
      return OutlinedButton(
        onPressed: () => _set(repo, c, ChallengeStatus.cancelled),
        child: const Text('End challenge'),
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _set(dynamic repo, Challenge c, ChallengeStatus next) async {
    if (!ChallengeEngine.canTransition(c.status, next)) return;
    await repo.setStatus(c, next);
  }
}
