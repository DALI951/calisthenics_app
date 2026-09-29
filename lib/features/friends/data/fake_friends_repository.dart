import 'dart:async';

import '../domain/friend_models.dart';
import 'friends_repository.dart';

/// Shared state of the fake friends server. Two [FakeFriendsRepository]
/// instances (two devices) can point at ONE backend so cross-side flows
/// behave like the real Firestore world.
class FakeFriendsBackend {
  FakeFriendsBackend({
    Map<String, UserProfile> users = const {},
    List<FriendRequest> requests = const [],
    Map<String, Set<String>> friendships = const {},
  }) : users = Map.of(users),
       requests = List.of(requests),
       friendships = {
         for (final e in friendships.entries) e.key: Set.of(e.value),
       };

  final Map<String, UserProfile> users;
  final List<FriendRequest> requests;
  final Map<String, Set<String>> friendships;

  final friendsCtrl = StreamController<void>.broadcast();
  final requestsCtrl = StreamController<void>.broadcast();
  final ownCtrl = StreamController<void>.broadcast();

  /// Notify every connected device that something changed.
  void bump() {
    friendsCtrl.add(null);
    requestsCtrl.add(null);
    ownCtrl.add(null);
  }

  void dispose() {
    friendsCtrl.close();
    requestsCtrl.close();
    ownCtrl.close();
  }
}

/// Deterministic in-memory friends backend — used by widget tests and the
/// local-only fallback when the backend is unavailable. Mirrors the
/// Firestore semantics 1:1 (pair docs, denormalized friend copies).
class FakeFriendsRepository implements FriendsRepository {
  FakeFriendsRepository({
    required this._ownUid,
    this._ownHandle = 'me',
    FakeFriendsBackend? backend,
  }) : _b = backend ?? FakeFriendsBackend();

  final String _ownUid;
  String _ownHandle;
  final FakeFriendsBackend _b;

  FakeFriendsBackend get backend => _b;

  @override
  Stream<UserProfile?> watchOwnProfile() => _seeded(
    () {
      final existing = _b.users[_ownUid];
      return existing ?? UserProfile(uid: _ownUid, handle: _ownHandle);
    },
    _b.ownCtrl.stream.map((_) {
      final existing = _b.users[_ownUid];
      return existing ?? UserProfile(uid: _ownUid, handle: _ownHandle);
    }),
  );

  @override
  Stream<List<FriendProfile>> watchFriends() =>
      _seeded(_myFriends, _friendUpdates);

  @override
  Stream<List<FriendRequest>> watchIncomingRequests() => _seeded(
    _incomingRequests,
    _b.requestsCtrl.stream.map((_) => _incomingRequests()),
  );

  @override
  Stream<List<FriendRequest>> watchOutgoingRequests() => _seeded(
    _outgoingRequests,
    _b.requestsCtrl.stream.map((_) => _outgoingRequests()),
  );

  @override
  Future<List<UserProfile>> searchUsers(String handlePrefix) async {
    final prefix = handlePrefix.trim().toLowerCase();
    if (prefix.isEmpty) return const [];
    return _b.users.values
        .where((u) => u.uid != _ownUid)
        .where((u) => u.handle.toLowerCase().startsWith(prefix))
        .take(12)
        .toList();
  }

  @override
  Future<UserProfile?> ensureProfile({String? handle}) async {
    if (handle != null && handle.trim().isNotEmpty) {
      _ownHandle = handle.trim().toLowerCase();
    }
    final me = UserProfile(
      uid: _ownUid,
      handle: _ownHandle,
      displayName: _b.users[_ownUid]?.displayName,
    );
    _b.users[_ownUid] = me;
    _b.bump();
    return me;
  }

  @override
  Future<void> sendRequest(String toHandle) async {
    final matches = _b.users.values
        .where((u) => u.handle.toLowerCase() == toHandle.trim().toLowerCase())
        .toList();
    if (matches.isEmpty) {
      throw FriendsException('No user with handle "$toHandle".');
    }
    final target = matches.first;
    if (target.uid == _ownUid) {
      throw FriendsException("That's you — try a different handle.");
    }
    _b.requests.removeWhere(
      (r) => r.pairId == friendPairId(_ownUid, target.uid),
    );
    _b.requests.add(
      FriendRequest(
        pairId: friendPairId(_ownUid, target.uid),
        fromUid: _ownUid,
        toUid: target.uid,
        fromHandle: _ownHandle,
        fromDisplayName: _b.users[_ownUid]?.displayName,
        state: FriendRequestState.pending,
        at: DateTime.now(),
      ),
    );
    _b.bump();
  }

  @override
  Future<void> acceptRequest(FriendRequest request) async {
    _b.requests.removeWhere((r) => r.pairId == request.pairId);
    _b.friendships.putIfAbsent(_ownUid, () => {}).add(request.fromUid);
    _b.friendships.putIfAbsent(request.fromUid, () => {}).add(_ownUid);
    _b.bump();
  }

  @override
  Future<void> declineRequest(FriendRequest request) async {
    _b.requests.removeWhere((r) => r.pairId == request.pairId);
    _b.bump();
  }

  @override
  Future<void> withdrawRequest(FriendRequest request) async {
    _b.requests.removeWhere((r) => r.pairId == request.pairId);
    _b.bump();
  }

  @override
  Future<void> removeFriend(String friendUid) async {
    _b.friendships[_ownUid]?.remove(friendUid);
    _b.friendships[friendUid]?.remove(_ownUid);
    _b.bump();
  }

  // ---- internals ----------------------------------------------------------

  /// Yields the current state immediately, then every change after.
  Stream<T> _seeded<T>(T Function() seed, Stream<T> changes) async* {
    yield seed();
    yield* changes;
  }

  List<FriendProfile> _myFriends() {
    final list = (_b.friendships[_ownUid] ?? const <String>[])
        .map(
          (fuid) => FriendProfile(
            uid: fuid,
            handle: _b.users[fuid]?.handle ?? fuid,
            since: DateTime.utc(2026, 1, 1),
            displayName: _b.users[fuid]?.displayName,
            photoUrl: _b.users[fuid]?.photoUrl,
          ),
        )
        .toList();
    list.sort((a, b) => b.since.compareTo(a.since));
    return list;
  }

  Stream<List<FriendProfile>> get _friendUpdates =>
      _b.friendsCtrl.stream.map((_) => _myFriends());

  List<FriendRequest> _incomingRequests() =>
      _b.requests.where((r) => r.toUid == _ownUid).toList();

  List<FriendRequest> _outgoingRequests() =>
      _b.requests.where((r) => r.fromUid == _ownUid).toList();
}
