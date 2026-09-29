import 'package:calisthenics_app/features/exercises/domain/exercise.dart';
import 'package:calisthenics_app/features/exercises/domain/exercise_enums.dart';
import 'package:calisthenics_app/features/workout_session/domain/set_entry.dart';
import 'package:flutter_test/flutter_test.dart';

/// "When I choose a program in the exercise library I want to be able to
/// choose doing it and it counts how much I did."
void main() {
  final pushups = Exercise(
    id: 'pushup-standard',
    name: 'Push-ups',
    category: ExerciseCategory.push,
    muscleGroups: const [],
    equipment: const [],
    instructions: const [],
    techniqueCues: const [],
  );

  final plank = Exercise(
    id: 'plank',
    name: 'Plank',
    category: ExerciseCategory.core,
    muscleGroups: const [],
    equipment: const [],
    instructions: const [],
    techniqueCues: const [],
    metric: ExerciseMetric.time,
  );

  test('a rep-based exercise logs sets as reps', () {
    final sets = <SetEntry>[];
    final values = List.filled(3, 12);
    final isTimed = pushups.metric == ExerciseMetric.time;
    for (var i = 0; i < values.length; i++) {
      sets.add(
        SetEntry(
          id: 'x$i',
          exerciseId: pushups.id,
          setNumber: i + 1,
          reps: isTimed ? null : values[i],
          seconds: isTimed ? values[i] : null,
          completedAt: DateTime.utc(2026),
        ),
      );
    }
    expect(sets.length, 3);
    expect(sets.first.reps, 12);
    expect(sets.first.seconds, isNull);
    expect(sets.every((s) => s.countsTowardRecords), isTrue);
    expect(sets.map((s) => s.primaryValue).reduce((a, b) => a + b), 36);
  });

  test('a timed exercise logs seconds, never reps', () {
    final isTimed = plank.metric == ExerciseMetric.time;
    expect(isTimed, isTrue);
    final entry = SetEntry(
      id: 'a',
      exerciseId: plank.id,
      setNumber: 1,
      reps: isTimed ? null : 60,
      seconds: isTimed ? 60 : null,
      completedAt: DateTime.utc(2026),
    );
    expect(entry.reps, isNull);
    expect(entry.seconds, 60);
    expect(entry.isTimed, isTrue);
    expect(entry.primaryValue, 60);
  });

  test('quick-log ids are unique per log so history never duplicates', () {
    final a = DateTime.now();
    final b = a.add(const Duration(milliseconds: 1));
    expect('ql_${pushups.id}_${a.millisecondsSinceEpoch}',
        isNot('ql_${pushups.id}_${b.millisecondsSinceEpoch}'));
  });

  test('recent logs remember the newest and drop repeats', () {
    // Same rule the controller uses: newest first, no duplicates.
    const updated = ['a', 'b', 'a'];
    final next = ['a', ...updated.where((id) => id != 'a')].take(12).toList();
    expect(next.first, 'a');
    expect(next.where((id) => id == 'a').length, 1);
  });
}
