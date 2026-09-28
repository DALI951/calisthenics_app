import 'package:firebase_auth/firebase_auth.dart' as fa;

import '../../../core/errors/app_failure.dart';
import '../domain/app_user.dart';
import 'auth_repository.dart';

/// Production repository backed by Firebase Auth.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  final fa.FirebaseAuth _auth;

  @override
  Stream<AppUser?> authStateChanges() =>
      _auth.authStateChanges().map((u) => u == null ? null : _fromFirebase(u));

  @override
  AppUser? get currentUser {
    final u = _auth.currentUser;
    return u == null ? null : _fromFirebase(u);
  }

  AppUser _fromFirebase(fa.User u) => AppUser(
    id: u.uid,
    email: u.email,
    displayName: u.displayName,
    photoUrl: u.photoURL,
    emailVerified: u.emailVerified,
  );

  @override
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      throw mapError(e, context: 'signIn');
    }
  }

  @override
  Future<void> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = cred.user;
      if (user != null && (displayName?.trim().isNotEmpty ?? false)) {
        await user.updateDisplayName(displayName!.trim());
        await user.reload();
      }
    } catch (e) {
      throw mapError(e, context: 'signUp');
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw mapError(e, context: 'resetPassword');
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await user.delete();
    } catch (e) {
      throw mapError(e, context: 'deleteAccount');
    }
  }

  @override
  AppFailure mapError(Object error, {String? context}) {
    if (error is AppFailure) return error;
    if (error is fa.FirebaseAuthException) {
      // Never leak the raw message to the UI.
      return AuthFailure.fromCode(
        error.code,
        debugDetails: '$context: ${error.message}',
      );
    }
    return const NetworkFailure();
  }
}
