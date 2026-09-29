import 'dart:io';

import 'package:flutter/services.dart';
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

  /// Checks for a newer release. Never throws at the UI.
  Future<void> check() async {
    if (state is UpdateChecking) return;
    state = const UpdateChecking();
    try {
      final svc = ref.read(updateServiceProvider);
      final release = await svc.latestRelease();
      if (release == null) {
        // The repo is private, so an unauthenticated GitHub API call 404s.
        // Say THAT instead of pretending it was a bad connection, and point
        // the user at something that actually works.
        state = const UpdateDone(
          UpdateDecision(
            UpdateCheck.checkFailed,
            reason:
                'Automatic checks need a public download link. Open the '
                'releases page to download the newest version.',
          ),
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
      state = UpdateFailed(
        'Could not download the update. Check your connection and retry — if it '
        'keeps failing, download the APK from the releases page instead.',
      );
    }
  }

  /// Hands the APK to the system installer.
  ///
  /// The intent is built on the Android side (see UpdateInstallerChannel)
  /// because it needs the APK MIME type and FLAG_GRANT_READ_URI_PERMISSION.
  /// A content:// URI launched through url_launcher without that grant cannot
  /// be read, and the install dies silently as "App not installed".
  Future<void> install() async {
    final ready = state;
    if (ready is! UpdateReadyToInstall) return;

    var opened = false;
    try {
      opened =
          await _channel.invokeMethod<bool>('installApk', {
            'path': ready.file.path,
          }) ??
          false;
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

  static const _channel = MethodChannel(
    'com.dali951.calisthenics_app/update_installer',
  );

  /// Opens the release page in a browser, where the user's own GitHub session
  /// (if any) can authorise the private download.
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
