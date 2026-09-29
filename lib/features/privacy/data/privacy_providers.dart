import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/privacy_settings.dart';

part 'privacy_providers.g.dart';

@Riverpod(keepAlive: true)
class PrivacySettingsController extends _$PrivacySettingsController {
  static const _key = 'calisthenics.privacy.settings.v1';

  @override
  Future<PrivacySettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const PrivacySettings();
    try {
      return PrivacySettings.fromStorage(
        (jsonDecode(raw) as Map).cast<Object?, Object?>(),
      );
    } catch (_) {
      return const PrivacySettings();
    }
  }

  Future<void> save(PrivacySettings next) async {
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(next.toStorage()));
  }
}
