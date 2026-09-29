import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/router/app_shell.dart';
import '../../../core/widgets/app_card.dart';
import '../../auth/data/auth_providers.dart';
import '../../workout_session/presentation/workout_session_controller.dart';
import '../data/train_together_providers.dart';
import '../domain/live_pair_state.dart';
import '../domain/train_together_engine.dart';

/// Train Together (spec §22): the same workout, side by side, synchronized.
/// Shared workout state only — not a surveillance feature, no video call.
class TrainTogetherScreen extends ConsumerStatefulWidget {
  const TrainTogetherScreen({
    super.key,
    required this.partnerUid,
    required this.partnerHandle,
  });

  final String partnerUid;
  final String partnerHandle;

  @override
  ConsumerState<TrainTogetherScreen> createState() =>
      _TrainTogetherScreenState();
}

class _TrainTogetherScreenState extends ConsumerState<TrainTogetherScreen> {
  StreamSubscription<dynamic>? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(trainTogetherSessionProvider.notifier).start(widget.partnerUid);
    });
    // One shared ticker for both rest countdowns.
    _ticker = Stream.periodic(const Duration(seconds: 1)).listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Mirror MY progress the moment a set is recorded / skipped / the phase
    // changes — this is the whole synchronization loop.
    ref.listen(workoutSessionControllerProvider, (_, _) {
      ref.read(trainTogetherSessionProvider.notifier).syncNow();
    });
    final pair = ref.watch(trainTogetherProvider(widget.partnerUid)).value;
    final session = ref.watch(workoutSessionControllerProvider);
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;

    if (pair == null) {
      return Scaffold(
        appBar: const ShellAppBar(title: 'Train together'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final phase = TrainTogetherEngine.phaseForMe(pair);
    final remaining = pair.restRemaining;

    return Scaffold(
      appBar: const ShellAppBar(title: 'Train together'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppCard(
            highlight: true,
            child: Column(
              children: [
                Text(pair.exerciseLabel, style: AppTypography.title),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  TrainTogetherEngine.statusLine(pair),
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(color: secondary),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _AthleteTile(
                        label: 'You',
                        setLabel: _setLabel(pair.me),
                        phase: pair.meSetComplete,
                        highlight: true,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _AthleteTile(
                        label: '@${widget.partnerHandle}',
                        setLabel: _setLabel(pair.partner),
                        phase: pair.partnerSetComplete,
                        highlight: false,
                        offline: !pair.partnerOnline,
                      ),
                    ),
                  ],
                ),
                if (phase == LivePhase.resting && remaining != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: Column(
                      children: [
                        Text('REST', style: AppTypography.title),
                        Text(
                          '${remaining.inSeconds}s',
                          style: AppTypography.title.copyWith(
                            color: AppColors.accentLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (phase == LivePhase.waiting)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: Text(
                      'Waiting for @${widget.partnerHandle}…',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textDisabled,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (TrainTogetherEngine.shouldOfferSoloContinue(pair)) ...[
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                children: [
                  Text(
                    'Your partner seems away. Keep training or keep waiting '
                    '— nothing is lost either way.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(color: secondary),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: () =>
                        ref.read(trainTogetherSessionProvider.notifier).stop(),
                    child: const Text('Train solo'),
                  ),
                ],
              ),
            ),
          ],
          if (session != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, color: AppColors.accentLight),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Your workout is syncing live. Record sets as usual — '
                      'they show up for your partner.',
                      style: AppTypography.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Text(
                'No workout running. Start one from the Workouts tab and it '
                'will sync here automatically.',
                style: AppTypography.bodySmall.copyWith(color: secondary),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text('Send some energy', style: AppTypography.title),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final e in TrainTogetherEngine.cheers)
                IconButton.filledTonal(
                  onPressed: () => _cheer(e),
                  icon: Text(e, style: AppTypography.title),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          StreamBuilder<List<Cheer>>(
            stream: ref
                .read(trainTogetherRepositoryProvider)
                .watchCheers(
                  trainPairId(
                    ref.watch(authControllerProvider).value?.id ?? 'me',
                    widget.partnerUid,
                  ),
                ),
            builder: (context, snap) {
              final cheers = (snap.data ?? const <Cheer>[])
                  .where(
                    (c) => c.at.isAfter(
                      DateTime.now().toUtc().subtract(
                        const Duration(seconds: 8),
                      ),
                    ),
                  )
                  .toList();
              if (cheers.isEmpty) return const SizedBox.shrink();
              return Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final c in cheers)
                    Chip(
                      avatar: Text(c.emoji),
                      label: Text(c.fromHandle),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _setLabel(LiveAthleteState? s) {
    if (s == null) return 'Not joined';
    if (s.totalSets == 0) return '—';
    return 'Set ${s.setNumber}/${s.totalSets}';
  }

  Future<void> _cheer(String emoji) async {
    final me = ref.read(authControllerProvider).value?.id;
    if (me == null) return;
    await ref
        .read(trainTogetherRepositoryProvider)
        .sendCheer(trainPairId(me, widget.partnerUid), emoji);
  }
}

class _AthleteTile extends StatelessWidget {
  const _AthleteTile({
    required this.label,
    required this.setLabel,
    required this.phase,
    required this.highlight,
    this.offline = false,
  });

  final String label;
  final String setLabel;
  final bool phase;
  final bool highlight;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      children: [
        Text(label, style: AppTypography.body),
        const SizedBox(height: AppSpacing.xs),
        Text(
          setLabel,
          style: AppTypography.title.copyWith(
            color: offline
                ? AppColors.textDisabled
                : highlight
                ? AppColors.accentLight
                : AppColors.success,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          offline
              ? 'away'
              : phase
              ? 'set done ✓'
              : 'training',
          style: AppTypography.caption.copyWith(color: secondary),
        ),
      ],
    );
  }
}
