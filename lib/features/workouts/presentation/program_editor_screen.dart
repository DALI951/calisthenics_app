import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_card.dart';
import '../data/active_program_controller.dart';
import '../data/program_registry.dart';
import '../domain/workout_program.dart';

/// Edit the week: swap any two days, move a day, flip it to rest or back to
/// training, and change what each day actually contains.
class ProgramEditorScreen extends ConsumerWidget {
  const ProgramEditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final program =
        ref.watch(activeProgramControllerProvider).value ??
        ProgramRegistry.beginner;
    final ctrl = ref.read(activeProgramControllerProvider.notifier);
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;

    final ordered = [...program.days]
      ..sort((a, b) => a.dayNumber.compareTo(b.dayNumber));

    return Scaffold(
      appBar: AppBar(title: const Text('Edit my week')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        children: [
          Text(
            'Drag nothing, tap nothing you cannot undo. Every change here is '
            'yours, and "Reset to default" always brings the original back.',
            style: AppTypography.bodySmall.apply(color: secondary),
          ),
          const SizedBox(height: AppSpacing.lg),

          for (final day in ordered) ...[
            _DayCard(
              day: day,
              isFirst: day.dayNumber == 1,
              isLast: day.dayNumber == ordered.length,
              onMove: (offset) => ctrl.moveDay(day.dayNumber, offset),
              onToggleRest: () => ctrl.setDayType(
                day.dayNumber,
                day.type == ProgramDayType.rest
                    ? ProgramDayType.training
                    : ProgramDayType.rest,
              ),
              onEdit: () => _editDay(context, day),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          const SizedBox(height: AppSpacing.md),
          AppSecondaryButton(
            label: 'Reset to the original program',
            onPressed: () => ctrl.resetToDefault(),
          ),
        ],
      ),
    );
  }

  void _editDay(BuildContext context, ProgramDay day) {
    context.push('/app/workouts/edit/day/${day.dayNumber}');
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.isFirst,
    required this.isLast,
    required this.onMove,
    required this.onToggleRest,
    required this.onEdit,
  });

  final ProgramDay day;
  final bool isFirst;
  final bool isLast;
  final ValueChanged<int> onMove;
  final VoidCallback onToggleRest;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final isRest = day.type == ProgramDayType.rest;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isRest
                      ? AppColors.surfaceRaised
                      : AppColors.accentGlow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${day.dayNumber}',
                  style: AppTypography.label.copyWith(
                    color: isRest
                        ? AppColors.textSecondary
                        : AppColors.accentLight,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  day.name,
                  style: AppTypography.body.copyWith(
                    color: isRest ? AppColors.textSecondary : null,
                  ),
                ),
              ),
              // Quiet reordering: two taps, no drag handle to miss.
              IconButton(
                onPressed: isFirst ? null : () => onMove(-1),
                icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                color: AppColors.textSecondary,
                visualDensity: VisualDensity.compact,
                tooltip: 'Move earlier',
              ),
              IconButton(
                onPressed: isLast ? null : () => onMove(1),
                icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                color: AppColors.textSecondary,
                visualDensity: VisualDensity.compact,
                tooltip: 'Move later',
              ),
            ],
          ),
          if (isRest)
            Padding(
              padding: const EdgeInsets.only(left: 40, top: AppSpacing.xs),
              child: Text(
                'Rest day',
                style: AppTypography.caption.apply(color: secondary),
              ),
            )
          else ...[
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Text(
                day.exercises.isEmpty
                    ? 'No exercises yet — tap Edit to add some'
                    : day.exercises.map((e) => e.exerciseId).join(' · '),
                style: AppTypography.caption.apply(color: secondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.tune, size: 16),
                label: Text(isRest ? 'Make it a workout' : 'Edit day'),
                style: TextButton.styleFrom(
                  foregroundColor: isRest
                      ? AppColors.textSecondary
                      : AppColors.accentLight,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onToggleRest,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  isRest ? 'Set as training' : 'Set as rest',
                  style: AppTypography.bodySmall.apply(
                    color: isRest
                        ? AppColors.accentLight
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
