import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/services/backend_status.dart';
import '../../auth/data/auth_providers.dart';
import '../data/fake_friends_repository.dart';
import '../data/firestore_friends_repository.dart';
import '../data/friends_repository.dart';
import '../domain/friend_models.dart';

part 'friends_providers.g.dart';

/// Injectable friends backend seam (mirrors authRepository — tests override
/// this with the fake; widgets never touch Firestore directly).
@Riverpod(keepAlive: true)
FriendsRepository friendsRepository(Ref ref) {
  final status = ref.watch(backendStatusProvider);
  final authUser = ref.watch(authControllerProvider).value;
  final uid = authUser?.id;
  return switch (status) {
    BackendStatus.available || BackendStatus.emulator =>
      FirestoreFriendsRepository(FirebaseFirestore.instance, () => uid),
    BackendStatus.unavailable => FakeFriendsRepository(
      ownUid: uid ?? 'local',
      ownHandle: uid == null
          ? 'local'
          : uid.substring(0, uid.length.clamp(0, 6)),
    ),
  };
}

/// Ensures my public profile exists (creates with a derived handle).
@Riverpod(keepAlive: true)
Future<UserProfile?> ownProfile(Ref ref) async {
  final repo = ref.watch(friendsRepositoryProvider);
  return repo.ensureProfile();
}

/// Realtime accepted friends.
@Riverpod(keepAlive: true)
Stream<List<FriendProfile>> friendsList(Ref ref) =>
    ref.watch(friendsRepositoryProvider).watchFriends();

/// Realtime pending incoming requests (drives the badge).
@Riverpod(keepAlive: true)
Stream<List<FriendRequest>> incomingFriendRequests(Ref ref) =>
    ref.watch(friendsRepositoryProvider).watchIncomingRequests();

/// Realtime pending outgoing requests (drives "requested" state on search).
@Riverpod(keepAlive: true)
Stream<List<FriendRequest>> outgoingFriendRequests(Ref ref) =>
    ref.watch(friendsRepositoryProvider).watchOutgoingRequests();

/// Live user search by handle prefix.
@Riverpod(keepAlive: true)
Future<List<UserProfile>> userSearch(Ref ref, String query) async {
  if (query.trim().length < 2) return const [];
  final repo = ref.watch(friendsRepositoryProvider);
  return repo.searchUsers(query);
}
