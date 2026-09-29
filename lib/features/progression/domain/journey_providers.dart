import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_ids.dart';
import 'progression_engine.dart';

part 'journey_providers.g.dart';

/// How far through the long-term journey this athlete is.
///
/// This is what makes a program a journey rather than a 4-day loop: the week
/// counter never ends, the blocks repeat in a cycle, and each block asks for
/// a different kind of effort. It advances when a training week is actually
/// completed, never by opening the app.
@Riverpod(keepAlive: true)
class JourneyProgressController extends _$JourneyProgressController {
  static const _key = '${AppIds.prefPrefix}journey.week.v1';

  @override
  Future<JourneyProgress> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const JourneyProgress(week: 1);
    try {
      final decoded = jsonDecode(raw) as Map;
      final week = decoded['week'];
      if (week is int && week >= 1) return JourneyProgress(week: week);
    } catch (_) {
      // Corrupt progress restarts the journey at week 1 rather than crashing.
    }
    return const JourneyProgress(week: 1);
  }

  /// Called when a training week is genuinely finished.
  Future<void> advanceWeek() async {
    final next = (state.value ?? const JourneyProgress(week: 1)).next();
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode({'week': next.week}));
  }

  Future<void> reset() async {
    state = const AsyncData(JourneyProgress(week: 1));
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
