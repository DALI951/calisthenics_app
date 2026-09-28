import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart' as gs;

import '../../../core/errors/app_failure.dart';
import '../domain/app_user.dart';
import 'auth_repository.dart';

/// The OAuth web client ID of the Firebase project (its auto-created web
/// client). Public by design — OAuth client IDs are not secrets. Override
/// with `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` if the project changes.
const String kGoogleServerClientId = String.fromEnvironment(
  'GOOGLE_SERVER_CLIENT_ID',
  defaultValue: '706687524703-l8nboplulqotabpkcfn77p0b1tqk3d04.apps.googleusercontent.com',
);

/// Production repository backed by Firebase Auth.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  final fa.FirebaseAuth _auth;

  gs.GoogleSignIn? _google;
  bool _googleReady = false;

  Future<gs.GoogleSignIn> _getGoogle() async {
    final g = _google ??= gs.GoogleSignIn.instance;
    if (!_googleReady) {
      await g.initialize(serverClientId: kGoogleServerClientId);
      _googleReady = true;
    }
    return g;
  }

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
  Future<void> signInWithGoogle() async {
    try {
      final google = await _getGoogle();
      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AuthFailure(
          'google-id-token-missing',
          'Google did not return an identity token. Try again.',
        );
      }
      final credential = fa.GoogleAuthProvider.credential(idToken: idToken);
      await _auth.signInWithCredential(credential);
    } on gs.GoogleSignInException catch (e) {
      if (e.code == gs.GoogleSignInExceptionCode.canceled ||
          e.code == gs.GoogleSignInExceptionCode.interrupted) {
        throw const AuthFailure(
          'sign-in-cancelled',
          'Google sign-in was cancelled.',
        );
      }
      throw AuthFailure(
        'google-sign-in-failed',
        'Could not complete Google sign-in.',
        debugDetails: e.description,
      );
    } on fa.FirebaseAuthException catch (e) {
      throw mapError(e, context: 'googleSignIn');
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
    if (error is gs.GoogleSignInException) {
      if (error.code == gs.GoogleSignInExceptionCode.canceled) {
        return const AuthFailure(
          'sign-in-cancelled',
          'Google sign-in was cancelled.',
        );
      }
      return AuthFailure(
        'google-sign-in-failed',
        'Could not complete Google sign-in.',
        debugDetails: error.description,
      );
    }
    if (error is PlatformException && error.code == 'sign_in_canceled') {
      return const AuthFailure(
        'sign-in-cancelled',
        'Google sign-in was cancelled.',
      );
    }
    return const NetworkFailure();
  }
}
