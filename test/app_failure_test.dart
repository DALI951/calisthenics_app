import 'package:calisthenics_app/core/errors/app_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthFailure.fromCode', () {
    test('maps known Firebase codes to friendly messages', () {
      final cases = {
        'invalid-email':
            'That email address looks wrong. Check it and try again.',
        'user-not-found':
            'No account found for that email. Want to sign up instead?',
        'wrong-password': 'Incorrect password. Try again or reset it.',
        'invalid-credential': 'Incorrect email or password.',
        'email-already-in-use':
            'That email is already registered. Sign in instead.',
        'weak-password': 'Password is too weak. Use at least 6 characters.',
        'user-disabled': 'This account has been disabled. Contact support.',
        'too-many-requests': 'Too many attempts. Wait a moment and try again.',
        'network-request-failed':
            'Connection problem. Check your internet and retry.',
      };
      cases.forEach((code, expected) {
        final failure = AuthFailure.fromCode(code);
        expect(failure.code, code, reason: 'code for $code');
        expect(failure.friendlyMessage, expected, reason: 'message for $code');
      });
    });

    test('unknown codes get a generic message, never the raw error', () {
      final failure = AuthFailure.fromCode(
        'auth/internal-error-with-secrets',
        debugDetails: 'signIn: raw-firebase-message-with-token',
      );
      expect(failure.friendlyMessage, 'Could not sign in. Please try again.');
      // debug info stays out of the user-facing message.
      expect(failure.friendlyMessage.contains('raw-firebase'), isFalse);
      expect(failure.debugDetails, contains('raw-firebase'));
    });
  });

  group('AppFailure', () {
    test('toString is compact and stable', () {
      const failure = NetworkFailure();
      expect(failure.toString(), 'AppFailure(network_unavailable)');
    });

    test('sealed hierarchy is user-safe', () {
      const failures = <AppFailure>[
        BackendUnavailableFailure(),
        NetworkFailure(),
        SyncFailure(),
        AuthFailure('x', 'y'),
        ValidationFailure('v', 'invalid'),
        NotAvailableFailure('Search'),
      ];
      for (final f in failures) {
        expect(f.friendlyMessage, isNotEmpty);
        expect(f.code, isNotEmpty);
      }
    });
  });
}
