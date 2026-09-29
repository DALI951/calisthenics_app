import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_ids.dart';
import '../domain/onboarding_answers.dart';

part 'onboarding_providers.g.dart';

/// Whether the user completed onboarding. Drives the router gate.
/// Answers are persisted alongside, so adaptive systems can read them
/// (equipment-aware substitutions, reminder scheduling).
@Riverpod(keepAlive: true)
class OnboardingController extends _$OnboardingController {
  static const _answersKey = '${AppIds.prefPrefix}onboarding.answers';

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppIds.prefOnboardingCompleted) ?? false;
  }

  Future<void> complete(OnboardingAnswers answers) async {
    final prefs = await SharedPreferences.getInstance();
    final stamped = answers.copyWith(
      completedAt: DateTime.now().toUtc(),
      safetyAcknowledged: answers.safetyAcknowledged,
    );
    await prefs.setString(_answersKey, jsonEncode(stamped.toJson()));
    await prefs.setBool(AppIds.prefOnboardingCompleted, true);
    await prefs.setBool(
      AppIds.prefNotificationsEnabled,
      answers.notificationsEnabled,
    );
    state = const AsyncData(true);
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_answersKey);
    await prefs.remove(AppIds.prefOnboardingCompleted);
    state = const AsyncData(false);
  }

  /// Persisted answers, or null when onboarding never completed.
  Future<OnboardingAnswers?> storedAnswers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_answersKey);
    if (raw == null) return null;
    try {
      return OnboardingAnswers.fromJson(
        jsonDecode(raw) as Map<String, Object?>,
      );
    } catch (_) {
      return null;
    }
  }
}

/// In-memory draft while the wizard is open. Immutable — each step copies.
///
/// The draft is ALSO written to disk on every change, because the wizard's
/// step index and answers must survive anything that rebuilds the screen —
/// a router refresh, a remount, the app being backgrounded, or the process
/// being killed. Losing a half-finished setup because the widget was recreated
/// is exactly the "it throws me back to experience level" bug.
@Riverpod(keepAlive: true)
class OnboardingDraft extends _$OnboardingDraft {
  static const _draftKey = '${AppIds.prefPrefix}onboarding.draft.v1';

  @override
  OnboardingAnswers build() => const OnboardingAnswers();

  void update(OnboardingAnswers Function(OnboardingAnswers) mutate) {
    state = mutate(state);
    _persist(state);
  }

  /// Re-reads the draft saved on disk. Called once when the wizard opens so a
  /// relaunch resumes instead of restarting at step 0.
  Future<void> restoreFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      state = OnboardingAnswers.fromJson(decoded.cast<String, Object?>());
    } catch (_) {
      // A corrupt draft must never block onboarding — start clean.
    }
  }

  Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  void _persist(OnboardingAnswers answers) {
    // Fire-and-forget: a write failure must not break the tap that caused it.
    SharedPreferences.getInstance()
        .then(
          (prefs) => prefs.setString(_draftKey, jsonEncode(answers.toJson())),
        )
        .ignore();
  }
}
