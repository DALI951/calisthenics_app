/// In-app updater (release check against GitHub Releases).
///
/// Pure logic, zero Firebase, zero network — the network layer feeds it a
/// release map and a download function. That keeps the interesting part
/// (version comparison, honest states) testable without a network.
library;

/// A published release, parsed from the GitHub Releases API payload.
class AppRelease {
  const AppRelease({
    required this.tag,
    required this.version,
    required this.build,
    required this.apkUrl,
    required this.apkName,
    this.notes = '',
  });

  /// e.g. `v0.1.13+1`.
  final String tag;

  /// e.g. `0.1.13`.
  final String version;

  /// Android build number after `+`, e.g. `1`. -1 when absent.
  final int build;

  /// Direct download URL of the release APK, empty when the release has none.
  final String apkUrl;

  final String apkName;
  final String notes;

  bool get hasApk => apkUrl.isNotEmpty;

  /// Parses the GitHub `releases/latest` payload. Returns null when the shape
  /// is not what we expect — a bad payload must never crash the check.
  static AppRelease? fromGitHubJson(Map<String, Object?> json) {
    final tag = json['tag_name'];
    if (tag is! String || tag.isEmpty) return null;
    final version = _versionOf(tag);
    if (version == null) return null;

    var apkUrl = '';
    var apkName = '';
    final assets = json['assets'];
    if (assets is List) {
      for (final a in assets) {
        if (a is Map &&
            a['name'] is String &&
            (a['name'] as String).endsWith('.apk')) {
          apkName = a['name'] as String;
          final url = a['browser_download_url'];
          if (url is String) apkUrl = url;
          break;
        }
      }
    }
    return AppRelease(
      tag: tag,
      version: version,
      build: _buildOf(tag),
      apkUrl: apkUrl,
      apkName: apkName,
      notes: json['body'] is String ? json['body'] as String : '',
    );
  }

  /// `v0.1.13+1` -> `0.1.13`.
  static String? _versionOf(String tag) {
    final m = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)').firstMatch(tag.trim());
    if (m == null) return null;
    return '${m.group(1)}.${m.group(2)}.${m.group(3)}';
  }

  /// `v0.1.13+1` -> 1. Returns -1 when there is no build suffix.
  static int _buildOf(String tag) {
    final m = RegExp(r'\+(\d+)').firstMatch(tag);
    return m == null ? -1 : int.parse(m.group(1)!);
  }
}

/// What the check concluded. Deliberately explicit — no vague "something
/// happened".
enum UpdateCheck {
  /// The published release is the same as the running app.
  upToDate,

  /// A newer release exists and has a downloadable APK.
  updateAvailable,

  /// A newer release exists but has no APK attached.
  updateWithoutApk,

  /// The check could not be performed (offline, rate-limited, bad payload).
  checkFailed,
}

class UpdateDecision {
  const UpdateDecision(this.check, {this.release, this.reason});

  final UpdateCheck check;
  final AppRelease? release;

  /// Shown to the user when [check] is [UpdateCheck.checkFailed].
  final String? reason;

  bool get isNewer =>
      check == UpdateCheck.updateAvailable ||
      check == UpdateCheck.updateWithoutApk;
}

/// Compares the running app against the newest published release.
class UpdateChecker {
  const UpdateChecker();

  /// [current] is `version+build`, e.g. `0.1.13+1`.
  UpdateDecision compare({required String current, AppRelease? release}) {
    if (release == null) {
      return UpdateDecision(
        UpdateCheck.checkFailed,
        reason: 'Could not read the latest release. Check your connection.',
      );
    }
    final cur = _Version.parse(current);
    if (cur == null) {
      return const UpdateDecision(
        UpdateCheck.checkFailed,
        reason: 'Could not read this app\'s version.',
      );
    }
    final newest = _Version.parse('${release.version}+${release.build}');
    if (newest == null) {
      return UpdateDecision(
        UpdateCheck.checkFailed,
        reason: 'The published release has an unreadable version.',
      );
    }

    final cmp = newest.compareTo(cur);
    if (cmp == 0) {
      return UpdateDecision(UpdateCheck.upToDate, release: release);
    }
    if (cmp < 0) {
      // The published release is older — a dev/beta build. Say so honestly
      // instead of nagging the user to "update" to something older.
      return UpdateDecision(
        UpdateCheck.upToDate,
        release: release,
        reason: 'You are on a newer build than the public release.',
      );
    }
    return UpdateDecision(
      release.hasApk
          ? UpdateCheck.updateAvailable
          : UpdateCheck.updateWithoutApk,
      release: release,
    );
  }
}

class _Version implements Comparable<_Version> {
  const _Version(this.major, this.minor, this.patch, this.build);

  final int major;
  final int minor;
  final int patch;

  /// -1 means "absent", which sorts below any real build number.
  final int build;

  static _Version? parse(String raw) {
    final m = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?')
        .firstMatch(raw.trim());
    if (m == null) return null;
    return _Version(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
      m.group(4) == null ? -1 : int.parse(m.group(4)!),
    );
  }

  @override
  int compareTo(_Version other) {
    final parts = [
      (major, other.major),
      (minor, other.minor),
      (patch, other.patch),
      (build, other.build),
    ];
    for (final p in parts) {
      final c = p.$1.compareTo(p.$2);
      if (c != 0) return c;
    }
    return 0;
  }
}
