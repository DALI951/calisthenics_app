import 'package:calisthenics_app/features/achievements/data/achievements_providers.dart';
import 'package:calisthenics_app/features/achievements/domain/achievement.dart';
import 'package:calisthenics_app/features/achievements/domain/achievement_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fresh = AchievementStats();

  test('nothing is earned on a brand new account', () {
    expect(AchievementEngine.newlyEarned(fresh, const {}), isEmpty);
  });

  test('first workout unlocks exactly one achievement', () {
    final earned = AchievementEngine.newlyEarned(
      const AchievementStats(workoutsCompleted: 1),
      const {},
    );
    expect(earned.map((a) => a.id), ['workouts_1']);
  });

  test('no achievement spam: an earned achievement is awarded ONCE', () {
    const stats = AchievementStats(workoutsCompleted: 1);
    final first = AchievementEngine.newlyEarned(stats, const {});
    expect(first.length, 1);
    final already = first.map((a) => a.id).toSet();
    final second = AchievementEngine.newlyEarned(stats, already);
    expect(second, isEmpty);
  });

  test('fake repository never double-awards, even if called twice', () async {
    final repo = FakeAchievementRepository();
    const stats = AchievementStats(workoutsCompleted: 10);
    final first = AchievementEngine.newlyEarned(stats, const {});
    await repo.unlock(first, DateTime.utc(2026, 1, 1));
    final held = (await repo.watchUnlocked().first);
    expect(held.map((h) => h.id).toSet(), {'workouts_1', 'workouts_10'});

    // Second pass with the ids now held → nothing new.
    final second = AchievementEngine.newlyEarned(
      stats,
      held.map((h) => h.id).toSet(),
    );
    expect(second, isEmpty);
    await repo.unlock(second, DateTime.utc(2026, 1, 2));
    expect((await repo.watchUnlocked().first).length, 2);
  });

  test('reps unlock the exact rep achievements (25/50 push-ups)', () {
    final p25 = AchievementEngine.newlyEarned(
      const AchievementStats(bestPushups: 25),
      const {},
    );
    expect(p25.map((a) => a.id), contains('pushup_25'));
    expect(p25.map((a) => a.id), isNot(contains('pushup_50')));

    final p50 = AchievementEngine.newlyEarned(
      const AchievementStats(bestPushups: 50),
      const {},
    );
    expect(p50.map((a) => a.id), containsAll(['pushup_25', 'pushup_50']));
  });

  test('plank achievements use seconds, not reps', () {
    final a = AchievementEngine.newlyEarned(
      const AchievementStats(bestPlankSeconds: 60),
      const {},
    );
    expect(a.map((x) => x.id), contains('plank_60'));
    expect(a.map((x) => x.id), isNot(contains('plank_120')));
  });

  test('streaks use the LONGEST streak ever, not just today', () {
    final a = AchievementEngine.newlyEarned(
      const AchievementStats(currentStreak: 1, longestStreak: 7),
      const {},
    );
    expect(a.map((x) => x.id), contains('streak_7'));
  });

  test('hidden achievements stay hidden until earned', () {
    const nothing = AchievementStats();
    expect(
      AchievementEngine.visible(nothing, const {}).map((a) => a.id),
      isNot(contains('weekly_goal_4')),
    );
    final earned = AchievementEngine.visible(
      const AchievementStats(weeksWithGoalMet: 4),
      const {'weekly_goal_4'},
    );
    expect(earned.map((a) => a.id), contains('weekly_goal_4'));
  });

  test('progress bar never exceeds 1 and is monotonic', () {
    final a = Achievements.byId('workouts_25');
    expect(AchievementEngine.progressOf(a, const AchievementStats()), 0);
    expect(
      AchievementEngine.progressOf(
        a,
        const AchievementStats(workoutsCompleted: 12),
      ),
      closeTo(0.48, 0.01),
    );
    expect(
      AchievementEngine.progressOf(
        a,
        const AchievementStats(workoutsCompleted: 999),
      ),
      1,
    );
  });

  test('every achievement id is unique and has XP', () {
    final ids = Achievements.all.map((a) => a.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(Achievements.all.every((a) => a.xp > 0), isTrue);
    expect(Achievements.all.every((a) => a.target > 0), isTrue);
  });

  test('XP level curve is monotonic and gentler than linear', () {
    expect(XpEngine.levelForXp(0), 1);
    expect(XpEngine.levelForXp(149), 1);
    expect(XpEngine.levelForXp(150), 2);
    expect(XpEngine.levelForXp(450), 3);
    expect(XpEngine.levelForXp(900), 4);
    for (var lvl = 2; lvl < 20; lvl++) {
      expect(
        XpEngine.xpForLevel(lvl + 1),
        greaterThan(XpEngine.xpForLevel(lvl)),
      );
      // Each level costs more than the last — no late-game free levels.
      expect(
        XpEngine.xpForLevel(lvl + 1) - XpEngine.xpForLevel(lvl),
        greaterThan(XpEngine.xpForLevel(lvl) - XpEngine.xpForLevel(lvl - 1)),
      );
    }
  });

  test('level progress is a clean 0..1 with a sane XP-to-next', () {
    expect(XpEngine.levelProgress(0), 0);
    expect(XpEngine.levelProgress(150), 0);
    expect(XpEngine.levelProgress(300), inInclusiveRange(0.49, 0.51));
    expect(XpEngine.xpToNextLevel(0), 150);
    expect(XpEngine.xpToNextLevel(300), 150);
  });

  test('XP is ONLY from training — opening the app pays nothing', () {
    // No app-open input exists anywhere in the API: XP comes from session
    // estimates and achievements, both training-derived.
    expect(XpEngine.totalFromSessions(const []), 0);
    expect(XpEngine.totalFromSessions([120, 80]), 200);
  });

  test('unlocked achievement storage round-trips with provenance', () {
    final u = UnlockedAchievement(
      id: 'workouts_1',
      earnedAt: DateTime.utc(2026, 1, 5),
      xp: 50,
    );
    final back = UnlockedAchievement.fromStorage(
      u.toStorage().cast<Object?, Object?>(),
    );
    expect(back.id, 'workouts_1');
    expect(back.xp, 50);
    expect(back.decidedBy, 'engine-v1');
  });
}
