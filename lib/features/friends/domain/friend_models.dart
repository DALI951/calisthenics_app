/// A public member profile as seen by the friends feature (spec §20).
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.handle,
    this.displayName,
    this.photoUrl,
    this.joinedAt,
  });

  final String uid;
  final String handle;
  final String? displayName;
  final String? photoUrl;
  final DateTime? joinedAt;

  String get displayLabel =>
      (displayName != null && displayName!.isNotEmpty) ? displayName! : handle;
}

/// A friend (an accepted, symmetric connection, spec §20/§21).
class FriendProfile {
  const FriendProfile({
    required this.uid,
    required this.handle,
    required this.since,
    this.displayName,
    this.photoUrl,
  });

  final String uid;
  final String handle;
  final DateTime since;
  final String? displayName;
  final String? photoUrl;

  String get displayLabel =>
      (displayName != null && displayName!.isNotEmpty) ? displayName! : handle;
}

/// Direction + state of a friend request (spec §20).
enum FriendRequestState { pending, accepted, declined }

class FriendRequest {
  const FriendRequest({
    required this.pairId,
    required this.fromUid,
    required this.toUid,
    required this.fromHandle,
    this.fromDisplayName,
    required this.state,
    required this.at,
  });

  final String pairId;
  final String fromUid;
  final String toUid;
  final String fromHandle;
  final String? fromDisplayName;
  final FriendRequestState state;
  final DateTime at;

  String get fromLabel =>
      (fromDisplayName != null && fromDisplayName!.isNotEmpty)
      ? fromDisplayName!
      : fromHandle;

  bool get isIncoming => state == FriendRequestState.pending;
}

/// Stable, order-independent id for a 1:1 connection (a < b sorted):
/// `friends/{pairId}`, `friendRequests/{pairId}`.
String friendPairId(String a, String b) {
  final sorted = [a, b]..sort();
  return '${sorted[0]}_${sorted[1]}';
}
