import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../auth/data/auth_providers.dart';
import '../../exercises/data/exercise_library.dart';
import '../../friends/data/friends_providers.dart';
import '../../friends/domain/friend_models.dart';
import '../data/challenge_repository.dart';
import '../data/challenges_providers.dart';
import '../domain/challenge.dart';
import '../domain/challenge_engine.dart';

/// Challenge creation (spec §24). Safety-first: targets are capped by
/// [ChallengeEngine] and the UI refuses anything that smells like max-out.
class CreateChallengeScreen extends ConsumerStatefulWidget {
  const CreateChallengeScreen({super.key});

  @override
  ConsumerState<CreateChallengeScreen> createState() =>
      _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends ConsumerState<CreateChallengeScreen> {
  FriendProfile? _friend;
  ChallengeType _type = ChallengeType.consistency;
  int _target = 3;
  int _days = 7;
  String? _exerciseId;
  String? _dayName;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final friends =
        ref.watch(friendsListProvider).value ?? const <FriendProfile>[];
    final me = ref.watch(authControllerProvider).value;
    final metric = _exerciseId == null
        ? ExerciseMetricLike.reps
        : (ExerciseLibrary.byId(_exerciseId!)?.metric.name == 'seconds'
              ? ExerciseMetricLike.seconds
              : ExerciseMetricLike.reps);
    final error = ChallengeEngine.validateTarget(
      type: _type,
      target: _target,
      metric: metric,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('New challenge')),
      body: friends.isEmpty
          ? const AppEmptyState(
              title: 'Need a training partner',
              message: 'Add a friend first — challenges are head to head.',
              icon: Icons.people_outline,
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text('Training partner', style: AppTypography.title),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final f in friends)
                      ChoiceChip(
                        label: Text('@${f.handle}'),
                        selected: _friend?.uid == f.uid,
                        onSelected: (_) => setState(() => _friend = f),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Type', style: AppTypography.title),
                const SizedBox(height: AppSpacing.sm),
                for (final t in ChallengeType.values)
                  RadioListTile<ChallengeType>(
                    value: t,
                    // ignore: deprecated_member_use
                    groupValue: _type,
                    // ignore: deprecated_member_use
                    onChanged: (v) => setState(() {
                      _type = v ?? _type;
                      _target = _defaultTarget(v ?? _type, metric);
                    }),
                    title: Text(t.label, style: AppTypography.body),
                    subtitle: Text(t.description, style: AppTypography.caption),
                    contentPadding: EdgeInsets.zero,
                  ),
                const SizedBox(height: AppSpacing.sm),
                if (_type.needsExercise)
                  _ExercisePicker(
                    selected: _exerciseId,
                    onSelected: (id) => setState(() {
                      _exerciseId = id;
                      final m = ExerciseLibrary.byId(id)?.metric.name;
                      _target = m == 'seconds' ? 30 : 20;
                    }),
                  ),
                if (_type == ChallengeType.workoutCompletion)
                  _DayNamePicker(
                    selected: _dayName,
                    onSelected: (n) => setState(() => _dayName = n),
                  ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Target', style: AppTypography.title),
                          Text(
                            '$_target ${_type.unit(metric)}',
                            style: AppTypography.body,
                          ),
                        ],
                      ),
                      Slider(
                        value: _target
                            .clamp(
                              1,
                              ChallengeEngine.maxTarget(_type, metric: metric),
                            )
                            .toDouble(),
                        min: 1,
                        max: ChallengeEngine.maxTarget(
                          _type,
                          metric: metric,
                        ).toDouble(),
                        onChanged: (v) => setState(() => _target = v.round()),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Period', style: AppTypography.title),
                          Text('$_days days', style: AppTypography.body),
                        ],
                      ),
                      Wrap(
                        spacing: AppSpacing.sm,
                        children: [
                          for (final d in ChallengeEngine.periodOptions)
                            ChoiceChip(
                              label: Text('$d d'),
                              selected: _days == d,
                              onSelected: (_) => setState(() => _days = d),
                            ),
                        ],
                      ),
                      if (error != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          error,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed:
                      _friend != null && me != null && error == null && !_saving
                      ? _submit
                      : null,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send challenge'),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Consistency over max effort — every target above is '
                  'capped to stay safe.',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
    );
  }

  int _defaultTarget(ChallengeType type, ExerciseMetricLike metric) =>
      switch (type) {
        ChallengeType.consistency => 3,
        ChallengeType.workoutCompletion => 1,
        ChallengeType.volume => 300,
        ChallengeType.progression => metric.isSeconds ? 60 : 25,
        ChallengeType.time => 90,
        ChallengeType.headToHead => 500,
      };

  Future<void> _submit() async {
    final me = ref.read(authControllerProvider).value;
    final friend = _friend;
    if (me == null || friend == null) return;
    setState(() => _saving = true);
    final now = DateTime.now().toUtc();
    final challenge = Challenge(
      id: 'ch_${DateTime.now().microsecondsSinceEpoch}',
      creatorUid: me.id,
      creatorHandle: me.displayLabel.toLowerCase(),
      opponentUid: friend.uid,
      opponentHandle: friend.handle,
      type: _type,
      target: _target,
      startsAt: now,
      endsAt: now.add(Duration(days: _days)),
      createdAt: now,
      exerciseId: _type.needsExercise ? _exerciseId : null,
      exerciseName: _exerciseId == null
          ? null
          : ExerciseLibrary.byId(_exerciseId!)?.name,
      dayName: _type == ChallengeType.workoutCompletion ? _dayName : null,
    );
    try {
      await ref.read(challengeRepositoryProvider).create(challenge);
      if (mounted) Navigator.of(context).pop();
    } on ChallengeException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _ExercisePicker extends StatelessWidget {
  const _ExercisePicker({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final exercises = ExerciseLibrary.all
        .where(
          (e) => !e.prerequisites.any((p) => ExerciseLibrary.byId(p) == null),
        )
        .take(24)
        .toList();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Exercise', style: AppTypography.title),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final e in exercises)
                ChoiceChip(
                  label: Text(e.name),
                  selected: selected == e.id,
                  onSelected: (_) => onSelected(e.id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayNamePicker extends StatelessWidget {
  const _DayNamePicker({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String> onSelected;

  static const _days = [
    'Push + Core',
    'Pull + Back',
    'Legs + Conditioning',
    'Full Body Circuit',
    'Active Recovery',
  ];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Program day', style: AppTypography.title),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final d in _days)
                ChoiceChip(
                  label: Text(d),
                  selected: selected == d,
                  onSelected: (_) => onSelected(d),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
