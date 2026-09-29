import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/services/backend_status.dart';
import '../../auth/data/auth_providers.dart';
import '../../workout_session/data/workout_history_repository.dart';
import '../domain/challenge.dart';
import '../domain/challenge_engine.dart';
import 'challenge_repository.dart';
import 'firestore_challenge_repository.dart';

part 'challenges_providers.g.dart';

/// Challenges backend seam — Firestore when available, in-memory otherwise.
@Riverpod(keepAlive: true)
ChallengeRepository challengeRepository(Ref ref) {
  final status = ref.watch(backendStatusProvider);
  final uid = ref.watch(authControllerProvider).value?.id;
  return switch (status) {
    BackendStatus.available || BackendStatus.emulator =>
      FirestoreChallengeRepository(FirebaseFirestore.instance, uid),
    BackendStatus.unavailable => FakeChallengeRepository(myUid: uid),
  };
}

/// All challenges I am part of.
@Riverpod(keepAlive: true)
Stream<List<Challenge>> myChallenges(Ref ref) =>
    ref.watch(challengeRepositoryProvider).watchMyChallenges();

/// Live progress for a challenge, with the effective status applied
/// (accepted → active → expired/completed over time).
@Riverpod(keepAlive: true)
Stream<ChallengeView> challengeView(Ref ref, String challengeId) {
  final repo = ref.watch(challengeRepositoryProvider);
  final myUid = ref.watch(authControllerProvider).value?.id;
  final history = ref.watch(workoutHistoryRepositoryProvider).value ?? const [];
  return repo.watchMyChallenges().asyncExpand((all) async* {
    final raw = all.where((c) => c.id == challengeId).firstOrNull;
    if (raw == null) {
      yield ChallengeView.missing();
      return;
    }
    final now = DateTime.now().toUtc();
    await for (final progress in repo.watchProgress(challengeId)) {
      final settled = ChallengeEngine.settle(raw, {
        for (final p in progress) p.uid: p,
      }, now: now);
      // Recompute MY progress from local history (authoritative for me) and
      // publish it so friends see it live.
      if (myUid != null) {
        final mine = ChallengeEngine.progressFor(
          raw,
          myUid,
          history,
          metric: ChallengeEngine.metricFor(raw),
          now: now,
        );
        final published = progress.where((p) => p.uid == myUid).firstOrNull;
        if (published?.value != mine.value ||
            published?.evidenceSessionIds.length !=
                mine.evidenceSessionIds.length) {
          unawaited(repo.publishProgress(mine));
        }
      }
      yield ChallengeView(
        challenge: settled,
        myUid: myUid ?? '',
        progress: {
          for (final p in progress)
            if (p.uid != myUid) p.uid: p,
        },
        myProgress: myUid == null
            ? null
            : ChallengeEngine.progressFor(
                raw,
                myUid,
                history,
                metric: ChallengeEngine.metricFor(raw),
                now: now,
              ),
      );
    }
  });
}

/// Everything the challenge detail screen needs in one object.
class ChallengeView {
  const ChallengeView({
    required this.challenge,
    required this.myUid,
    required this.progress,
    required this.myProgress,
    this.missing = false,
  });

  const ChallengeView.missing()
    : challenge = null,
      myUid = '',
      progress = const {},
      myProgress = null,
      missing = true;

  final Challenge? challenge;
  final String myUid;
  final Map<String, ChallengeProgress> progress;
  final ChallengeProgress? myProgress;
  final bool missing;

  bool get isCreator => challenge?.creatorUid == myUid;
  bool get isOpponent => challenge?.opponentUid == myUid;

  /// Live progress for both sides (my value wins for my own side — the
  /// published copy may lag a second behind).
  int? valueOf(String uid) =>
      uid == myUid ? myProgress?.value : progress[uid]?.value;

  ChallengeProgress? get myProgressOrNull => myProgress;
}
