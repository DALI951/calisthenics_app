import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_card.dart';
import '../../exercises/data/exercise_library.dart';
import '../domain/workout_session.dart';
import 'workout_session_controller.dart';

/// The live workout screen (spec Â§14): warm-up â†’ sets â†’ rest â†’ next.
/// The rest timer lives INSIDE this screen; timestamp math means it stays
/// correct even if the app is backgrounded (spec Â§15, Â§70).
class WorkoutSessionScreen extends ConsumerStatefulWidget {
  const WorkoutSessionScreen({super.key});

  @override
  ConsumerState<WorkoutSessionScreen> createState() =>
      _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends ConsumerState<WorkoutSessionScreen> {
  int _reps = 0;
  int _seconds = 0;
  int _assisted = 0;
  bool _pain = false;
  StreamSubscription<int>? _tickSub;

  @override
  void initState() {
    super.initState();
    // Restore a possible killed-session draft on open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(workoutSessionControllerProvider.notifier).restoreDraft();
    });
  }

  @override
  void dispose() {
    _tickSub?.cancel();
    super.dispose();
  }

  void _resetInputs() {
    setState(() {
      _reps = 0;
      _seconds = 0;
      _assisted = 0;
      _pain = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(workoutSessionControllerProvider);
    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Workout')),
        body: const Center(child: Text('No active workout.')),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave(session);
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.dayName,
                style: AppTypography.bodySmall.apply(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                _phaseLabel(session.phase),
                style: AppTypography.title.copyWith(fontSize: 16),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: session.phase == WorkoutPhase.paused
                  ? 'Resume'
                  : 'Pause',
              icon: Icon(
                session.phase == WorkoutPhase.paused
                    ? Icons.play_arrow
                    : Icons.pause,
              ),
              onPressed: () {
                final ctrl = ref.read(
                  workoutSessionControllerProvider.notifier,
                );
                session.phase == WorkoutPhase.paused
                    ? ctrl.resumeWorkout()
                    : ctrl.pauseWorkout();
              },
            ),
            if (session.phase == WorkoutPhase.paused) ...[
              IconButton(
                tooltip: 'Finish workout',
                icon: const Icon(Icons.flag),
                onPressed: () => _confirmFinish(),
              ),
              IconButton(
                tooltip: 'Abandon workout',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDiscard(),
              ),
            ],
          ],
        ),
        body: switch (session.phase) {
          WorkoutPhase.warmup => _Warmup(session),
          WorkoutPhase.working || WorkoutPhase.paused => _workingView(session),
          WorkoutPhase.resting => _restView(session),
          WorkoutPhase.finished => _FinishedView(session),
        },
      ),
    );
  }

  String _phaseLabel(WorkoutPhase p) => switch (p) {
    WorkoutPhase.warmup => 'Warm-up',
    WorkoutPhase.working => 'Workout in progress',
    WorkoutPhase.resting => 'Rest',
    WorkoutPhase.paused => 'Paused',
    WorkoutPhase.finished => 'Workout complete',
  };

  Widget _workingView(WorkoutSession session) {
    final ctrl = ref.read(workoutSessionControllerProvider.notifier);
    final cur = ctrl.current;
    final exercise = ExerciseLibrary.byId(cur.exercise.exerciseId);
    final paused = session.phase == WorkoutPhase.paused;

    if (paused) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.pause_circle_outline,
                size: 72,
                color: AppColors.accentLight,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Session paused', style: AppTypography.headline),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Your progress is saved. Resume whenever you\'re ready.',
                style: AppTypography.body.apply(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppPrimaryButton(
                label: 'Resume',
                icon: Icons.play_arrow,
                onPressed: () => ctrl.resumeWorkout(),
              ),
            ],
          ),
        ),
      );
    }

    final isTimed = cur.exercise.isTimed;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // Exercise header.
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Exercise ${_exerciseIndex(session, cur.exercise.exerciseId) + 1} of ${session.exercises.length}',
                    style: AppTypography.caption.apply(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(cur.exercise.name, style: AppTypography.headline),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Set ${cur.setNumber} of ${cur.exercise.sets} â€” target ${cur.exercise.targetLabel}',
                    style: AppTypography.body.apply(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Substitute menu.
            PopupMenuButton<String>(
              tooltip: 'More options',
              onSelected: (v) {
                if (v == 'substitute') _pickSubstitute(cur.exercise);
                if (v == 'detail') {
                  context.push(
                    '/app/workouts/exercises/${cur.exercise.exerciseId}',
                  );
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'substitute',
                  child: Text('Substitute exercise'),
                ),
                PopupMenuItem(
                  value: 'detail',
                  child: Text('View instructions'),
                ),
              ],
            ),
          ],
        ),
        if (exercise != null && exercise.techniqueCues.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.tips_and_updates_outlined,
                      size: 16,
                      color: AppColors.accentLight,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text('Form cues', style: AppTypography.label),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ...exercise.techniqueCues
                    .take(3)
                    .map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('â€¢ $c', style: AppTypography.bodySmall),
                      ),
                    ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        // Set input.
        AppCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isTimed ? 'Time' : 'Reps',
                      style: AppTypography.title,
                    ),
                  ),
                  if (exercise != null)
                    Text(
                      exercise.metricLabel,
                      style: AppTypography.caption.apply(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StepperButton(
                    icon: Icons.remove,
                    onPressed: () => setState(() {
                      if (isTimed) {
                        _seconds = (_seconds - 5).clamp(0, 3600);
                      } else {
                        _reps = (_reps - 1).clamp(0, 200);
                      }
                    }),
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  Text(
                    isTimed ? '$_seconds s' : '$_reps',
                    style: AppTypography.statNumber.copyWith(fontSize: 56),
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  _StepperButton(
                    icon: Icons.add,
                    onPressed: () => setState(() {
                      if (isTimed) {
                        _seconds = (_seconds + 5).clamp(0, 3600);
                      } else {
                        _reps = (_reps + 1).clamp(0, 200);
                      }
                    }),
                  ),
                ],
              ),
              if (isTimed) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    for (final quick in [20, 30, 40, 60])
                      ActionChip(
                        label: Text('${quick}s'),
                        onPressed: () => setState(() => _seconds = quick),
                      ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    if (cur.exercise.targetMin != null &&
                        cur.exercise.targetMax != null)
                      for (final quick in [
                        cur.exercise.targetMin!,
                        cur.exercise.targetMax!,
                      ])
                        ActionChip(
                          label: Text('$quick'),
                          onPressed: () => setState(() => _reps = quick),
                        ),
                    ActionChip(
                      label: Text('${(_reps + 5).clamp(0, 200)}'),
                      onPressed: () =>
                          setState(() => _reps = (_reps + 5).clamp(0, 200)),
                    ),
                  ],
                ),
                if (exercise != null &&
                    exercise.equipment.any((e) => e.name != 'none')) ...[
                  const SizedBox(height: AppSpacing.md),
                  FilterChip(
                    label: Text('Assisted (+$_assisted)'),
                    selected: _assisted > 0,
                    onSelected: (on) => setState(() => _assisted = on ? 1 : 0),
                  ),
                ],
              ],
              if (_pain) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.health_and_safety_outlined,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Marked with pain. We\'ll pause progression on this '
                          'movement for you. If pain is significant or lasting, '
                          'rest and talk to an adult or a professional â€” never '
                          'push through it.',
                          style: AppTypography.bodySmall.apply(
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // Set action row.
        Row(
          children: [
            Expanded(
              child: AppSecondaryButton(
                label: 'Skip',
                icon: Icons.fast_forward,
                onPressed: () {
                  ctrl.skipSet();
                  _resetInputs();
                  _startRest(session);
                },
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: AppPrimaryButton(
                label: 'Confirm set',
                icon: _assisted > 0 ? Icons.assistant : Icons.check,
                onPressed: () {
                  if (isTimed && _seconds == 0) return;
                  if (!isTimed && _reps == 0) return;
                  ctrl.recordSet(
                    reps: isTimed ? null : _reps,
                    seconds: isTimed ? _seconds : null,
                    assistedReps: _assisted,
                    painReported: _pain,
                  );
                  final nextSession = ref.read(
                    workoutSessionControllerProvider,
                  );
                  if (nextSession?.phase == WorkoutPhase.finished) {
                    _finishFlow();
                    return;
                  }
                  _resetInputs();
                  if (nextSession?.phase == WorkoutPhase.resting) {
                    _startRest(nextSession!);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: session.sets.isEmpty
                  ? null
                  : () {
                      ctrl.undoLastSet();
                      _resetInputs();
                    },
              icon: const Icon(Icons.undo, size: 18),
              label: const Text('Undo last set'),
            ),
            TextButton.icon(
              onPressed: _pain ? null : () => setState(() => _pain = true),
              icon: const Icon(Icons.highlight_off, size: 18),
              label: Text(_pain ? 'Pain noted' : 'Mark pain / discomfort'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Text(
            '${session.completedSetCount} set${session.completedSetCount == 1 ? '' : 's'} recorded',
            style: AppTypography.caption.apply(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  void _startRest(WorkoutSession session) {
    final cfg = ref
        .read(workoutSessionControllerProvider.notifier)
        .restConfig();
    ref
        .read(restTimerControllerProvider.notifier)
        .start(
          cfg.seconds,
          exerciseId: cfg.exerciseId,
          setNumber: cfg.setNumber,
        );
  }

  Widget _restView(WorkoutSession session) {
    final timer = ref.watch(restTimerControllerProvider);
    // Subscribe to the ticker only while resting (cost control, Â§71).
    ref.watch(restTickerProvider);
    final ctrl = ref.read(workoutSessionControllerProvider.notifier);
    final timerCtrl = ref.read(restTimerControllerProvider.notifier);

    if (timer == null) {
      return Center(
        child: AppPrimaryButton(
          label: 'Start next set',
          onPressed: () {
            ctrl.nextSetNow();
          },
        ),
      );
    }

    final now = DateTime.now();
    final remaining = timer.remainingAt(now);
    final progress = timer.totalSeconds == 0
        ? 0.0
        : (remaining.inMilliseconds / (timer.totalSeconds * 1000))
              .clamp(0.0, 1.0)
              .toDouble();
    final display = timer.isPaused
        ? remaining
        : (remaining.inSeconds <= 0
              ? Duration.zero
              : remaining + const Duration(milliseconds: 999));

    // Auto-advance at zero.
    if (!timer.isPaused && remaining.inSeconds <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        timerCtrl.skip();
        ctrl.nextSetNow();
      });
    }

    final nextExercise =
        session.exercises[(session.currentExerciseIndex(session.sets) + 0)
            .clamp(0, session.exercises.length - 1)];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const SizedBox(height: AppSpacing.md),
        Center(
          child: SizedBox(
            width: 260,
            height: 260,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 260,
                  height: 260,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timer.isPaused ? 'Paused' : 'Rest',
                      style: AppTypography.bodySmall.apply(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${display.inMinutes}:${(display.inSeconds % 60).toString().padLeft(2, '0')}',
                      style: AppTypography.statNumber.copyWith(fontSize: 48),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: AppSecondaryButton(
                label: timer.isPaused ? 'Resume' : 'Pause',
                icon: timer.isPaused ? Icons.play_arrow : Icons.pause,
                onPressed: timer.isPaused ? timerCtrl.resume : timerCtrl.pause,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppSecondaryButton(
                label: 'Skip',
                icon: Icons.skip_next,
                onPressed: () {
                  timerCtrl.skip();
                  ctrl.nextSetNow();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => timerCtrl.addSeconds(-15),
                icon: const Icon(Icons.remove, size: 18),
                label: const Text('15s'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => timerCtrl.addSeconds(15),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('15s'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Next',
                style: AppTypography.caption.apply(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(nextExercise.name, style: AppTypography.title),
              Text(
                'Set ${nextExercise.sets} of ${nextExercise.sets} â€” ${nextExercise.targetLabel}',
                style: AppTypography.bodySmall.apply(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _finishFlow() async {
    final completed = await ref
        .read(workoutSessionControllerProvider.notifier)
        .finish();
    if (!mounted) return;
    ref.read(restTimerControllerProvider.notifier).skip();
    context.pushReplacement('/app/workouts/session/summary', extra: completed);
  }

  Future<void> _confirmFinish() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finish workout?'),
        content: const Text('Record what you\'ve done and go to the summary.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Finish'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) _finishFlow();
  }

  Future<void> _confirmLeave(WorkoutSession session) async {
    if (session.phase == WorkoutPhase.finished) {
      context.pop();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave workout?'),
        content: const Text(
          'Your session stays saved â€” you can resume it '
          'from the Workouts tab. Nothing is lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) context.pop();
  }

  Future<void> _confirmDiscard() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Abandon workout?'),
        content: const Text(
          'This removes ALL recorded sets of this session. '
          'There is no undo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abandon'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await ref.read(workoutSessionControllerProvider.notifier).discard();
      if (mounted) context.pop();
    }
  }

  Future<void> _pickSubstitute(SessionExercise current) async {
    final all = ExerciseLibrary.all
        .where((e) => e.id != current.exerciseId)
        .toList();
    if (all.isEmpty) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text('Substitute ${current.name}', style: AppTypography.title),
            const SizedBox(height: AppSpacing.sm),
            ...all.map(
              (e) => ListTile(
                title: Text(e.name),
                subtitle: Text('${e.category.label} â€¢ ${e.difficulty.label}'),
                leading: const Icon(Icons.swap_horiz),
                onTap: () => Navigator.pop(ctx, e.id),
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) {
      ref
          .read(workoutSessionControllerProvider.notifier)
          .substituteExercise(picked);
    }
  }

  int _exerciseIndex(WorkoutSession session, String exerciseId) =>
      session.exercises.indexWhere((e) => e.exerciseId == exerciseId);
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        minimumSize: const Size(56, 56),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      tooltip: icon == Icons.add ? 'Increase' : 'Decrease',
    );
  }
}

class _Warmup extends ConsumerWidget {
  const _Warmup(this.session);

  final WorkoutSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final secondary = AppColors.textSecondary;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.md),
        const Icon(Icons.spa_outlined, size: 72, color: AppColors.accentLight),
        const SizedBox(height: AppSpacing.lg),
        Text('Warm up first', style: AppTypography.headline),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'A short warm-up makes every rep safer (spec Â§29):',
          style: AppTypography.body.apply(color: secondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        const _WarmupItem(
          icon: Icons.rotate_left,
          label: 'Shoulder circles â€” 10 each way',
        ),
        const _WarmupItem(
          icon: Icons.back_hand_outlined,
          label: 'Wrist circles â€” 10 each way',
        ),
        const _WarmupItem(
          icon: Icons.directions_walk,
          label: 'Light movement â€” 1â€“2 minutes',
        ),
        const _WarmupItem(
          icon: Icons.fitness_center,
          label: 'Easy versions of today\'s first exercises',
        ),
        const SizedBox(height: AppSpacing.xl),
        AppPrimaryButton(
          label: 'Start workout',
          icon: Icons.play_arrow,
          onPressed: () => ref
              .read(workoutSessionControllerProvider.notifier)
              .beginWorking(),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppSecondaryButton(
          label: 'Skip warm-up',
          onPressed: () => ref
              .read(workoutSessionControllerProvider.notifier)
              .beginWorking(),
        ),
      ],
    );
  }
}

class _WarmupItem extends StatelessWidget {
  const _WarmupItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.accentLight),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: AppTypography.body)),
        ],
      ),
    );
  }
}

class _FinishedView extends ConsumerWidget {
  const _FinishedView(this.session);

  final WorkoutSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.celebration_outlined,
              size: 72,
              color: AppColors.success,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Workout complete', style: AppTypography.headline),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${session.completedSetCount} sets, ${session.totalReps} reps',
              style: AppTypography.body.apply(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppPrimaryButton(
              label: 'See summary',
              icon: Icons.summarize_outlined,
              onPressed: () async {
                final completed = await ref
                    .read(workoutSessionControllerProvider.notifier)
                    .finish();
                if (context.mounted) {
                  context.pushReplacement(
                    '/app/workouts/session/summary',
                    extra: completed,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
