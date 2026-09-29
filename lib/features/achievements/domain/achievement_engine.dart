import 'achievement.dart';

/// Unlock + XP rules (spec §25 "avoid achievement spam", §26 "training is the
/// source of progress").
class AchievementEngine {
  const AchievementEngine._();

  /// Achievements a user already holds. Unlocking is idempotent — an
  /// achievement can only ever be awarded once.
  static List<Achievement> newlyEarned(
    AchievementStats stats,
    Set<String> alreadyUnlocked,
  ) {
    final out = <Achievement>[];
    for (final a in Achievements.all) {
      if (alreadyUnlocked.contains(a.id)) continue;
      if (a.isEarned(stats)) out.add(a);
    }
    out.sort((a, b) => a.target.compareTo(b.target));
    return out;
  }

  /// All achievements that should be visible, given progress.
  static List<Achievement> visible(
    AchievementStats stats,
    Set<String> unlocked,
  ) => Achievements.all
      .where((a) => !a.hidden || unlocked.contains(a.id) || a.isEarned(stats))
      .toList();

  static double progressOf(Achievement a, AchievementStats stats) {
    if (a.target == 0) return 1;
    return (a.progress(stats) / a.target).clamp(0, 1);
  }
}

/// Level curve. Deliberately gentle and capped — no late-game treadmill and
/// no "open the app to level up" (spec §26).
class XpEngine {
  const XpEngine._();

  /// XP needed to reach level n (cumulative), quadratic but slow:
  /// L1 0, L2 150, L3 450, L4 900, L5 1500… each level costs more than the
  /// last, so late levels are earned, never handed out.
  static int xpForLevel(int level) {
    if (level <= 1) return 0;
    return 150 * (level - 1) * level ~/ 2;
  }

  static int levelForXp(int xp) {
    var level = 1;
    while (level < 50 && xp >= xpForLevel(level + 1)) {
      level++;
    }
    return level;
  }

  /// Progress within the current level (0..1).
  static double levelProgress(int xp) {
    final level = levelForXp(xp);
    final floorXp = xpForLevel(level);
    final next = xpForLevel(level + 1);
    if (next == floorXp) return 1;
    return ((xp - floorXp) / (next - floorXp)).clamp(0, 1);
  }

  static int xpToNextLevel(int xp) {
    final level = levelForXp(xp);
    return xpForLevel(level + 1) - xp;
  }

  /// XP already banked from finished sessions (5/set, 2/min, 25 bonus) plus
  /// achievement rewards. Only TRAINING pays — opening the app pays nothing.
  static int totalFromSessions(Iterable<int> sessionXp) =>
      sessionXp.fold(0, (a, b) => a + b);
}
