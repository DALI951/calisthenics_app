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
@Riverpod(keepAlive: true)
class OnboardingDraft extends _$OnboardingDraft {
  @override
  OnboardingAnswers build() => const OnboardingAnswers();

  void update(OnboardingAnswers Function(OnboardingAnswers) mutate) {
    state = mutate(state);
  }
}
