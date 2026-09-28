import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

part 'app_user.freezed.dart';
part 'app_user.g.dart';

/// Authenticated user identity (never sensitive detail).
@freezed
abstract class AppUser with _$AppUser {
  const factory AppUser({
    required String id,
    String? email,
    String? displayName,
    String? username,
    String? photoUrl,
    @Default(false) bool emailVerified,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, Object?> json) =>
      _$AppUserFromJson(json);

  const AppUser._();

  /// How the user sees this profile on screen.
  String get displayLabel {
    final name = (displayName?.trim().isNotEmpty ?? false)
        ? displayName?.trim()
        : (username?.trim().isNotEmpty ?? false)
        ? username?.trim()
        : null;
    if (name != null) return name;
    if (email != null) {
      final handle = email!.split('@').first;
      return handle.isEmpty ? 'Athlete' : handle;
    }
    return 'Athlete';
  }

  /// First letter of the display label, uppercased. Never null because
  /// [displayLabel] always returns a non-empty handle.
  String get initial => displayLabel.substring(0, 1).toUpperCase();
}
