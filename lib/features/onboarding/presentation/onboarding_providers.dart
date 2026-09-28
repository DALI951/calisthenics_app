import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_ids.dart';

part 'onboarding_providers.g.dart';

/// Whether the user completed onboarding. Drives the router gate.
/// Persisted locally (per-device); part of the user profile in the cloud
/// once Firebase profiles land.
@Riverpod(keepAlive: true)
class OnboardingController extends _$OnboardingController {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppIds.prefOnboardingCompleted) ?? false;
  }

  Future<void> complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppIds.prefOnboardingCompleted, true);
    state = const AsyncData(true);
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppIds.prefOnboardingCompleted);
    state = const AsyncData(false);
  }
}
