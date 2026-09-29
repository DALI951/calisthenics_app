import 'package:calisthenics_app/features/train_together/data/train_together_providers.dart';
import 'package:calisthenics_app/features/train_together/data/train_together_repository.dart';
import 'package:calisthenics_app/features/train_together/domain/live_pair_state.dart';
import 'package:calisthenics_app/features/train_together/domain/train_together_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.now().toUtc();

  LiveAthleteState athlete({
    String uid = 'me',
    String handle = 'dali',
    String exercise = 'Push-ups',
    int set = 2,
    int total = 4,
    LivePhase phase = LivePhase.working,
    int ageSeconds = 0,
    bool online = true,
  }) => LiveAthleteState(
    uid: uid,
    handle: handle,
    exerciseName: exercise,
    setNumber: set,
    totalSets: total,
    phase: phase,
    updatedAt: now.subtract(Duration(seconds: ageSeconds)),
    online: online,
  );

  LivePairState pair(
    LiveAthleteState? me,
    LiveAthleteState? partner, {
    DateTime? restStartedAt,
    int rest = 90,
  }) => LivePairState(
    me: me,
    partner: partner,
    restSeconds: rest,
    restStartedAt: restStartedAt,
  );

  test('trainPairId is symmetric and stable', () {
    expect(trainPairId('b', 'a'), trainPairId('a', 'b'));
    expect(trainPairId('a', 'b'), isNot(trainPairId('a', 'c')));
  });

  test('both working → I see "go" and no wait', () {
    final p = pair(athlete(), athlete(uid: 'ayoub', handle: 'ayoub'));
    expect(TrainTogetherEngine.phaseForMe(p), LivePhase.working);
    expect(TrainTogetherEngine.statusLine(p), contains('ayoub'));
  });

  test('I finished my set, partner still going → waiting (no pressure)', () {
    final p = pair(
      athlete(phase: LivePhase.waiting),
      athlete(uid: 'ayoub', handle: 'ayoub'),
    );
    expect(TrainTogetherEngine.phaseForMe(p), LivePhase.waiting);
    expect(TrainTogetherEngine.statusLine(p), contains('waiting for @ayoub'));
  });

  test('both finished → REST, countdown identical on both phones', () {
    final started = now.subtract(const Duration(seconds: 30));
    final p = pair(
      athlete(phase: LivePhase.waiting),
      athlete(uid: 'ayoub', handle: 'ayoub', phase: LivePhase.resting),
      restStartedAt: started,
    );
    expect(TrainTogetherEngine.phaseForMe(p), LivePhase.resting);
    expect(p.restRunning, isTrue);
    expect(p.restRemaining!.inSeconds, inInclusiveRange(58, 60));
    expect(TrainTogetherEngine.statusLine(p), contains('resting together'));
  });

  test('partner never joined → keep going, no fake rest, honest wording', () {
    final p = pair(athlete(phase: LivePhase.waiting), null);
    expect(p.restRunning, isFalse);
    expect(TrainTogetherEngine.phaseForMe(p), LivePhase.waiting);
    expect(
      TrainTogetherEngine.statusLine(p),
      contains('Waiting for your partner'),
    );
  });

  test('partner crashed mid-set → "away" wording, no shaming', () {
    final p = pair(
      athlete(phase: LivePhase.waiting),
      athlete(uid: 'ayoub', handle: 'ayoub', ageSeconds: 600, online: false),
    );
    final line = TrainTogetherEngine.statusLine(p);
    expect(line, contains('away'));
    expect(line, contains('Keep going or wait here'));
  });

  test('shouldOfferSoloContinue: only for a partner who WAS here', () {
    final here = pair(
      athlete(),
      athlete(uid: 'ayoub', handle: 'ayoub', ageSeconds: 5),
    );
    // Partner present → never nudge.
    expect(TrainTogetherEngine.shouldOfferSoloContinue(here), isFalse);
    // Partner never joined → nothing to leave behind, no button.
    expect(
      TrainTogetherEngine.shouldOfferSoloContinue(pair(athlete(), null)),
      isFalse,
    );
    // Partner crashed / gone past grace → offer the way out.
    final gone = pair(
      athlete(),
      athlete(uid: 'ayoub', handle: 'ayoub', ageSeconds: 60, online: false),
    );
    expect(TrainTogetherEngine.shouldOfferSoloContinue(gone), isTrue);
  });

  test('stale nodes (crashed client) count as offline', () {
    expect(TrainTogetherEngine.isStale(null, now), isTrue);
    expect(TrainTogetherEngine.isStale(athlete(ageSeconds: 30), now), isFalse);
    expect(TrainTogetherEngine.isStale(athlete(ageSeconds: 600), now), isTrue);
  });

  test('exercise label shows exercise + set n/total', () {
    final p = pair(athlete(set: 2, total: 4), athlete(uid: 'ayoub'));
    expect(p.exerciseLabel, 'Push-ups — Set 2/4');
  });

  test('finished session says both finished, no winner talk', () {
    final p = pair(
      athlete(phase: LivePhase.finished),
      athlete(uid: 'ayoub', handle: 'ayoub', phase: LivePhase.finished),
    );
    final line = TrainTogetherEngine.statusLine(p);
    expect(line, contains('Both of you finished'));
    expect(line.toLowerCase(), isNot(contains('loser')));
  });

  test('fake repository syncs two devices over one shared backend', () async {
    final mine = FakeTrainTogetherRepository(myUid: 'me', myHandle: 'dali');
    final pairId = trainPairId('me', 'ayoub');
    mine.simulatePartner(
      pairId,
      'ayoub',
      athlete(uid: 'ayoub', handle: 'ayoub', phase: LivePhase.working),
    );

    final seen = <LivePhase>[];
    final sub = mine.watchPartner(pairId, 'ayoub').listen((s) {
      if (s != null) seen.add(s.phase);
    });
    await Future<void>.delayed(Duration.zero);

    await mine.publishMe(pairId, athlete(phase: LivePhase.waiting, set: 3));
    await Future<void>.delayed(Duration.zero);
    expect(seen.last, LivePhase.working);

    mine.simulatePartner(
      pairId,
      'ayoub',
      athlete(uid: 'ayoub', handle: 'ayoub', phase: LivePhase.resting, set: 3),
    );
    await Future<void>.delayed(Duration.zero);
    expect(seen.last, LivePhase.resting);

    // Crash → node removed → partner gone.
    mine.dropPartner(pairId, 'ayoub');
    await Future<void>.delayed(Duration.zero);
    expect(await mine.watchPartner(pairId, 'ayoub').first, isNull);
    await sub.cancel();
  });

  test('cheers flow to the partner feed', () async {
    final mine = FakeTrainTogetherRepository(myUid: 'me', myHandle: 'dali');
    final pairId = trainPairId('me', 'ayoub');
    await mine.sendCheer(pairId, '💪');
    final cheers = await mine.watchCheers(pairId).first;
    expect(cheers.single.emoji, '💪');
    expect(cheers.single.fromHandle, 'dali');
  });

  test('live state survives storage round-trip', () {
    final s = athlete(set: 2, total: 5, phase: LivePhase.resting);
    final back = LiveAthleteState.fromStorage(
      s.toStorage().cast<Object?, Object?>(),
    )!;
    expect(back.setNumber, 2);
    expect(back.totalSets, 5);
    expect(back.phase, LivePhase.resting);
    expect(back.exerciseName, 'Push-ups');
  });
}
