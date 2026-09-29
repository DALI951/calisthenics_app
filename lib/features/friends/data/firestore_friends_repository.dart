import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/friend_models.dart';
import 'friends_repository.dart';

/// Firestore-backed friends (spec §21 realtime, §32 secure architecture).
/// Schema (denormalized on purpose — one-doc reads, offline friendly):
///   users/{uid}                     → own public profile
///   users/{uid}/friends/{fuid}      → {handle, name, photo, since}
///   friendRequests/{pairId}         → {fromUid, toUid, fromHandle,
///                                      fromName, state, at} (pairId = sorted
///                                      uids joined with '_')
///   friends/{pairId}                → {uids[2], since, *Handle, *Name, *Photo}
///
/// Pair-doc design keeps Phase 12 security rules simple: a doc is readable
/// and writable iff the caller's uid is one of the two member uids.
class FirestoreFriendsRepository implements FriendsRepository {
  FirestoreFriendsRepository(this._db, this._ownUidOf);

  final FirebaseFirestore _db;
  final String? Function() _ownUidOf;

  String? get _me => _ownUidOf();

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  @override
  Stream<UserProfile?> watchOwnProfile() {
    final me = _me;
    if (me == null) return Stream.value(null);
    return _userDoc(me).snapshots().map(
      (s) => s.exists
          ? UserProfile(
              uid: me,
              handle: (s.data()?['handle'] ?? me) as String,
              displayName: s.data()?['name'] as String?,
              photoUrl: s.data()?['photo'] as String?,
              joinedAt: (s.data()?['joinedAt'] as Timestamp?)?.toDate(),
            )
          : null,
    );
  }

  @override
  Stream<List<FriendProfile>> watchFriends() {
    final me = _me;
    if (me == null) return Stream.value(const []);
    return _userDoc(me)
        .collection('friends')
        .orderBy('since', descending: true)
        .snapshots()
        .map(
          (qs) => qs.docs
              .map(
                (d) => FriendProfile(
                  uid: d.id,
                  handle: d.data()['handle'] as String,
                  since: (d.data()['since'] as Timestamp).toDate(),
                  displayName: d.data()['name'] as String?,
                  photoUrl: d.data()['photo'] as String?,
                ),
              )
              .toList(),
        );
  }

  @override
  Stream<List<FriendRequest>> watchIncomingRequests() {
    final me = _me;
    if (me == null) return Stream.value(const []);
    return _db
        .collection('friendRequests')
        .where('toUid', isEqualTo: me)
        .where('state', isEqualTo: 'pending')
        .snapshots()
        .map((qs) => qs.docs.map(_requestFromDoc).toList());
  }

  @override
  Stream<List<FriendRequest>> watchOutgoingRequests() {
    final me = _me;
    if (me == null) return Stream.value(const []);
    return _db
        .collection('friendRequests')
        .where('fromUid', isEqualTo: me)
        .where('state', isEqualTo: 'pending')
        .snapshots()
        .map((qs) => qs.docs.map(_requestFromDoc).toList());
  }

  FriendRequest _requestFromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data()!;
    return FriendRequest(
      pairId: d.id,
      fromUid: data['fromUid'] as String,
      toUid: data['toUid'] as String,
      fromHandle: data['fromHandle'] as String,
      fromDisplayName: data['fromDisplayName'] as String?,
      state: FriendRequestState.pending,
      at: (data['at'] as Timestamp).toDate(),
    );
  }

  @override
  Future<List<UserProfile>> searchUsers(String handlePrefix) async {
    final me = _me;
    final prefix = handlePrefix.trim().toLowerCase();
    if (me == null || prefix.isEmpty) return const [];
    final upper = '$prefix\uf8ff';
    final qs = await _db
        .collection('users')
        .where('searchHandle', isGreaterThanOrEqualTo: prefix)
        .where('searchHandle', isLessThanOrEqualTo: upper)
        .limit(12)
        .get();
    return qs.docs
        .where((d) => d.id != me)
        .map(
          (d) => UserProfile(
            uid: d.id,
            handle: d.data()['handle'] as String,
            displayName: d.data()['name'] as String?,
            photoUrl: d.data()['photo'] as String?,
            joinedAt: (d.data()['joinedAt'] as Timestamp?)?.toDate(),
          ),
        )
        .toList();
  }

  @override
  Future<UserProfile?> ensureProfile({String? handle}) async {
    final me = _me;
    if (me == null) return null;
    final doc = _userDoc(me);
    final existing = await doc.get();
    var effectiveHandle = handle?.trim().toLowerCase();
    var name = existing.data()?['name'] as String?;
    final photo = existing.data()?['photo'] as String?;

    if (existing.exists) {
      effectiveHandle ??= (existing.data()?['handle'] ?? me) as String;
    } else {
      effectiveHandle ??= me.length >= 6 ? me.substring(0, 6) : me;
      name ??= effectiveHandle;
    }
    await doc.set({
      'handle': effectiveHandle,
      'searchHandle': effectiveHandle,
      'name': name,
      'photo': photo,
      'joinedAt': existing.exists
          ? (existing.data()?['joinedAt'] ?? Timestamp.now())
          : Timestamp.now(),
    }, SetOptions(merge: true));

    return UserProfile(
      uid: me,
      handle: effectiveHandle,
      displayName: name,
      photoUrl: photo,
    );
  }

  @override
  Future<void> sendRequest(String toHandle) async {
    final me = _me;
    if (me == null) return;
    final prefix = toHandle.trim().toLowerCase();
    final qs = await _db
        .collection('users')
        .where('searchHandle', isEqualTo: prefix)
        .limit(1)
        .get();
    if (qs.docs.isEmpty) {
      throw FriendsException('No user with handle "$toHandle".');
    }
    final target = qs.docs.first;
    if (target.id == me) {
      throw FriendsException("That's you — try a different handle.");
    }
    final own = await _userDoc(me).get();
    final ownData = own.data() ?? const {};
    final pairId = friendPairId(me, target.id);
    await _db.collection('friendRequests').doc(pairId).set({
      'fromUid': me,
      'toUid': target.id,
      'fromHandle': (ownData['handle'] ?? me) as String,
      'fromDisplayName': ownData['name'],
      'state': 'pending',
      'at': Timestamp.now(),
    });
  }

  @override
  Future<void> acceptRequest(FriendRequest request) async {
    final me = _me;
    if (me == null || request.fromUid == me) return;
    // Fetch both public profiles BEFORE the transaction (plain reads).
    final own = await _userDoc(me).get();
    final ownData = own.data() ?? const {};
    final fromDoc = await _userDoc(request.fromUid).get();
    final fromData = fromDoc.data() ?? const {};
    await _db.runTransaction((tx) async {
      final reqRef = _db.collection('friendRequests').doc(request.pairId);
      final req = await tx.get(reqRef);
      if (!req.exists || req.data()?['state'] != 'pending') return;
      tx.update(reqRef, {'state': 'accepted'});
      // Symmetric denormalized friends docs (Phase 12 rules allow the
      // request flow only; friendship docs are per-user subcollections).
      tx.set(_userDoc(me).collection('friends').doc(request.fromUid), {
        'handle': request.fromHandle,
        'name': request.fromLabel,
        'photo': fromData['photo'],
        'since': Timestamp.now(),
      });
      tx.set(_userDoc(request.fromUid).collection('friends').doc(me), {
        'handle': (ownData['handle'] ?? me) as String,
        'name': ownData['name'] ?? me,
        'photo': ownData['photo'],
        'since': Timestamp.now(),
      });
    });
  }

  @override
  Future<void> declineRequest(FriendRequest request) async {
    final me = _me;
    if (me == null) return;
    await _db.runTransaction((tx) async {
      final reqRef = _db.collection('friendRequests').doc(request.pairId);
      final req = await tx.get(reqRef);
      if (!req.exists) return;
      tx.update(reqRef, {'state': 'declined'});
    });
  }

  @override
  Future<void> withdrawRequest(FriendRequest request) async {
    final me = _me;
    if (me == null || request.fromUid != me) return;
    await _db.collection('friendRequests').doc(request.pairId).delete();
  }

  @override
  Future<void> removeFriend(String friendUid) async {
    final me = _me;
    if (me == null) return;
    await _db.runTransaction((tx) async {
      tx.delete(_userDoc(me).collection('friends').doc(friendUid));
      tx.delete(_userDoc(friendUid).collection('friends').doc(me));
    });
  }
}
