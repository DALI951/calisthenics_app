import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

import '../domain/training_presence.dart';
import 'presence_repository.dart';

/// RTDB presence: `presence/{uid}` = {handle, exercise, day, at} with
/// `onDisconnect → null`, so presence is ALWAYS honest — no ghost "training
/// now" badges after a crash.
class RtdbPresenceRepository implements PresenceRepository {
  RtdbPresenceRepository(this._db, this._myUid);

  final FirebaseDatabase _db;
  final String? _myUid;

  DatabaseReference _ref(String uid) => _db.ref('presence/$uid');

  @override
  Stream<TrainingPresence?> watchPresence(
    String uid, {
    required String handle,
  }) {
    return _ref(uid).onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return null;
      final at = value['at'];
      return TrainingPresence(
        uid: uid,
        handle: (value['handle'] as String?) ?? handle,
        exerciseName: (value['exercise'] as String?) ?? '',
        dayName: (value['day'] as String?) ?? '',
        startedAt: at is num
            ? DateTime.fromMillisecondsSinceEpoch(at.toInt(), isUtc: true)
            : DateTime.now().toUtc(),
      );
    });
  }

  @override
  Future<void> goOnlineForTraining({
    required String exerciseName,
    required String dayName,
  }) async {
    final me = _myUid;
    if (me == null) return;
    final ref = _ref(me);
    // Presence must die WITH the client — onDisconnect is the whole point
    // of choosing RTDB over Firestore here.
    await ref.onDisconnect().set(null);
    await ref.set({
      'handle': me,
      'exercise': exerciseName,
      'day': dayName,
      'at': ServerValue.timestamp,
    });
  }

  @override
  Future<void> stopTraining() async {
    final me = _myUid;
    if (me == null) return;
    final ref = _ref(me);
    await ref.onDisconnect().remove();
    await ref.set(null);
  }
}

/// In-memory presence for tests and the local-only fallback.
class FakePresenceRepository implements PresenceRepository {
  FakePresenceRepository({String? myUid, this.myHandle = 'me'})
    : _myUid = myUid ?? 'local-me';

  final String _myUid;
  final String myHandle;
  final _presences = <String, TrainingPresence>{};
  final _controllers = <String, StreamController<TrainingPresence?>>{};

  StreamController<TrainingPresence?> _controllerFor(String uid) =>
      _controllers.putIfAbsent(uid, () {
        final c = StreamController<TrainingPresence?>.broadcast();
        c.onListen = () => c.add(_presences[uid]);
        return c;
      });

  /// Test helper: simulate a friend going live.
  void setOnline(TrainingPresence presence) {
    _presences[presence.uid] = presence;
    _controllers[presence.uid]?.add(presence);
  }

  /// Test helper: simulate a friend going offline.
  void setOffline(String uid) {
    _presences.remove(uid);
    _controllers[uid]?.add(null);
  }

  @override
  Stream<TrainingPresence?> watchPresence(
    String uid, {
    required String handle,
  }) async* {
    yield _presences[uid];
    yield* _controllerFor(uid).stream;
  }

  @override
  Future<void> goOnlineForTraining({
    required String exerciseName,
    required String dayName,
  }) async {
    _presences[_myUid] = TrainingPresence(
      uid: _myUid,
      handle: myHandle,
      exerciseName: exerciseName,
      dayName: dayName,
      startedAt: DateTime.now().toUtc(),
    );
    _controllers[_myUid]?.add(_presences[_myUid]);
  }

  @override
  Future<void> stopTraining() async {
    _presences.remove(_myUid);
    _controllers[_myUid]?.add(null);
  }

  TrainingPresence? get myPresence => _presences[_myUid];
}
