import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../data/quick_log_providers.dart';
import '../domain/exercise.dart';
import '../domain/exercise_enums.dart';

/// "I did this movement, count it."
///
/// Logs one or more sets of a library exercise through the normal history
/// pipeline, so it shows up in stats, PRs, XP, streaks and achievements like
/// any other training.
class QuickLogCard extends ConsumerStatefulWidget {
  const QuickLogCard({required this.exercise, super.key});

  final Exercise exercise;

  @override
  ConsumerState<QuickLogCard> createState() => _QuickLogCardState();
}

class _QuickLogCardState extends ConsumerState<QuickLogCard> {
  final _reps = TextEditingController(text: '10');
  final _sets = TextEditingController(text: '3');
  bool _saving = false;

  @override
  void dispose() {
    _reps.dispose();
    _sets.dispose();
    super.dispose();
  }

  bool get _timed => widget.exercise.metric == ExerciseMetric.time;

  String get _unit => _timed ? 'seconds' : 'reps';

  Future<void> _save() async {
    final perSet = int.tryParse(_reps.text.trim()) ?? 0;
    final setCount = int.tryParse(_sets.text.trim()) ?? 0;
    if (perSet <= 0 || setCount <= 0) {
      _toast('Enter how many $_unit you did and how many sets.');
      return;
    }
    setState(() => _saving = true);
    final ok = await ref
        .read(quickLogControllerProvider.notifier)
        .log(
          exercise: widget.exercise,
          values: List.filled(setCount.clamp(1, 20), perSet),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      await ref.read(recentQuickLogsProvider.notifier).remember(widget.exercise.id);
      if (!mounted) return;
      _toast(
        'Logged $setCount x $perSet $_unit — added to your progress.',
      );
    } else {
      _toast('Nothing to log yet.');
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Did this today?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Log it here and it counts toward your stats, records and streak.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _MiniField(
                    controller: _sets,
                    label: 'Sets',
                    digitsOnly: true,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: _MiniField(
                    controller: _reps,
                    label: _unit,
                    digitsOnly: true,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Log it'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniField extends StatelessWidget {
  const _MiniField({
    required this.controller,
    required this.label,
    this.digitsOnly = false,
  });

  final TextEditingController controller;
  final String label;
  final bool digitsOnly;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: digitsOnly ? TextInputType.number : TextInputType.text,
      inputFormatters: digitsOnly
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
        counterText: '',
      ),
    );
  }
}
