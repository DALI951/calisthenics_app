import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'update_checker.dart';
import 'update_service.dart';

part 'update_providers.g.dart';

@Riverpod(keepAlive: true)
UpdateService updateService(Ref ref) {
  final s = UpdateService();
  ref.onDispose(s.dispose);
  return s;
}

final updateCheckerProvider = Provider<UpdateChecker>(
  (_) => const UpdateChecker(),
);

/// What the updater is doing right now.
sealed class UpdateState {
  const UpdateState();
}

/// Nothing has happened yet.
class UpdateIdle extends UpdateState {
  const UpdateIdle();
}

class UpdateChecking extends UpdateState {
  const UpdateChecking();
}

class UpdateDone extends UpdateState {
  const UpdateDone(this.decision);
  final UpdateDecision decision;

  bool get hasUpdate => decision.isNewer;
  bool get failed => decision.check == UpdateCheck.checkFailed;
}

class UpdateDownloading extends UpdateState {
  const UpdateDownloading(this.progress);
  final double progress;
}

/// The APK is on disk; the installer is the next step.
class UpdateReadyToInstall extends UpdateState {
  const UpdateReadyToInstall(this.file, this.release);
  final File file;
  final AppRelease release;
}

class UpdateFailed extends UpdateState {
  const UpdateFailed(this.message);
  final String message;
}

@Riverpod(keepAlive: true)
class UpdateController extends _$UpdateController {
  @override
  UpdateState build() => const UpdateIdle();

  /// Checks GitHub for a newer release. Never throws at the UI.
  Future<void> check() async {
    if (state is UpdateChecking) return;
    state = const UpdateChecking();
    try {
      final svc = ref.read(updateServiceProvider);
      final release = await svc.latestRelease();
      if (release == null) {
        state = UpdateDone(
          const UpdateChecker().compare(current: '0.0.0', release: null),
        );
        return;
      }
      final current = await svc.currentVersion();
      final decision = ref
          .read(updateCheckerProvider)
          .compare(current: current, release: release);
      state = UpdateDone(decision);
    } catch (e) {
      state = const UpdateDone(
        UpdateDecision(
          UpdateCheck.checkFailed,
          reason:
              'Could not check for updates. You are on the latest known '
              'build — try again when you are online.',
        ),
      );
    }
  }

  /// Downloads the APK into the app cache.
  Future<void> download() async {
    final done = state;
    if (done is! UpdateDone) return;
    final release = done.decision.release;
    if (release == null || !release.hasApk) return;
    state = const UpdateDownloading(0);
    try {
      final file = await ref
          .read(updateServiceProvider)
          .download(
            release.apkUrl,
            release.apkName.isEmpty ? 'calisthenics.apk' : release.apkName,
            onProgress: (p) => state = UpdateDownloading(p),
          );
      state = UpdateReadyToInstall(file, release);
    } catch (e) {
      state = UpdateFailed('Download failed. Check your connection and retry.');
    }
  }

  /// Hands the APK to the system installer.
  ///
  /// Android blocks raw `file://` intents, so the cache file is shared through
  /// the app's FileProvider (`content://<pkg>.fileprovider/updates/<name>`).
  /// If even that is refused, the release page opens instead — the user is
  /// never left staring at a button that did nothing.
  Future<void> install() async {
    final ready = state;
    if (ready is! UpdateReadyToInstall) return;
    final name = Uri.encodeComponent(ready.file.uri.pathSegments.last);

    var opened = false;
    try {
      final pkg = await ref.read(updateServiceProvider).packageName();
      opened = await launchUrl(
        Uri.parse('content://$pkg.fileprovider/updates/$name'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened) opened = await _openReleasePage();
    if (!opened) {
      state = const UpdateFailed(
        'Your phone would not open the installer. Download the update from '
        'GitHub instead.',
      );
    }
  }

  Future<bool> _openReleasePage() async {
    final page =
        'https://github.com/${UpdateService.repoOwner}/'
        '${UpdateService.repoName}/releases/latest';
    try {
      return await launchUrl(
        Uri.parse(page),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }

  void reset() => state = const UpdateIdle();
}
