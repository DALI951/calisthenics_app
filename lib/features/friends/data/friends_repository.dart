import '../domain/friend_models.dart';

/// Backend seam for the friends feature (spec §20–24). Widgets and tests
/// only ever see this interface; the Firestore impl is chosen by
/// [backendStatus] like auth.
abstract class FriendsRepository {
  /// The signed-in user's own public profile (created on first use).
  Stream<UserProfile?> watchOwnProfile();

  /// Accepted, symmetric connections: `friends/{pairId}` docs.
  Stream<List<FriendProfile>> watchFriends();

  /// Pending INCOMING requests: `friendRequests/{pairId}` toUid == me.
  Stream<List<FriendRequest>> watchIncomingRequests();

  /// Pending OUTGOING requests sent by me.
  Stream<List<FriendRequest>> watchOutgoingRequests();

  /// Search users by handle prefix (case-insensitive-ish).
  Future<List<UserProfile>> searchUsers(String handlePrefix);

  /// Ensure my `users/{me}` profile doc exists; create with a derived
  /// handle when missing. Returns the current own profile.
  Future<UserProfile?> ensureProfile({String? handle});

  /// Send a friend request by target handle (or uid).
  Future<void> sendRequest(String toHandle);

  /// Accept an incoming request (creates the symmetric friends doc).
  Future<void> acceptRequest(FriendRequest request);

  /// Decline an incoming request (removes it).
  Future<void> declineRequest(FriendRequest request);

  /// Withdraw an outgoing request I sent.
  Future<void> withdrawRequest(FriendRequest request);

  /// Remove a friend (deletes the symmetric friends doc).
  Future<void> removeFriend(String friendUid);
}

/// Honest user-facing failure for friend operations.
class FriendsException implements Exception {
  const FriendsException(this.message);
  final String message;

  @override
  String toString() => message;
}
