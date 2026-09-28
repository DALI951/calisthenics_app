import 'package:firebase_core/firebase_core.dart';

import 'app_env.dart';

/// Runtime configuration.
///
/// Secrets policy: no real Firebase API keys live in this file or in git.
/// Dev builds initialize Firebase programmatically against the Emulator Suite
/// (dummy values are fine — emulators ignore them). Prod builds rely on the
/// platform config (google-services.json / GoogleService-Info.plist) from
/// Dali's real Firebase project; keys can additionally be injected via
/// --dart-define only if ever needed.
abstract final class AppConfig {
  static const String appName = 'Calisthenics';

  /// Single source of truth for the display version.
  static const String appVersion = '0.1.0';

  /// Emulator hosts (Firebase Emulator Suite defaults).
  /// Android emulators reach the host machine via 10.0.2.2.
  static const String _emulatorAuthHost = '10.0.2.2';
  static const String _emulatorFirestoreHost = '10.0.2.2';
  static const String _emulatorDatabaseHost = '10.0.2.2';
  static const String _emulatorStorageHost = '10.0.2.2';

  /// Placeholder project id for emulator mode.
  static const String _emulatorProjectId = 'calisthenics-app';

  /// FirebaseOptions used when running against the Emulator Suite.
  /// Values are intentionally dummy — the emulators accept any project id.
  static FirebaseOptions get emulatorOptions => const FirebaseOptions(
    apiKey: 'emulator-api-key-do-not-commit',
    appId: 'emulator-app-id-do-not-commit',
    messagingSenderId: 'emulator-sender',
    projectId: _emulatorProjectId,
  );

  static FirebaseOptions? get _prodViaDartDefine {
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    if (apiKey.isEmpty || appId.isEmpty || projectId.isEmpty) return null;
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: const String.fromEnvironment('FIREBASE_SENDER_ID'),
      projectId: projectId,
      storageBucket: const String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
    );
  }

  /// Options to pass to Firebase.initializeApp.
  ///
  /// Prod prefers the platform config (google-services.json), falling back to
  /// dart-define options. Non-prod uses emulator options.
  static Future<FirebaseOptions> resolveOptions(AppEnv env) async {
    if (env.isDev) return emulatorOptions;
    final fromDefine = _prodViaDartDefine;
    if (fromDefine != null) return fromDefine;
    // Platform default config (google-services.json) via FirebaseCore.
    return Firebase.app().options;
  }

  static const String emulatorAuthHost = _emulatorAuthHost;
  static const String emulatorFirestoreHost = _emulatorFirestoreHost;
  static const String emulatorDatabaseHost = _emulatorDatabaseHost;
  static const String emulatorStorageHost = _emulatorStorageHost;

  static const int emulatorAuthPort = 9099;
  static const int emulatorFirestorePort = 8080;
  static const int emulatorDatabasePort = 9000;
  static const int emulatorStoragePort = 9199;

  /// Firestore query budget guard — cap document reads on list screens.
  static const int defaultPageSize = 30;
}
