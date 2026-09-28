import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/services/backend_status.dart';
import '../data/auth_repository.dart';
import '../data/firebase_auth_repository.dart';
import '../domain/app_user.dart';

part 'auth_providers.g.dart';

/// Global backend status — injected by main() after Firebase bootstrap.
/// In tests, override [authRepositoryProvider] (simpler) or this.
@Riverpod(keepAlive: true)
BackendStatus backendStatus(Ref ref) => BackendStatus.unavailable;

/// Chosen auth backend at runtime. No Firebase import leaks into widgets
/// or tests — they only ever see [AuthRepository].
@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  final status = ref.watch(backendStatusProvider);
  return switch (status) {
    BackendStatus.available ||
    BackendStatus.emulator => FirebaseAuthRepository(FirebaseAuth.instance),
    BackendStatus.unavailable => const NoBackendAuthRepository(),
  };
}

/// Auth state machine — single source of truth for the router and screens.
/// Mirrors the repository's auth stream; holds `null` when signed out.
@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  StreamSubscription<AppUser?>? _sub;

  @override
  Future<AppUser?> build() async {
    final repo = ref.watch(authRepositoryProvider);
    final current = repo.currentUser;
    _sub?.cancel();
    _sub = repo.authStateChanges().listen((user) {
      state = AsyncData(user);
    });
    ref.onDispose(() => _sub?.cancel());
    return current;
  }

  Future<void> signIn({required String email, required String password}) async {
    final repo = ref.read(authRepositoryProvider);
    await repo.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    await repo.signUpWithEmailAndPassword(
      email: email,
      password: password,
      displayName: displayName,
    );
  }

  Future<void> resetPassword(String email) async {
    final repo = ref.read(authRepositoryProvider);
    await repo.sendPasswordResetEmail(email);
  }

  Future<void> signOut() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.signOut();
    state = const AsyncData(null);
  }

  Future<void> deleteAccount() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.deleteAccount();
    state = const AsyncData(null);
  }
}
