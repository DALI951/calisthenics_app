import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_card.dart';
import '../../exercises/data/exercise_library.dart';
import '../../exercises/domain/exercise.dart';
import '../../exercises/domain/exercise_enums.dart';
import '../data/active_program_controller.dart';
import '../domain/workout_program.dart';
import '../data/program_registry.dart';

/// Edit one day in full: its name, and every exercise with sets, rep range and
/// rest. Anything the built-in program had, you can change or delete here.
class DayEditorScreen extends ConsumerStatefulWidget {
  const DayEditorScreen({super.key, required this.dayNumber});

  final int dayNumber;

  @override
  ConsumerState<DayEditorScreen> createState() => _DayEditorScreenState();
}

class _DayEditorScreenState extends ConsumerState<DayEditorScreen> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final program =
        ref.watch(activeProgramControllerProvider).value ??
        ProgramRegistry.blank;
    final day = program.days.firstWhere(
      (d) => d.dayNumber == widget.dayNumber,
      orElse: () => program.days.first,
    );
    final ctrl = ref.read(activeProgramControllerProvider.notifier);
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final isRest = day.type == ProgramDayType.rest;

    if (_name.text != day.name && !_name.value.composing.isValid) {
      _name.text = day.name;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Day ${day.dayNumber}'),
        actions: [
          TextButton(
            onPressed: () {
              ctrl.renameDay(day.dayNumber, _name.text);
              FocusScope.of(context).unfocus();
            },
            child: const Text('Save name'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        children: [
          AppCard(
            child: TextField(
              controller: _name,
              textInputAction: TextInputAction.done,
              onSubmitted: (v) => ctrl.renameDay(day.dayNumber, v),
              style: AppTypography.body,
              decoration: InputDecoration(
                labelText: 'Day name',
                helperText: 'e.g. Push + Core, Legs, Upper',
                helperStyle: AppTypography.caption.apply(color: secondary),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Row(
            children: [
              Expanded(
                child: AppPrimaryButton(
                  label: isRest ? 'Make it a workout' : 'Make it a rest day',
                  icon: isRest ? Icons.fitness_center : Icons.self_improvement,
                  onPressed: () => ctrl.setDayType(
                    day.dayNumber,
                    isRest ? ProgramDayType.training : ProgramDayType.rest,
                  ),
                ),
              ),
            ],
          ),

          if (isRest) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              'This day is a rest day. Switch it to a workout to add exercises.',
              style: AppTypography.bodySmall.apply(color: secondary),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Text('Exercises', style: AppTypography.label),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _addExercise(context, day),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            if (day.exercises.isEmpty)
              AppCard(
                child: Text(
                  'Nothing in this day yet. Add the first exercise.',
                  style: AppTypography.bodySmall.apply(color: secondary),
                ),
              )
            else
              for (final planned in day.exercises) ...[
                _ExerciseRow(
                  planned: planned,
                  onChange: (next) => ctrl.updateDay(
                    day.dayNumber,
                    (d) => d.copyWith(
                      exercises: [
                        for (final e in d.exercises)
                          if (e.exerciseId == planned.exerciseId) next else e,
                      ],
                    ),
                  ),
                  onDelete: () => ctrl.updateDay(
                    day.dayNumber,
                    (d) => d.copyWith(
                      exercises: d.exercises
                          .where((e) => e.exerciseId != planned.exerciseId)
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
          ],
        ],
      ),
    );
  }

  Future<void> _addExercise(BuildContext context, ProgramDay day) async {
    final picked = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => const _ExercisePickerSheet(),
    );
    if (picked == null || !mounted) return;
    final ctrl = ref.read(activeProgramControllerProvider.notifier);
    ctrl.updateDay(widget.dayNumber, (d) {
      // Adding the same movement twice would double-count it in the session.
      if (d.exercises.any((e) => e.exerciseId == picked.id)) return d;
      final timed = picked.metric == ExerciseMetric.time;
      return d.copyWith(
        exercises: [
          ...d.exercises,
          PlannedExercise(
            exerciseId: picked.id,
            sets: 3,
            targetMin: timed ? null : 5,
            targetMax: timed ? null : 10,
            targetSecondsMin: timed ? 20 : null,
            targetSecondsMax: timed ? 40 : null,
            restSeconds: timed ? 60 : 90,
          ),
        ],
      );
    });
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.planned,
    required this.onChange,
    required this.onDelete,
  });

  final PlannedExercise planned;
  final ValueChanged<PlannedExercise> onChange;
  final VoidCallback onDelete;

  String get _name {
    for (final e in ExerciseLibrary.all) {
      if (e.id == planned.exerciseId) return e.name;
    }
    return planned.exerciseId;
  }

  bool get _timed =>
      planned.targetSecondsMax != null || planned.targetSecondsMin != null;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(_name, style: AppTypography.body)),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 20),
                color: AppColors.textSecondary,
                visualDensity: VisualDensity.compact,
                tooltip: 'Remove',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              _Stepper(
                label: 'Sets',
                value: planned.sets,
                onChanged: (v) =>
                    onChange(planned.copyWith(sets: v.clamp(1, 20))),
              ),
              if (!_timed) ...[
                _Stepper(
                  label: 'Min reps',
                  value: planned.targetMin ?? 0,
                  onChanged: (v) => onChange(planned.copyWith(targetMin: v)),
                ),
                _Stepper(
                  label: 'Max reps',
                  value: planned.targetMax ?? 0,
                  onChanged: (v) => onChange(planned.copyWith(targetMax: v)),
                ),
              ] else ...[
                _Stepper(
                  label: 'Min sec',
                  value: planned.targetSecondsMin ?? 0,
                  onChanged: (v) =>
                      onChange(planned.copyWith(targetSecondsMin: v)),
                ),
                _Stepper(
                  label: 'Max sec',
                  value: planned.targetSecondsMax ?? 0,
                  onChanged: (v) =>
                      onChange(planned.copyWith(targetSecondsMax: v)),
                ),
              ],
              _Stepper(
                label: 'Rest sec',
                value: planned.restSeconds,
                step: 15,
                onChanged: (v) =>
                    onChange(planned.copyWith(restSeconds: v.clamp(0, 600))),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _timed ? 'Timed hold' : 'Rep target',
            style: AppTypography.caption.apply(color: secondary),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.onChanged,
    this.step = 1,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int step;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: AppTypography.caption.apply(color: secondary)),
        IconButton(
          onPressed: () => onChanged(value - step),
          icon: const Icon(Icons.remove, size: 16),
          color: AppColors.textSecondary,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          padding: EdgeInsets.zero,
        ),
        SizedBox(
          width: 34,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: AppTypography.body,
          ),
        ),
        IconButton(
          onPressed: () => onChanged(value + step),
          icon: const Icon(Icons.add, size: 16),
          color: AppColors.accent,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }
}

/// Every movement in the library, searchable.
class _ExercisePickerSheet extends StatefulWidget {
  const _ExercisePickerSheet();

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final items = ExerciseLibrary.all
        .where(
          (e) =>
              _query.isEmpty ||
              e.name.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add an exercise', style: AppTypography.title),
            const SizedBox(height: AppSpacing.md),
            TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              style: AppTypography.body,
              decoration: const InputDecoration(
                hintText: 'Search movements',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final e in items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(e.name, style: AppTypography.body),
                      subtitle: Text(
                        e.metric == ExerciseMetric.time ? 'Timed' : 'Reps',
                        style: AppTypography.caption.apply(color: secondary),
                      ),
                      onTap: () => Navigator.of(context).pop(e),
                    ),
                  if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.lg,
                      ),
                      child: Text(
                        'No movement matches that.',
                        style: AppTypography.bodySmall.apply(color: secondary),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
