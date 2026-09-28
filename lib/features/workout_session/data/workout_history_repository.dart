import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_ids.dart';
import '../domain/workout_session.dart';

part 'workout_history_repository.g.dart';

/// Local-first workout history (spec §31, §17): completed sessions are
/// IMMUTABLE records — never modified after completion (spec §60). This
/// storage backs history/PRs/analytics today and syncs to Firestore in
/// Phase 11 (idempotent, client-generated ids).
@Riverpod(keepAlive: true)
class WorkoutHistoryRepository extends _$WorkoutHistoryRepository {
  static const _key = '${AppIds.prefPrefix}history.v1';

  @override
  Future<List<WorkoutSession>> build() => _read();

  Future<List<WorkoutSession>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => WorkoutSession.fromStorage(e as Map<String, Object?>))
          .toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    } catch (_) {
      return const [];
    }
  }

  Future<void> add(WorkoutSession session) async {
    final current = await _read();
    final next = [session, ...current];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(next.map((s) => s.toStorage()).toList()),
    );
    state = AsyncData(next);
  }

  /// Sessions strictly BEFORE [before] (newest first) — used by the PR
  /// detector and Phase 5 analytics without loading "whole collections".
  List<WorkoutSession> priorSessions(
    List<WorkoutSession> all,
    WorkoutSession before,
  ) {
    final end = before.startedAt;
    return all.where((s) => s.startedAt.isBefore(end)).toList();
  }
}
