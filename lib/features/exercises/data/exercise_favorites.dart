import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_ids.dart';

part 'exercise_favorites.g.dart';

/// Favorite exercise ids (spec §64 — favorites in library & quick start).
@Riverpod(keepAlive: true)
class ExerciseFavorites extends _$ExerciseFavorites {
  static const _key = '${AppIds.prefPrefix}exercises.favorites';

  @override
  Future<Set<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return <String>{};
    try {
      return (jsonDecode(raw) as List<dynamic>).cast<String>().toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> toggle(String exerciseId) async {
    final current = state.value ?? <String>{};
    final next = {...current};
    next.contains(exerciseId) ? next.remove(exerciseId) : next.add(exerciseId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(next.toList()));
    state = AsyncData(next);
  }
}

/// Recently viewed/performed exercise ids, most recent first, capped at 8
/// (spec §65).
@Riverpod(keepAlive: true)
class RecentlyUsedExercises extends _$RecentlyUsedExercises {
  static const _key = '${AppIds.prefPrefix}exercises.recent';
  static const _max = 8;

  @override
  Future<List<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List<dynamic>).cast<String>();
    } catch (_) {
      return const [];
    }
  }

  Future<void> record(String exerciseId) async {
    final current = state.value ?? const [];
    final next = [
      exerciseId,
      ...current.where((id) => id != exerciseId),
    ].take(_max).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(next));
    state = AsyncData(next);
  }
}
