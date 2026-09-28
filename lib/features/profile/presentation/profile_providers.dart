import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_ids.dart';

part 'profile_providers.g.dart';

/// Persisted theme mode (system default).
@Riverpod(keepAlive: true)
class ThemeModeController extends _$ThemeModeController {
  @override
  Future<ThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppIds.prefThemeMode);
    return raw == null
        ? ThemeMode.system
        : ThemeMode.values.firstWhere(
            (m) => m.name == raw,
            orElse: () => ThemeMode.system,
          );
  }

  Future<void> set(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppIds.prefThemeMode, mode.name);
    state = AsyncData(mode);
  }
}
