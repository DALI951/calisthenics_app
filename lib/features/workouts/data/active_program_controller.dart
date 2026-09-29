import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_ids.dart';
import '../domain/workout_program.dart';
import 'program_registry.dart';

part 'active_program_controller.g.dart';

/// The user's editable week.
///
/// The built-in program is only a STARTING POINT. Everything about it is
/// changeable: which days train, what each day is called, which exercises are
/// in it, sets, reps and rest. The built-in registry is never mutated — the
/// user's copy is a separate persisted program, so "Reset to default" is
/// always possible and nothing is lost forever.
@Riverpod(keepAlive: true)
class ActiveProgramController extends _$ActiveProgramController {
  static const _key = '${AppIds.prefPrefix}program.custom.v1';

  @override
  Future<WorkoutProgram> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return ProgramRegistry.blank;
    try {
      return WorkoutProgram.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>(),
      );
    } catch (_) {
      return ProgramRegistry.blank;
    }
  }

  bool isCustom() =>
      state.hasValue && state.value!.id != ProgramRegistry.blank.id;

  void _apply(WorkoutProgram program) {
    state = AsyncData(program);
    SharedPreferences.getInstance()
        .then((p) => p.setString(_key, jsonEncode(program.toJson())))
        .ignore();
  }

  ProgramDay _day(WorkoutProgram p, int dayNumber) =>
      p.days.firstWhere((d) => d.dayNumber == dayNumber);

  WorkoutProgram _replaceDay(WorkoutProgram p, ProgramDay day) => p.copyWith(
    days: [
      for (final d in p.days)
        if (d.dayNumber == day.dayNumber) day else d,
    ],
  );

  /// Swaps two days of the week — "I want to train legs on Wednesday".
  void swapDays(int a, int b) {
    final p = state.value;
    if (p == null || a == b) return;
    final da = _day(p, a);
    final db = _day(p, b);
    _apply(
      _replaceDay(
        _replaceDay(p, da.copyWith(dayNumber: db.dayNumber)),
        db.copyWith(dayNumber: da.dayNumber),
      ),
    );
  }

  /// Moves a day earlier/later in the week order.
  void moveDay(int dayNumber, int offset) {
    final p = state.value;
    if (p == null) return;
    final ordered = [...p.days]
      ..sort((x, y) => x.dayNumber.compareTo(y.dayNumber));
    final index = ordered.indexWhere((d) => d.dayNumber == dayNumber);
    final target = index + offset;
    if (index < 0 || target < 0 || target >= ordered.length) return;
    final moved = ordered.removeAt(index);
    ordered.insert(target, moved);
    _apply(
      p.copyWith(
        days: [
          for (var i = 0; i < ordered.length; i++)
            ordered[i].copyWith(dayNumber: i + 1),
        ],
      ),
    );
  }

  /// Toggles a day between training and rest.
  void setDayType(int dayNumber, ProgramDayType type) {
    final p = state.value;
    if (p == null) return;
    final day = _day(p, dayNumber);
    if (day.type == type) return;
    _apply(
      _replaceDay(
        p,
        day.copyWith(
          type: type,
          // A rest day has no exercises; a training day always needs a name.
          exercises: type == ProgramDayType.rest ? const [] : day.exercises,
          name: type == ProgramDayType.rest ? 'Rest' : day.name,
        ),
      ),
    );
  }

  void renameDay(int dayNumber, String name) {
    final p = state.value;
    if (p == null) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _apply(_replaceDay(p, _day(p, dayNumber).copyWith(name: trimmed)));
  }

  void updateDay(int dayNumber, ProgramDay Function(ProgramDay) mutate) {
    final p = state.value;
    if (p == null) return;
    _apply(_replaceDay(p, mutate(_day(p, dayNumber))));
  }

  /// The training days available to pick for "what do I want to train today".
  List<ProgramDay> get trainingDays {
    final p = state.value;
    if (p == null) return const [];
    return p.days.where((d) => d.type == ProgramDayType.training).toList();
  }

  void resetToDefault() {
    state = AsyncData(ProgramRegistry.blank);
    SharedPreferences.getInstance().then((p) => p.remove(_key)).ignore();
  }
}
