import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../exercises/data/exercise_library.dart';
import '../../exercises/domain/exercise.dart';
import '../../exercises/domain/exercise_enums.dart';
import '../data/session_starter.dart';
import '../domain/workout_program.dart';

/// One movement added to tonight's session, with the numbers he typed.
class _Planned {
  _Planned(this.exercise) : sets = 3, reps = 8;

  final Exercise exercise;
  int sets;
  int reps;
  int? seconds;

  bool get isTimed => exercise.metric == ExerciseMetric.time;

  PlannedExercise toPlanned() => PlannedExercise(
        exerciseId: exercise.id,
        sets: sets,
        targetMin: isTimed ? null : reps,
        targetMax: isTimed ? null : reps,
        targetSecondsMin: isTimed ? seconds ?? 30 : null,
        targetSecondsMax: isTimed ? seconds ?? 30 : null,
        restSeconds: exercise.recommendedRestSeconds,
      );
}

/// Builds the plan for one training session, right before training it.
///
/// He asked for exactly this: no preset split, no waiting for "Push day" to
/// come round. Pick what you are doing tonight, set the numbers, start. The
/// session is a real session — the progression engine still scales it against
/// his declared maxes, and it lands in history like any other workout.
class SessionBuilderScreen extends ConsumerStatefulWidget {
  const SessionBuilderScreen({super.key});

  @override
  ConsumerState<SessionBuilderScreen> createState() =>
      _SessionBuilderScreenState();
}

class _SessionBuilderScreenState extends ConsumerState<SessionBuilderScreen> {
  final _picked = <_Planned>[];
  bool _starting = false;

  void _add(Exercise exercise) {
    setState(() {
      _picked.add(_Planned(exercise));
    });
  }

  void _removeAt(int index) {
    setState(() => _picked.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final totalSets =
        _picked.fold<int>(0, (sum, p) => sum + p.sets);

    return Scaffold(
      appBar: AppBar(title: const Text("Tonight's session")),
      body: _picked.isEmpty
          ? AppEmptyState(
              icon: Icons.edit_note_outlined,
              title: 'Nothing picked yet',
              message:
                  'Add the movements you are training today. You decide the '
                  'sets and reps.',
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(
                  '${_picked.length} movement${_picked.length == 1 ? '' : 's'} '
                  '· $totalSets sets',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (var i = 0; i < _picked.length; i++)
                  _PlanRow(
                    key: ValueKey(_picked[i].exercise.id),
                    planned: _picked[i],
                    onRemove: () => _removeAt(i),
                    onChanged: () => setState(() {}),
                  ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showModalBottomSheet<Exercise>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const _ExercisePickerSheet(),
                    );
                    if (picked != null) _add(picked);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add a movement'),
                ),
              ],
            ),
      bottomNavigationBar: _picked.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _starting ? null : () => _start(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                    ),
                    child: _starting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Start workout'),
                  ),
                ),
              ),
            ),
    );
  }

  /// Hands the built plan to the session controller as a real one-off day.
  Future<void> _start() async {
    setState(() => _starting = true);
    final built = buildSessionDay(_picked.map((p) => p.toPlanned()).toList());
    await SessionStarter().startBuilt(context, built);
    if (mounted) setState(() => _starting = false);
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.planned,
    required this.onRemove,
    required this.onChanged,
    super.key,
  });

  final _Planned planned;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    planned.exercise.name,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    planned.isTimed ? 'Timed hold' : 'Reps',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            _Stepper(
              value: planned.sets,
              onChanged: (v) {
                planned.sets = v.clamp(1, 20);
                onChanged();
              },
            ),
            const SizedBox(width: AppSpacing.sm),
            _Stepper(
              value: planned.isTimed ? (planned.seconds ?? 30) : planned.reps,
              onChanged: (v) {
                final value = v.clamp(1, planned.isTimed ? 600 : 200);
                if (planned.isTimed) {
                  planned.seconds = value;
                } else {
                  planned.reps = value;
                }
                onChanged();
              },
            ),
            IconButton(
              tooltip: 'Remove',
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => onChanged(value - 1),
            icon: const Icon(Icons.remove, size: 18),
          ),
          Text('$value', style: Theme.of(context).textTheme.titleSmall),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => onChanged(value + 1),
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
    );
  }
}

class _ExercisePickerSheet extends ConsumerStatefulWidget {
  const _ExercisePickerSheet();

  @override
  ConsumerState<_ExercisePickerSheet> createState() =>
      _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends ConsumerState<_ExercisePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final results = q.isEmpty
        ? ExerciseLibrary.all
        : ExerciseLibrary.all
            .where((e) => e.name.toLowerCase().contains(q))
            .toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search movements',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: controller,
              itemCount: results.length,
              itemBuilder: (context, i) {
                final e = results[i];
                return ListTile(
                  title: Text(e.name),
                  subtitle: Text(
                    '${e.category.label} · ${e.metric.label.toLowerCase()}',
                  ),
                  trailing: const Icon(Icons.add_circle_outline),
                  onTap: () => Navigator.of(context).pop(e),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

