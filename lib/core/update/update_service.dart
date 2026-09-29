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

  /// `version+build` of the running app, e.g. `0.1.13+1`.
  Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  }

  /// Android application id, used to build the FileProvider content URI.
  Future<String> packageName() async =>
      (await PackageInfo.fromPlatform()).packageName;

  /// Latest published release, or null if it cannot be read.
  Future<AppRelease?> latestRelease() async {
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
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) return null;
    return AppRelease.fromGitHubJson(decoded.cast<String, Object?>());
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
