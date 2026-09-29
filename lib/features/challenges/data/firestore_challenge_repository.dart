import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/challenge.dart';
import 'challenge_repository.dart';

/// Firestore challenges:
///   challenges/{id}                       — definition + status + result
///   challenges/{id}/progress/{uid}        — self-published evidence-backed
class FirestoreChallengeRepository implements ChallengeRepository {
  FirestoreChallengeRepository(this._db, this._myUid);

  final FirebaseFirestore _db;
  final String? _myUid;

  @override
  Stream<List<Challenge>> watchMyChallenges() {
    final uid = _myUid;
    if (uid == null) return Stream.value(const []);
    final mine = _db
        .collection('challenges')
        .where('creatorUid', isEqualTo: uid)
        .snapshots();
    final theirs = _db
        .collection('challenges')
        .where('opponentUid', isEqualTo: uid)
        .snapshots();
    return Rx.combineLatest2(mine, theirs, (a, b) {
      final all =
          [
              ...a.docs,
              ...b.docs,
            ].map((d) => Challenge.fromStorage(d.data())).toList()
            ..sort((x, y) => y.endsAt.compareTo(x.endsAt));
      return all;
    });
  }

  @override
  Stream<List<ChallengeProgress>> watchProgress(String challengeId) => _db
      .collection('challenges')
      .doc(challengeId)
      .collection('progress')
      .snapshots()
      .map(
        (s) =>
            s.docs.map((d) => ChallengeProgress.fromStorage(d.data())).toList(),
      );

  @override
  Future<Challenge> create(Challenge challenge) async {
    await _db
        .collection('challenges')
        .doc(challenge.id)
        .set(challenge.toStorage());
    return challenge;
  }

  @override
  Future<void> publishProgress(ChallengeProgress progress) async {
    await _db
        .collection('challenges')
        .doc(progress.challengeId)
        .collection('progress')
        .doc(progress.uid)
        .set(progress.toStorage());
  }

  @override
  Future<void> setStatus(Challenge challenge, ChallengeStatus next) async {
    await _db.collection('challenges').doc(challenge.id).update({
      'status': next.name,
    });
  }

  @override
  Future<void> finalize(Challenge challenge) async {
    await _db.collection('challenges').doc(challenge.id).set({
      'status': challenge.status.name,
      'result': challenge.result?.toStorage(),
    }, SetOptions(merge: true));
  }
}

/// Minimal combineLatest2 for two Firestore snapshot streams (no rxdart dep).
class Rx {
  static Stream<R> combineLatest2<T1, T2, R>(
    Stream<T1> a,
    Stream<T2> b,
    R Function(T1, T2) combine,
  ) {
    return Stream.multi((c) {
      T1? lastA;
      T2? lastB;
      var hasA = false;
      var hasB = false;
      final subA = a.listen((v) {
        lastA = v;
        hasA = true;
        if (hasB) c.add(combine(lastA as T1, lastB as T2));
      }, onError: c.addError);
      final subB = b.listen((v) {
        lastB = v;
        hasB = true;
        if (hasA) c.add(combine(lastA as T1, lastB as T2));
      }, onError: c.addError);
      c.onCancel = () async {
        await subA.cancel();
        await subB.cancel();
      };
    });
  }
}
