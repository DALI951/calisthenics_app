import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

import '../domain/live_pair_state.dart';
import 'train_together_repository.dart';

/// RTDB Train-Together: `liveSessions/{pairId}/{uid}` — each client writes
/// ONLY its own node, with `onDisconnect -> null` so a crashed phone never
/// leaves a ghost "still training" state. No video, no camera, no audio.
class RtdbTrainTogetherRepository implements TrainTogetherRepository {
  RtdbTrainTogetherRepository(this._db, this._myUid, {this.myHandle = 'me'});

  final FirebaseDatabase _db;
  final String? _myUid;
  final String myHandle;

  String get _me => _myUid ?? 'anonymous';
  DatabaseReference _ref(String pairId, String uid) =>
      _db.ref('liveSessions/$pairId/$uid');

  @override
  Stream<LiveAthleteState?> watchPartner(String pairId, String partnerUid) =>
      _ref(pairId, partnerUid).onValue.map((e) {
        final v = e.snapshot.value;
        if (v is! Map) return null;
        return LiveAthleteState.fromStorage(v.cast<Object?, Object?>());
      });

  @override
  Stream<LiveAthleteState?> watchMe(String pairId) =>
      _ref(pairId, _me).onValue.map((e) {
        final v = e.snapshot.value;
        if (v is! Map) return null;
        return LiveAthleteState.fromStorage(v.cast<Object?, Object?>());
      });

  @override
  Future<void> publishMe(String pairId, LiveAthleteState state) async {
    final ref = _ref(pairId, _me);
    await ref.onDisconnect().set(null);
    await ref.set({
      ...state.toStorage(),
      'uid': _me,
      'handle': myHandle,
      'at': ServerValue.timestamp,
    });
    // Both phones read the same rest length from the pair meta node so the
    // countdown cannot drift.
    final meta = _db.ref('liveSessions/$pairId/meta');
    await meta.onDisconnect().remove();
    await meta.set({'restSeconds': 90, 'restStartedAt': ServerValue.timestamp});
  }

  @override
  Future<void> leave(String pairId) async {
    final ref = _ref(pairId, _me);
    await ref.onDisconnect().remove();
    await ref.remove();
  }

  @override
  Stream<List<Cheer>> watchCheers(String pairId) =>
      _db.ref('liveSessions/$pairId/cheers').onValue.map((e) {
        final v = e.snapshot.value;
        if (v is! Map) return <Cheer>[];
        return [
          for (final entry in v.entries)
            if (entry.value is Map)
              Cheer(
                fromHandle:
                    (entry.value as Map)['handle'] as String? ?? 'friend',
                emoji: (entry.value as Map)['emoji'] as String? ?? '💪',
                at: DateTime.fromMillisecondsSinceEpoch(
                  ((entry.value as Map)['at'] as num?)?.toInt() ?? 0,
                  isUtc: true,
                ),
              ),
        ]..sort((a, b) => a.at.compareTo(b.at));
      });

  @override
  Future<void> sendCheer(String pairId, String emoji) async {
    await _db.ref('liveSessions/$pairId/cheers/$_me').set({
      'handle': myHandle,
      'emoji': emoji,
      'at': ServerValue.timestamp,
    });
    // Cheers are ephemeral — clear them shortly after so the feed stays clean.
    unawaited(
      Future<void>.delayed(const Duration(seconds: 8), () async {
        await _db.ref('liveSessions/$pairId/cheers/$_me').remove();
      }),
    );
  }

  @override
  int restSeconds(String pairId) => 90;

  @override
  DateTime? restStartedAt(String pairId) => null;
}
