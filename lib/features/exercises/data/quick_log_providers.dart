import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_ids.dart';
import '../../exercises/domain/exercise.dart';
import '../../exercises/domain/exercise_enums.dart';
import '../../workout_session/data/workout_history_repository.dart';
import '../../workout_session/domain/set_entry.dart';
import '../../workout_session/domain/workout_session.dart';

part 'quick_log_providers.g.dart';

/// Logs a set of a single exercise straight from the library.
///
/// He asked for this plainly: pick a movement in the library, do it, and have
/// it counted. It builds a real one-exercise [WorkoutSession] and pushes it
/// through the same history pipeline a program workout uses — so sets, PRs,
/// XP, streaks, level and achievements all see it. Nothing is a "fake" entry
/// kept on the side.
@Riverpod(keepAlive: true)
class QuickLogController extends _$QuickLogController {
  @override
  void build() {}

  /// Records [sets] of [exercise] as a completed workout.
  ///
  /// [values] is reps for rep-based movements and seconds for timed ones; it
  /// decides automatically from the exercise so the caller cannot mislabel a
  /// plank as 3 reps.
  Future<bool> log({
    required Exercise exercise,
    required List<int> values,
    int? assistedReps,
    String? note,
  }) async {
    final clean = values.where((v) => v > 0).toList();
    if (clean.isEmpty) return false;

    final isTimed = exercise.metric == ExerciseMetric.time;
    final now = DateTime.now();
    final stamp = now.millisecondsSinceEpoch;

    final entries = <SetEntry>[
      for (var i = 0; i < clean.length; i++)
        SetEntry(
          id: 'ql_${exercise.id}_${stamp}_$i',
          exerciseId: exercise.id,
          setNumber: i + 1,
          reps: isTimed ? null : clean[i],
          seconds: isTimed ? clean[i] : null,
          assistedReps: isTimed ? 0 : (assistedReps ?? 0),
          note: note,
          completedAt: now.toUtc(),
        ),
    ];

    final session = WorkoutSession(
      id: 'ql_${exercise.id}_$stamp',
      programId: QuickLogController.quickLogProgramId,
      dayName: exercise.name,
      dayNumber: 1,
      startedAt: now.toUtc(),
      endedAt: now.toUtc(),
      phase: WorkoutPhase.finished,
      exercises: [
        SessionExercise(
          exerciseId: exercise.id,
          name: exercise.name,
          sets: entries.length,
        ),
      ],
      sets: entries,
    );

    await ref.read(workoutHistoryRepositoryProvider.notifier).add(session);
    return true;
  }

  /// Distinguishes logged work from program work in history.
  static const quickLogProgramId = 'quick-log';
}

/// He wants this, so it goes in the launch list: the last exercises he logged,
/// ready to repeat.
@Riverpod(keepAlive: true)
class RecentQuickLogs extends _$RecentQuickLogs {
  static const _key = '${AppIds.prefPrefix}quicklog.recent.v1';
  static const _maxEntries = 12;

  @override
  Future<List<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? const [];
  }

  Future<void> remember(String exerciseId) async {
    final current = state.value ?? const <String>[];
    final next = [
      exerciseId,
      ...current.where((id) => id != exerciseId),
    ].take(_maxEntries).toList();
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, next);
  }
}
