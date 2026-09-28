/// Build environment, selected via --dart-define=APP_ENV=...
///
///   dev  -> emulator-first Firebase (or local fakes), verbose logging
///   prod -> real Firebase project, normal logging
enum AppEnv {
  dev,
  prod;

  static AppEnv fromName(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'prod':
      case 'production':
        return AppEnv.prod;
      default:
        return AppEnv.dev;
    }
  }

  bool get isDev => this == AppEnv.dev;
  bool get isProd => this == AppEnv.prod;

  /// True when the Firebase Emulator Suite should back this build.
  /// Enabled by default in dev; override with --dart-define=USE_FIREBASE_EMULATORS=false.
  bool get useEmulators {
    const override = String.fromEnvironment('USE_FIREBASE_EMULATORS');
    if (override.isNotEmpty) {
      return override == 'true' || override == '1';
    }
    return isDev;
  }
}
