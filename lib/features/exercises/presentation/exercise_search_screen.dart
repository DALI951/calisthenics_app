import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../data/exercise_favorites.dart';
import '../data/exercise_library.dart';
import '../domain/exercise.dart';
import '../domain/exercise_enums.dart';
import 'exercise_detail_screen.dart';

/// Searchable exercise library (spec §41, §63): name / category / difficulty /
/// equipment / muscle group / favorites / recently used.
class ExerciseSearchScreen extends ConsumerStatefulWidget {
  const ExerciseSearchScreen({super.key});

  @override
  ConsumerState<ExerciseSearchScreen> createState() =>
      _ExerciseSearchScreenState();
}

class _ExerciseSearchScreenState extends ConsumerState<ExerciseSearchScreen> {
  final _query = TextEditingController();
  ExerciseCategory? _category;
  ExerciseDifficulty? _difficulty;
  Equipment? _equipment;
  MuscleGroup? _muscle;
  bool _onlyFavorites = false;
  bool _showFilters = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<Exercise> _filter(List<Exercise> all) {
    final q = _query.text.trim().toLowerCase();
    return all.where((e) {
      if (q.isNotEmpty) {
        final haystack = [
          e.name,
          e.category.label,
          e.difficulty.label,
          e.metric.label,
          e.primaryMuscle,
          ...e.muscleGroups.map((m) => m.label),
          ...e.equipment.map((eq) => eq.label),
          ...e.tags.map((t) => t.label),
        ].join(' ').toLowerCase();
        if (!haystack.contains(q)) return false;
      }
      if (_category != null && e.category != _category) return false;
      if (_difficulty != null && e.difficulty != _difficulty) return false;
      if (_equipment != null && !e.equipment.contains(_equipment)) return false;
      if (_muscle != null && !e.muscleGroups.contains(_muscle)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final all = ExerciseLibrary.all;
    final favorites =
        ref.watch(exerciseFavoritesProvider).value ?? const <String>{};

    final scoped = _onlyFavorites
        ? all.where((e) => favorites.contains(e.id)).toList()
        : all;
    final results = _filter(scoped);

    return Scaffold(
      appBar: AppBar(title: const Text('Exercise library')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search exercises, muscles, equipment…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.text.isEmpty
                    ? IconButton(
                        tooltip: 'Filters',
                        icon: Icon(
                          _showFilters
                              ? Icons.filter_alt_off
                              : Icons.filter_alt,
                        ),
                        onPressed: () =>
                            setState(() => _showFilters = !_showFilters),
                      )
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _query.clear();
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
          if (_showFilters)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                children: [
                  _FilterRow<ExerciseCategory>(
                    values: ExerciseCategory.values,
                    selected: _category,
                    label: (v) => v.label,
                    onSelected: (v) => setState(() => _category = v),
                    onClear: () => setState(() => _category = null),
                  ),
                  _FilterRow<ExerciseDifficulty>(
                    values: ExerciseDifficulty.values,
                    selected: _difficulty,
                    label: (v) => v.label,
                    onSelected: (v) => setState(() => _difficulty = v),
                    onClear: () => setState(() => _difficulty = null),
                  ),
                  _FilterRow<Equipment>(
                    values: Equipment.values,
                    selected: _equipment,
                    label: (v) => v.label,
                    onSelected: (v) => setState(() => _equipment = v),
                    onClear: () => setState(() => _equipment = null),
                  ),
                  _FilterRow<MuscleGroup>(
                    values: MuscleGroup.values,
                    selected: _muscle,
                    label: (v) => v.label,
                    onSelected: (v) => setState(() => _muscle = v),
                    onClear: () => setState(() => _muscle = null),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Switch(
                          value: _onlyFavorites,
                          onChanged: (on) =>
                              setState(() => _onlyFavorites = on),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text('Favorites only', style: AppTypography.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: results.isEmpty
                ? const AppEmptyState(
                    icon: Icons.search_off,
                    title: 'No exercises match',
                    message: 'Try clearing a filter, or search for another movement.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: results.length,
                    itemBuilder: (context, i) {
                      final e = results[i];
                      final isFav = favorites.contains(e.id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: ExerciseCard(
                          exercise: e,
                          favorite: isFav,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ExerciseDetailScreen(exerciseId: e.id),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterRow<T> extends StatelessWidget {
  const _FilterRow({
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
    required this.onClear,
  });

  final List<T> values;
  final T? selected;
  final String Function(T) label;
  final ValueChanged<T> onSelected;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final v in values) ...[
              FilterChip(
                label: Text(label(v)),
                selected: selected == v,
                onSelected: (_) => onSelected(v),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            if (selected != null)
              TextButton(onPressed: onClear, child: const Text('Clear')),
          ],
        ),
      ),
    );
  }
}

/// Reusable exercise list item — library, search results, quick start.
class ExerciseCard extends StatelessWidget {
  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.onTap,
    this.favorite = false,
  });

  final Exercise exercise;
  final VoidCallback onTap;

  /// The caller decides whether to show a filled heart (favorites context).
  final bool favorite;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _iconFor(exercise.category),
              color: secondary,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exercise.name, style: AppTypography.body),
                const SizedBox(height: 2),
                Text(
                  '${exercise.category.label} • ${exercise.difficulty.label}'
                  '${exercise.primaryMuscle.isEmpty ? '' : ' • ${exercise.primaryMuscle}'}',
                  style: AppTypography.caption.apply(color: secondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (favorite)
            const Icon(Icons.favorite, size: 16, color: Color(0xFFDC2626)),
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.chevron_right, size: 20, color: Color(0x66FFFFFF)),
        ],
      ),
    );
  }

  IconData _iconFor(ExerciseCategory c) {
    switch (c) {
      case ExerciseCategory.push:
        return Icons.fitness_center;
      case ExerciseCategory.pull:
        return Icons.arrow_upward;
      case ExerciseCategory.legs:
        return Icons.directions_walk;
      case ExerciseCategory.core:
        return Icons.accessibility_new;
    }
  }
}
