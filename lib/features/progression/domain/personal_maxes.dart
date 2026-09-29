import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_ids.dart';
import '../../workout_session/data/workout_history_repository.dart';
import '../../workout_session/domain/workout_session.dart';

part 'personal_maxes.g.dart';

/// The movements whose max matters for programming. Deliberately short: these
/// are the big five skills that decide how the plan is built.
enum MaxSkill {
  pushups('pushup-standard', 'Push-ups', MaxUnit.reps),
  pullups('pullup-standard', 'Pull-ups', MaxUnit.reps),
  dips('dips', 'Dips', MaxUnit.reps),
  squats('air-squat', 'Squats', MaxUnit.reps),
  plank('plank', 'Plank', MaxUnit.seconds);

  const MaxSkill(this.exerciseId, this.label, this.unit);
  final String exerciseId;
  final String label;
  final MaxUnit unit;
}

enum MaxUnit {
  reps('reps'),
  seconds('seconds');

  const MaxUnit(this.label);
  final String label;
}

/// A declared top set for one skill, e.g. "my best push-up set is 22".
class SkillMax {
  const SkillMax({required this.value, required this.updatedAt});
  final int value;
  final DateTime updatedAt;
}

/// The user's declared maxes, plus the honest reasoning helpers the program
/// engine will use later.
class PersonalMaxes {
  const PersonalMaxes(this._bySkill);
  final Map<MaxSkill, SkillMax> _bySkill;

  static const empty = PersonalMaxes({});

  int? valueFor(MaxSkill skill) => _bySkill[skill]?.value;

  SkillMax? entryFor(MaxSkill skill) => _bySkill[skill];

  int get declaredCount => _bySkill.length;

  bool get isEmpty => _bySkill.isEmpty;
  bool get isComplete => _bySkill.length == MaxSkill.values.length;

  /// Reps to target for a skill, as a fraction of the declared max.
  ///
  /// Falls back to a conservative absolute number when no max is declared, so
  /// the program still works before setup is finished — it never guesses high.
  int workingTarget(MaxSkill skill, double fraction) {
    final max = valueFor(skill);
    if (max == null || max <= 0) {
      return skill == MaxSkill.plank ? 30 : 8;
    }
    final raw = (max * fraction).round();
    return raw.clamp(1, max);
  }

  PersonalMaxes withValue(MaxSkill skill, int value, DateTime now) {
    final next = Map<MaxSkill, SkillMax>.from(_bySkill);
    if (value <= 0) {
      next.remove(skill);
    } else {
      next[skill] = SkillMax(value: value, updatedAt: now);
    }
    return PersonalMaxes(next);
  }

  Map<String, Object?> toStorage() => {
    for (final e in _bySkill.entries)
      e.key.name: {
        'value': e.value.value,
        'at': e.value.updatedAt.toIso8601String(),
      },
  };

  static PersonalMaxes fromStorage(Map<Object?, Object?> raw) {
    final out = <MaxSkill, SkillMax>{};
    for (final skill in MaxSkill.values) {
      final v = raw[skill.name];
      if (v is Map) {
        final value = v['value'];
        final at = v['at'];
        if (value is int && value > 0) {
          out[skill] = SkillMax(
            value: value,
            updatedAt:
                DateTime.tryParse(at is String ? at : '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
          );
        }
      }
    }
    return PersonalMaxes(out);
  }
}

@Riverpod(keepAlive: true)
class PersonalMaxesController extends _$PersonalMaxesController {
  static const _key = '${AppIds.prefPrefix}personal.maxes.v1';

  @override
  Future<PersonalMaxes> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return PersonalMaxes.empty;
    try {
      return PersonalMaxes.fromStorage(
        (jsonDecode(raw) as Map).cast<Object?, Object?>(),
      );
    } catch (_) {
      // Corrupt data must never block training.
      return PersonalMaxes.empty;
    }
  }

  void set(MaxSkill skill, int value) {
    final current = state.value ?? PersonalMaxes.empty;
    final next = current.withValue(skill, value, DateTime.now().toUtc());
    state = AsyncData(next);
    SharedPreferences.getInstance()
        .then((p) => p.setString(_key, jsonEncode(next.toStorage())))
        .ignore();
  }

  /// Fills every skill that has evidence in history and is not declared yet.
  void seedFromHistory(Map<MaxSkill, int> detected) {
    var current = state.value ?? PersonalMaxes.empty;
    final now = DateTime.now().toUtc();
    var changed = false;
    for (final entry in detected.entries) {
      if (current.valueFor(entry.key) != null) continue;
      current = current.withValue(entry.key, entry.value, now);
      changed = true;
    }
    if (!changed) return;
    state = AsyncData(current);
    SharedPreferences.getInstance()
        .then((p) => p.setString(_key, jsonEncode(current.toStorage())))
        .ignore();
  }

  void clearAll() {
    state = const AsyncData(PersonalMaxes.empty);
    SharedPreferences.getInstance().then((p) => p.remove(_key)).ignore();
  }
}

/// Best set per skill found in real history — the zero-effort starting point
/// for the maxes screen. Evidence beats typing numbers.
@Riverpod(keepAlive: true)
Map<MaxSkill, int> historyMaxes(Ref ref) {
  final history =
      ref.watch(workoutHistoryRepositoryProvider).value ??
      const <WorkoutSession>[];
  final best = <MaxSkill, int>{};
  for (final session in history) {
    for (final set in session.sets) {
      if (set.skipped || !set.countsTowardRecords) continue;
      for (final skill in MaxSkill.values) {
        if (set.exerciseId != skill.exerciseId) continue;
        final v = skill.unit == MaxUnit.seconds
            ? (set.seconds ?? 0)
            : (set.reps ?? 0);
        if (v > (best[skill] ?? 0)) best[skill] = v;
      }
    }
  }
  return best;
}
