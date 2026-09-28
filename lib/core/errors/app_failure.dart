/// Central user-facing failure type.
///
/// Every repository/service converts raw exceptions (Firebase, network, io)
/// into [AppFailure]. Widgets show `friendlyMessage` and never leak raw
/// Firebase exceptions (product rule) while `debugDetails` keeps dev info
/// out of the UI and out of logs that could contain sensitive data.
sealed class AppFailure implements Exception {
  const AppFailure(this.code, this.friendlyMessage, {this.debugDetails});

  /// Stable machine-readable code (also used for analytics/error tracking).
  final String code;

  /// Human-readable message safe to show to the user.
  final String friendlyMessage;

  /// Developer-only context. Never render this in the UI.
  final String? debugDetails;

  @override
  String toString() => 'AppFailure($code)';
}

/// Backend is not configured (no Firebase project / no google-services.json).
class BackendUnavailableFailure extends AppFailure {
  const BackendUnavailableFailure({super.debugDetails})
    : super(
        'backend_unavailable',
        'This build is not connected to a backend yet. '
            'Set up your Firebase project and add google-services.json '
            '(see docs/firebase-setup.md), then rebuild.',
      );
}

/// No network or Firebase unreachable.
class NetworkFailure extends AppFailure {
  const NetworkFailure({super.debugDetails})
    : super(
        'network_unavailable',
        'Could not reach the server. Check your connection and try again.',
      );
}

/// A sync operation failed; data is safe locally and will be retried.
class SyncFailure extends AppFailure {
  const SyncFailure({super.debugDetails})
    : super(
        'sync_failed',
        "Couldn't sync your workout. It's saved on this device and will "
            'sync automatically when you are back online.',
      );
}

/// Authentication-related failure with a specific, readable message.
class AuthFailure extends AppFailure {
  const AuthFailure(super.code, super.friendlyMessage, {super.debugDetails});

  /// Maps common FirebaseAuthException codes + our own codes to a friendly
  /// message. Unknown codes get a generic message (never the raw error).
  factory AuthFailure.fromCode(String code, {String? debugDetails}) {
    final message = switch (code) {
      'invalid-email' =>
        'That email address looks wrong. Check it and try again.',
      'user-disabled' => 'This account has been disabled. Contact support.',
      'user-not-found' =>
        'No account found for that email. Want to sign up instead?',
      'wrong-password' => 'Incorrect password. Try again or reset it.',
      'invalid-credential' => 'Incorrect email or password.',
      'email-already-in-use' =>
        'That email is already registered. Sign in instead.',
      'weak-password' => 'Password is too weak. Use at least 6 characters.',
      'operation-not-allowed' => 'This sign-in method is not enabled.',
      'too-many-requests' => 'Too many attempts. Wait a moment and try again.',
      'network-request-failed' =>
        'Connection problem. Check your internet and retry.',
      'missing-android-pkg-name' ||
      'invalid-app-credential' => 'Sign-in is not ready on this device yet.',
      _ => 'Could not sign in. Please try again.',
    };
    return AuthFailure(code, message, debugDetails: debugDetails);
  }
}

/// Input failed validation (forms, onboarding).
class ValidationFailure extends AppFailure {
  const ValidationFailure(
    super.code,
    super.friendlyMessage, {
    super.debugDetails,
  });
}

/// The user tried something the current phase of the app does not support yet.
class NotAvailableFailure extends AppFailure {
  const NotAvailableFailure(String feature, {super.debugDetails})
    : super('not_available', '$feature is not available in this build yet.');
}
