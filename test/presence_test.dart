import 'package:calisthenics_app/features/presence/data/backend_presence_repositories.dart';
import 'package:calisthenics_app/features/presence/data/presence_repository.dart';
import 'package:calisthenics_app/features/presence/domain/training_presence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TrainingPresence p(String uid, {int minutesAgo = 5}) => TrainingPresence(
    uid: uid,
    handle: uid,
    exerciseName: 'Push-ups',
    dayName: 'Day 1 — Push + Core',
    startedAt: DateTime.now().toUtc().subtract(Duration(minutes: minutesAgo)),
  );

  test('combinePresenceWatches: empty → empty list', () async {
    expect(await combinePresenceWatches(const []).first, isEmpty);
  });

  test(
    'combinePresenceWatches: only live friends appear, newest first',
    () async {
      final repo = FakePresenceRepository();
      repo.setOnline(p('ayoub', minutesAgo: 10));
      repo.setOnline(p('sami', minutesAgo: 2));

      final combined = combinePresenceWatches([
        repo.watchPresence('ayoub', handle: 'ayoub'),
        repo.watchPresence('sami', handle: 'sami'),
        repo.watchPresence('ghost', handle: 'ghost'),
      ]);

      final emissions = <List<String>>[];
      final sub = combined.listen(
        (l) => emissions.add(l.map((x) => x.uid).toList()),
      );
      // The combined stream emits as each friend resolves — wait for the
      // settled state (all three watched).
      await pumpEventQueue();

      expect(emissions.last, ['sami', 'ayoub']); // ghost offline, newest first
      await sub.cancel();
    },
  );

  test('combinePresenceWatches: friend going offline drops out live', () async {
    final repo = FakePresenceRepository();
    repo.setOnline(p('ayoub'));

    final combined = combinePresenceWatches([
      repo.watchPresence('ayoub', handle: 'ayoub'),
    ]);

    final emissions = <List<String>>[];
    final sub = combined.listen(
      (list) => emissions.add(list.map((x) => x.uid).toList()),
    );
    // Initial + live event.
    await Future<void>.delayed(Duration.zero);
    repo.setOffline('ayoub');
    await Future<void>.delayed(Duration.zero);

    expect(emissions.first, ['ayoub']);
    expect(emissions.last, isEmpty);
    await sub.cancel();
  });

  test('goOnlineForTraining / stopTraining manage MY presence', () async {
    final repo = FakePresenceRepository(myUid: 'me', myHandle: 'dali');
    await repo.goOnlineForTraining(
      exerciseName: 'Squats',
      dayName: 'Day 2 — Legs',
    );
    final live = repo.myPresence;
    expect(live, isNotNull);
    expect(live!.exerciseName, 'Squats');
    expect(live.dayName, 'Day 2 — Legs');
    expect(live.handle, 'dali');

    await repo.stopTraining();
    expect(repo.myPresence, isNull);
  });

  test('NoOpPresenceRepository never fails and never lies', () async {
    const repo = NoOpPresenceRepository();
    await repo.goOnlineForTraining(exerciseName: 'x', dayName: 'y');
    await repo.stopTraining();
    expect(await repo.watchPresence('x', handle: 'x').first, isNull);
  });
}
