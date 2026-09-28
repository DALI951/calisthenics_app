import 'dart:async';

import '../../../../core/errors/app_failure.dart';
import '../domain/app_user.dart';
import 'auth_repository.dart';

/// In-memory fake for tests and storyboards. Mirrors real behavior closely:
/// duplicate email, wrong password, etc.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    AppUser? initialUser,
    List<String> registeredEmails = const [],
  }) : _user = initialUser,
       _registeredEmails = {...registeredEmails};

  AppUser? _user;
  final Set<String> _registeredEmails;
  final Map<String, String> _passwords = {};

  final _controller = StreamController<AppUser?>.broadcast();

  @override
  Stream<AppUser?> authStateChanges() => _controller.stream;

  @override
  AppUser? get currentUser => _user;

  void _emit() => _controller.add(_user);

  @override
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (!_registeredEmails.contains(normalized)) {
      throw const AuthFailure(
        'user-not-found',
        'No account found for that email. Want to sign up instead?',
      );
    }
    if (_passwords[normalized] != password) {
      throw const AuthFailure(
        'wrong-password',
        'Incorrect password. Try again or reset it.',
      );
    }
    _user = AppUser(
      id: 'fake-${normalized.hashCode}',
      email: normalized,
      emailVerified: true,
    );
    _emit();
  }

  @override
  Future<void> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (_registeredEmails.contains(normalized)) {
      throw const AuthFailure(
        'email-already-in-use',
        'That email is already registered. Sign in instead.',
      );
    }
    if (password.length < 6) {
      throw const AuthFailure(
        'weak-password',
        'Password is too weak. Use at least 6 characters.',
      );
    }
    _registeredEmails.add(normalized);
    _passwords[normalized] = password;
    _user = AppUser(
      id: 'fake-${normalized.hashCode}',
      email: normalized,
      displayName: displayName,
      emailVerified: true,
    );
    _emit();
  }

  @override
  Future<void> signInWithGoogle() async {
    _user = const AppUser(
      id: 'fake-g-001',
      email: 'dali.google@gmail.com',
      displayName: 'Dali (Google)',
      emailVerified: true,
    );
    _emit();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    if (!_registeredEmails.contains(email.trim().toLowerCase())) {
      throw const AuthFailure(
        'user-not-found',
        'No account found for that email.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _emit();
  }

  @override
  Future<void> deleteAccount() async {
    if (_user != null) _registeredEmails.remove(_user!.email?.toLowerCase());
    _user = null;
    _emit();
  }

  @override
  AppFailure mapError(Object error, {String? context}) {
    if (error is AppFailure) return error;
    return const NetworkFailure();
  }

  /// Test helper: seed an existing account.
  void seedAccount(String email, String password) {
    _registeredEmails.add(email.trim().toLowerCase());
    _passwords[email.trim().toLowerCase()] = password;
  }

  void dispose() => _controller.close();
}
