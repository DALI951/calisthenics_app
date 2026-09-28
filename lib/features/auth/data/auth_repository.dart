import '../../../../core/errors/app_failure.dart';
import '../domain/app_user.dart';

/// Auth data source contract. UI and ViewModels depend on this interface,
/// never on Firebase directly — tests swap in [FakeAuthRepository].
abstract interface class AuthRepository {
  /// Stream of the current signed-in user (null when signed out).
  Stream<AppUser?> authStateChanges();

  /// Current signed-in user, or null.
  AppUser? get currentUser;

  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<void> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  });

  Future<void> sendPasswordResetEmail(String email);

  Future<void> signOut();

  /// Deletes the account. Implementations should cascade/soft-delete
  /// associated data per the documented policy (docs/architecture.md).
  Future<void> deleteAccount();

  /// Maps raw provider errors to [AppFailure] — no raw exceptions leak.
  AppFailure mapError(Object error, {String? context});
}

/// Wraps an [AuthRepository] whose methods all fail with [BackendUnavailableFailure]
/// until Firebase is configured — used when [BackendStatus.unavailable].
class NoBackendAuthRepository implements AuthRepository {
  const NoBackendAuthRepository();

  @override
  Stream<AppUser?> authStateChanges() => Stream.value(null);

  @override
  AppUser? get currentUser => null;

  AppFailure get _unavailable => const BackendUnavailableFailure();

  @override
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    throw _unavailable;
  }

  @override
  Future<void> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    throw _unavailable;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    throw _unavailable;
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() async {
    throw _unavailable;
  }

  @override
  AppFailure mapError(Object error, {String? context}) {
    if (error is AppFailure) return error;
    return BackendUnavailableFailure(debugDetails: context);
  }
}
