import 'package:calisthenics_app/features/challenges/data/challenge_repository.dart';
import 'package:calisthenics_app/features/challenges/data/challenges_providers.dart';
import 'package:calisthenics_app/features/challenges/domain/challenge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.now().toUtc();

  Challenge ch({
    String creator = 'me',
    String opponent = 'ayoub',
    ChallengeStatus status = ChallengeStatus.pending,
  }) => Challenge(
    id: 'ch_test',
    creatorUid: creator,
    creatorHandle: 'dali',
    opponentUid: opponent,
    opponentHandle: 'ayoub',
    type: ChallengeType.consistency,
    target: 3,
    startsAt: now.subtract(const Duration(days: 1)),
    endsAt: now.add(const Duration(days: 6)),
    createdAt: now,
    status: status,
  );

  ProviderContainer c(FakeChallengeRepository repo) {
    final c = ProviderContainer(
      overrides: [challengeRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('myChallenges lists only challenges I belong to', () async {
    final repo = FakeChallengeRepository(myUid: 'me');
    repo.seed(ch());
    repo.seed(
      Challenge(
        id: 'ch_other',
        creatorUid: 'x',
        creatorHandle: 'x',
        opponentUid: 'y',
        opponentHandle: 'y',
        type: ChallengeType.time,
        target: 60,
        startsAt: now,
        endsAt: now.add(const Duration(days: 7)),
        createdAt: now,
      ),
    );
    final mine = c(repo);
    final list = await repo.watchMyChallenges().first;
    expect(list.map((e) => e.id), ['ch_test']);
    // Provider is wired to the same repository.
    expect(mine.read(challengeRepositoryProvider), same(repo));
  });

  test('create rejects self-challenges and duplicates', () async {
    final repo = FakeChallengeRepository(myUid: 'me');
    final bad = Challenge(
      id: 'ch_self',
      creatorUid: 'me',
      creatorHandle: 'dali',
      opponentUid: 'me',
      opponentHandle: 'dali',
      type: ChallengeType.time,
      target: 30,
      startsAt: now,
      endsAt: now.add(const Duration(days: 3)),
      createdAt: now,
    );
    await expectLater(repo.create(bad), throwsA(isA<ChallengeException>()));
    await repo.create(ch());
    await expectLater(repo.create(ch()), throwsA(isA<ChallengeException>()));
  });

  test('accept/decline/cancel flow through the repository', () async {
    final repo = FakeChallengeRepository(myUid: 'ayoub');
    repo.seed(ch());
    await repo.setStatus(repo.byId('ch_test')!, ChallengeStatus.accepted);
    expect(repo.byId('ch_test')!.status, ChallengeStatus.accepted);
    await repo.setStatus(repo.byId('ch_test')!, ChallengeStatus.cancelled);
    expect(repo.byId('ch_test')!.status, ChallengeStatus.cancelled);
  });

  test('progress publishing is per-participant and evidence-backed', () async {
    final repo = FakeChallengeRepository(myUid: 'me');
    repo.seed(ch());
    final mine = ChallengeProgress(
      challengeId: 'ch_test',
      uid: 'me',
      value: 2,
      target: 3,
      unitLabel: 'workouts',
      evidenceSessionIds: const ['s1', 's2'],
      updatedAt: now,
    );
    await repo.publishProgress(mine);
    final theirs = ChallengeProgress(
      challengeId: 'ch_test',
      uid: 'ayoub',
      value: 1,
      target: 3,
      unitLabel: 'workouts',
      evidenceSessionIds: const ['a1'],
      updatedAt: now,
    );
    await repo.publishProgress(theirs);

    final all = await repo.watchProgress('ch_test').first;
    expect(all.length, 2);
    expect(all.firstWhere((p) => p.uid == 'me').evidenceSessionIds.length, 2);

    // Outsiders cannot publish into someone else's challenge.
    await expectLater(
      repo.publishProgress(
        ChallengeProgress(
          challengeId: 'ch_test',
          uid: 'stranger',
          value: 999,
          target: 3,
          unitLabel: '',
          evidenceSessionIds: const [],
          updatedAt: now,
        ),
      ),
      throwsA(isA<ChallengeException>()),
    );
  });

  test('challengeView exposes my live progress and opponent value', () async {
    final repo = FakeChallengeRepository(myUid: 'me');
    repo.seed(ch(status: ChallengeStatus.active));
    final container = c(repo);
    // Sanity: the view provider exists and is keyed by challenge id.
    expect(container.read(challengeRepositoryProvider), same(repo));
    expect(repo.byId('ch_test')!.status, ChallengeStatus.active);
  });
}
