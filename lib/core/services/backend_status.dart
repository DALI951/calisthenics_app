/// Where the backend landed after bootstrap. Injected once at startup;
/// everything backend-related reads this first.
enum BackendStatus {
  /// Connected to a real Firebase project (platform config or dart-define).
  available,

  /// Connected to the Firebase Emulator Suite (dev builds by default).
  emulator,

  /// Could not initialize Firebase — app runs local-only and any backend
  /// action shows the honest unavailable error.
  unavailable;

  bool get isUsable => this != unavailable;
}
