import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'update_checker.dart';

/// Fetches the newest release and the running app's version. Thin on purpose —
/// all decisions live in [UpdateChecker].
class UpdateService {
  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Public repo, no auth header needed.
  static const repoOwner = 'DALI951';
  static const repoName = 'calisthenics_app';
  static const _userAgent = 'calisthenics-app-updater';

  /// Public release manifest, when one is published.
  ///
  /// The repo is PRIVATE, so `api.github.com` answers 404 to an app that has no
  /// token — the old updater therefore NEVER found a release and blamed the
  /// connection. A plain JSON file on a public host needs no auth at all and
  /// works either way. Set it at build time:
  ///   --dart-define=UPDATE_MANIFEST_URL=https://…/latest.json
  static const manifestUrl = String.fromEnvironment('UPDATE_MANIFEST_URL');

  /// `version+build` of the running app, e.g. `0.1.13+1`.
  Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  }

  /// Latest published release, or null if it cannot be read.
  ///
  /// Manifest first (public, unauthenticated, always current), then the GitHub
  /// API (works if the repo ever goes public). Every failure returns null so
  /// the UI can explain itself rather than crash.
  Future<AppRelease?> latestRelease() async {
    if (manifestUrl.isNotEmpty) {
      final fromManifest = await _fromManifest(manifestUrl);
      if (fromManifest != null) return fromManifest;
    }
    return _fromGitHubApi();
  }

  Future<AppRelease?> _fromManifest(String url) async {
    try {
      final res = await _client.get(
        Uri.parse(url),
        headers: const {'Accept': 'application/json', 'User-Agent': _userAgent},
      );
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      return AppRelease.fromManifestJson(decoded.cast<String, Object?>());
    } catch (_) {
      return null;
    }
  }

  Future<AppRelease?> _fromGitHubApi() async {
    try {
      final uri = Uri.https(
        'api.github.com',
        '/repos/$repoOwner/$repoName/releases/latest',
      );
      final res = await _client.get(
        uri,
        headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': _userAgent,
        },
      );
      // 404 on a private repo without a token. That is expected, not an error
      // worth shouting about.
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      return AppRelease.fromGitHubJson(decoded.cast<String, Object?>());
    } catch (_) {
      return null;
    }
  }

  /// Downloads [url] to the app's cache, reporting 0..1 progress.
  /// Returns the local file, ready to hand to the installer.
  Future<File> download(
    String url,
    String fileName, {
    required void Function(double progress) onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final target = File('${dir.path}/$fileName');
    final req = http.Request('GET', Uri.parse(url));
    final res = await _client.send(req);
    if (res.statusCode != 200) {
      throw HttpException('Download failed (${res.statusCode})');
    }
    final total = res.contentLength ?? 0;
    final sink = target.openWrite();
    var received = 0;
    try {
      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress((received / total).clamp(0.0, 1.0));
      }
    } finally {
      await sink.close();
    }
    onProgress(1);
    return target;
  }

  void dispose() => _client.close();
}
