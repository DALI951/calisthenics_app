import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_ids.dart';

/// Result of an account deletion (spec: "account deletion must remove or
/// deactivate associated data according to the project's documented policy").
///
/// The app is honest: shared documents (a challenge you and your partner can
/// both see, your own edge of a friendship) belong to both people, so a
/// client cannot unilaterally delete them. Those are listed in
/// [requiresServerPurge] and the policy is documented in the README.
class AccountDeletionReport {
  const AccountDeletionReport({
    this.remoteDocsDeleted = 0,
    this.localKeysCleared = 0,
    this.localCleared = false,
    this.accountDeleted = false,
    this.requiresServerPurge = const [],
    this.failures = const [],
  });

  /// Firestore + RTDB documents actually removed.
  final int remoteDocsDeleted;

  /// SharedPreferences keys wiped.
  final int localKeysCleared;

  final bool localCleared;

  /// The auth account itself.
  final bool accountDeleted;

  /// Data that a Cloud Function must purge (shared/competitive documents).
  final List<String> requiresServerPurge;

  /// Anything that could not be removed. Never swallowed.
  final List<String> failures;

  bool get fullyRemoved => failures.isEmpty;

  /// True when data still exists somewhere, but only in documents a partner
  /// can also see.
  bool get needsServerCleanup => requiresServerPurge.isNotEmpty;

  String describe() {
    final b = StringBuffer();
    b.write(
      'Removed $remoteDocsDeleted synced record'
      '${remoteDocsDeleted == 1 ? '' : 's'} and $localKeysCleared '
      'local setting${localKeysCleared == 1 ? '' : 's'}',
    );
    if (accountDeleted) b.write('. Signed out');
    if (needsServerCleanup) {
      b.write(
        '. ${requiresServerPurge.length} shared item'
        '${requiresServerPurge.length == 1 ? '' : 's'} still visible to '
        'your training partner until the server purge runs.',
      );
    }
    if (failures.isNotEmpty) {
      b.write(
        '. ${failures.length} item'
        '${failures.length == 1 ? '' : 's'} could not be removed.',
      );
    }
    return b.toString();
  }
}

/// Deletes everything the signed-in user owns, then the account.
///
/// Every step is defensive: one failure is recorded, never thrown, and the
/// account is still deleted so the person is not left in a half state they
/// cannot escape.
class AccountDeletionService {
  // Named parameters cannot be private in Dart, so the injected steps are
  // public fields rather than `this.clearLocal` initializing formals.
  AccountDeletionService({
    this.clearLocal,
    this.deleteFirestore,
    this.deleteRealtime,
    this.deleteAuthAccount,
  });

  /// Wipes every local key this app owns.
  final Future<int> Function()? clearLocal;

  /// Removes the caller's own Firestore documents.
  final Future<int> Function()? deleteFirestore;

  /// Removes presence + live-session nodes.
  final Future<int> Function()? deleteRealtime;

  /// Deletes the auth account itself.
  final Future<void> Function()? deleteAuthAccount;

  Future<AccountDeletionReport> run() async {
    var remote = 0;
    var localKeys = 0;
    var localCleared = false;
    var accountDeleted = false;
    final failures = <String>[];
    final server = <String>[];

    // Public final fields are not null-promoted, so take locals first.
    final clear = clearLocal;
    if (clear != null) {
      try {
        localKeys = await clear();
        localCleared = true;
      } catch (_) {
        failures.add('local settings');
      }
    } else {
      failures.add('local settings');
    }

    final firestore = deleteFirestore;
    if (firestore != null) {
      try {
        remote += await firestore();
      } catch (_) {
        failures.add('your synced profile and history');
      }
    } else {
      failures.add('your synced profile and history');
    }

    final realtime = deleteRealtime;
    if (realtime != null) {
      try {
        remote += await realtime();
      } catch (_) {
        failures.add('live presence');
      }
    }

    // Shared documents: visible to a partner, so only a trusted server may
    // delete them. Documented, not silently skipped.
    server.add('challenges you created (your partner can also see them)');
    server.add('achievements you earned (server-issued records)');
    server.add('your edge of friendships (your friend keeps theirs)');

    final auth = deleteAuthAccount;
    if (auth != null) {
      try {
        await auth();
        accountDeleted = true;
      } catch (_) {
        failures.add('your sign-in');
      }
    } else {
      failures.add('your sign-in');
    }

    return AccountDeletionReport(
      remoteDocsDeleted: remote,
      localKeysCleared: localKeys,
      localCleared: localCleared,
      accountDeleted: accountDeleted,
      requiresServerPurge: server,
      failures: failures,
    );
  }
}

/// Wipes every key this app owns in SharedPreferences.
Future<int> clearAllLocalAppData() async {
  final prefs = await SharedPreferences.getInstance();
  final keys = prefs.getKeys().where((k) => k.startsWith(AppIds.prefPrefix));
  var n = 0;
  for (final k in keys.toList()) {
    if (await prefs.remove(k)) n++;
  }
  // The theme key is prefixed too, but be explicit about onboarding so a
  // reinstall cannot land mid-flow.
  await prefs.remove(AppIds.prefOnboardingCompleted);
  return n;
}
