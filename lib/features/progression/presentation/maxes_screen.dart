import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../domain/personal_maxes.dart';

/// Set your top set per skill. This is the input the program scales against:
/// working sets are prescribed as a share of these numbers, so the plan gets
/// harder as you do, instead of asking a beginner to do 20 reps on day one.
class MaxesScreen extends ConsumerWidget {
  const MaxesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maxes =
        ref.watch(personalMaxesControllerProvider).value ?? PersonalMaxes.empty;
    final detected = ref.watch(historyMaxesProvider);
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;

    // Offer a one-tap fill from real history: typing numbers is work, and
    // history is already evidence.
    final seedable = detected.entries
        .where((e) => maxes.valueFor(e.key) == null && e.value > 0)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('My maxes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        children: [
          Text(
            'Your best set for each movement. Sets in your program are built '
            'from these, and they grow as you get stronger.',
            style: AppTypography.bodySmall.apply(color: secondary),
          ),
          const SizedBox(height: AppSpacing.lg),

          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < MaxSkill.values.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.hairline,
                      indent: AppSpacing.lg,
                    ),
                  _MaxRow(
                    skill: MaxSkill.values[i],
                    value: maxes.valueFor(MaxSkill.values[i]) ?? 0,
                    detected: detected[MaxSkill.values[i]],
                    onChanged: (v) => ref
                        .read(personalMaxesControllerProvider.notifier)
                        .set(MaxSkill.values[i], v),
                  ),
                ],
              ],
            ),
          ),

          if (seedable.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_outlined,
                    size: 20,
                    color: AppColors.accentLight,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Found ${seedable.length} best '
                      '${seedable.length == 1 ? 'set' : 'sets'} in your history.',
                      style: AppTypography.bodySmall.apply(color: secondary),
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref
                        .read(personalMaxesControllerProvider.notifier)
                        .seedFromHistory(detected),
                    child: const Text('Use them'),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xl),
          AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.trending_up,
                  size: 20,
                  color: AppColors.success,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Update these whenever you beat them. The program targets a '
                    'share of your max (for example 70% for hard sets), so '
                    'raising a max automatically makes your sessions heavier.',
                    style: AppTypography.bodySmall.apply(color: secondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (maxes.declaredCount > 0)
            Center(
              child: TextButton(
                onPressed: () => ref
                    .read(personalMaxesControllerProvider.notifier)
                    .clearAll(),
                child: Text(
                  'Clear all maxes',
                  style: AppTypography.bodySmall.apply(color: AppColors.danger),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One skill: label, the number, and quiet -/+ controls. No keyboard needed —
/// a number field invites typos, and 5 taps is faster than typing.
class _MaxRow extends StatelessWidget {
  const _MaxRow({
    required this.skill,
    required this.value,
    required this.detected,
    required this.onChanged,
  });

  final MaxSkill skill;
  final int value;
  final int? detected;
  final ValueChanged<int> onChanged;

  int get _step => skill.unit == MaxUnit.seconds ? 5 : 1;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final unit = skill.unit == MaxUnit.seconds ? 'sec' : 'reps';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(skill.label, style: AppTypography.body),
                if (detected != null && detected != value)
                  Text(
                    'Best in history: $detected',
                    style: AppTypography.caption.apply(color: secondary),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: value <= 0
                ? null
                : () => onChanged((value - _step).clamp(0, 9999)),
            icon: const Icon(Icons.remove_circle_outline, size: 22),
            color: AppColors.textSecondary,
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 68,
            child: Text(
              value == 0 ? '—' : '$value',
              textAlign: TextAlign.center,
              style: AppTypography.title.copyWith(
                color: value == 0
                    ? AppColors.textDisabled
                    : AppColors.textPrimary,
              ),
            ),
          ),
          Text(unit, style: AppTypography.caption.apply(color: secondary)),
          IconButton(
            onPressed: () => onChanged(value + _step),
            icon: const Icon(Icons.add_circle_outline, size: 22),
            color: AppColors.accent,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
