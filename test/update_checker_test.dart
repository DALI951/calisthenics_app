import 'package:calisthenics_app/core/update/update_checker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const checker = UpdateChecker();

  AppRelease release(
    String tag, {
    String apk = 'https://example/app.apk',
    String name = 'app.apk',
  }) {
    final r = AppRelease.fromGitHubJson({
      'tag_name': tag,
      'assets': [
        {'name': 'notes.txt', 'browser_download_url': 'https://example/n'},
        if (apk.isNotEmpty) {'name': name, 'browser_download_url': apk},
      ],
      'body': 'notes here',
    });
    return r!;
  }

  group('release parsing', () {
    test('parses a v0.1.13+1 tag into version + build', () {
      final r = release('v0.1.13+1');
      expect(r.version, '0.1.13');
      expect(r.build, 1);
      expect(r.apkUrl, 'https://example/app.apk');
      expect(r.apkName, 'app.apk');
      expect(r.notes, 'notes here');
    });

    test('a release with no build suffix is build -1, not 0', () {
      expect(release('v1.2.3').build, -1);
    });

    test('finds the APK even when it is not the first asset', () {
      final r = release(
        'v0.1.14+2',
        apk: 'https://example/x.apk',
        name: 'b.apk',
      );
      expect(r.apkName, 'b.apk');
    });

    test('a release with no APK is parsed but marked without one', () {
      final r = release('v0.1.14+2', apk: '');
      expect(r.hasApk, isFalse);
    });

    test('a junk payload returns null instead of crashing', () {
      expect(AppRelease.fromGitHubJson(const {}), isNull);
      expect(AppRelease.fromGitHubJson(const {'tag_name': 'nightly'}), isNull);
      expect(AppRelease.fromGitHubJson(const {'tag_name': ''}), isNull);
    });
  });

  group('version comparison', () {
    test('same version and build is up to date', () {
      final d = checker.compare(
        current: '0.1.13+1',
        release: release('v0.1.13+1'),
      );
      expect(d.check, UpdateCheck.upToDate);
      expect(d.isNewer, isFalse);
    });

    test('a higher patch is an available update', () {
      final d = checker.compare(
        current: '0.1.13+1',
        release: release('v0.1.14+1'),
      );
      expect(d.check, UpdateCheck.updateAvailable);
      expect(d.isNewer, isTrue);
    });

    test('a higher build of the same version counts as newer', () {
      expect(
        checker
            .compare(current: '0.1.13+1', release: release('v0.1.13+2'))
            .check,
        UpdateCheck.updateAvailable,
      );
    });

    test('minor and major both count', () {
      expect(
        checker
            .compare(current: '0.1.13+1', release: release('v0.2.0+1'))
            .isNewer,
        isTrue,
      );
      expect(
        checker
            .compare(current: '0.9.0+1', release: release('v1.0.0+1'))
            .isNewer,
        isTrue,
      );
    });

    test('an older published release never nags the user', () {
      final d = checker.compare(
        current: '0.2.0+1',
        release: release('v0.1.13+1'),
      );
      expect(d.check, UpdateCheck.upToDate);
      expect(d.reason, contains('newer build'));
    });

    test('a newer release without an APK says so honestly', () {
      final d = checker.compare(
        current: '0.1.13+1',
        release: release('v0.1.14+1', apk: ''),
      );
      expect(d.check, UpdateCheck.updateWithoutApk);
      expect(d.isNewer, isTrue);
    });

    test('a missing release fails the check instead of pretending', () {
      final d = checker.compare(current: '0.1.13+1', release: null);
      expect(d.check, UpdateCheck.checkFailed);
      expect(d.reason, isNotNull);
    });

    test('an unreadable local version fails the check', () {
      final d = checker.compare(current: 'dev', release: release('v0.1.14+1'));
      expect(d.check, UpdateCheck.checkFailed);
    });

    test('numeric, not lexical: 0.1.9 is older than 0.1.10', () {
      expect(
        checker
            .compare(current: '0.1.10+1', release: release('v0.1.9+1'))
            .check,
        UpdateCheck.upToDate,
      );
    });
  });
}
