import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/services/backend_status.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/achievement.dart';
import '../domain/achievement_engine.dart';

part 'achievements_providers.g.dart';

/// An achievement the user holds, with proof. `decidedBy` records WHO
/// awarded it — clients may only self-award what the local engine verified;
/// anything else requires a trusted backend (spec §28 security rules).
class UnlockedAchievement {
  const UnlockedAchievement({
    required this.id,
    required this.earnedAt,
    required this.xp,
    this.decidedBy = 'engine-v1',
  });

  final String id;
  final DateTime earnedAt;
  final int xp;
  final String decidedBy;

  Map<String, Object?> toStorage() => {
    'id': id,
    'earnedAt': earnedAt.millisecondsSinceEpoch,
    'xp': xp,
    'decidedBy': decidedBy,
  };

  static UnlockedAchievement fromStorage(Map<Object?, Object?> raw) =>
      UnlockedAchievement(
        id: raw['id'] as String? ?? '',
        earnedAt: DateTime.fromMillisecondsSinceEpoch(
          (raw['earnedAt'] as num?)?.toInt() ?? 0,
          isUtc: true,
        ),
        xp: (raw['xp'] as num?)?.toInt() ?? 0,
        decidedBy: raw['decidedBy'] as String? ?? 'engine-v1',
      );
}

abstract class AchievementRepository {
  Stream<List<UnlockedAchievement>> watchUnlocked();
  Future<void> unlock(List<Achievement> earned, DateTime now);
}

class FakeAchievementRepository implements AchievementRepository {
  final _items = <UnlockedAchievement>[];
  final _controller = StreamController<List<UnlockedAchievement>>.broadcast();

  @override
  Stream<List<UnlockedAchievement>> watchUnlocked() async* {
    yield List.unmodifiable(_items);
    yield* _controller.stream;
  }

  @override
  Future<void> unlock(List<Achievement> earned, DateTime now) async {
    final known = _items.map((i) => i.id).toSet();
    var changed = false;
    for (final a in earned) {
      if (known.contains(a.id)) continue; // never twice
      known.add(a.id);
      _items.add(UnlockedAchievement(id: a.id, earnedAt: now, xp: a.xp));
      changed = true;
    }
    if (changed) _controller.add(List.unmodifiable(_items));
  }
}

class FirestoreAchievementRepository implements AchievementRepository {
  FirestoreAchievementRepository(this._db, this._uid);
  final FirebaseFirestore _db;
  final String _uid;

  @override
  Stream<List<UnlockedAchievement>> watchUnlocked() => _db
      .collection('userAchievements')
      .doc(_uid)
      .collection('achievements')
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            UnlockedAchievement.fromStorage(d.data().cast<Object?, Object?>()),
        ]..sort((a, b) => b.earnedAt.compareTo(a.earnedAt)),
      );

  @override
  Future<void> unlock(List<Achievement> earned, DateTime now) async {
    final batch = _db.batch();
    for (final a in earned) {
      // Transaction-free but idempotent: the doc id IS the achievement id, so
      // a duplicate write can never double-award.
      batch.set(
        _db
            .collection('userAchievements')
            .doc(_uid)
            .collection('achievements')
            .doc(a.id),
        UnlockedAchievement(id: a.id, earnedAt: now, xp: a.xp).toStorage(),
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }
}

@Riverpod(keepAlive: true)
AchievementRepository achievementRepository(Ref ref) {
  final status = ref.watch(backendStatusProvider);
  final uid = ref.watch(authControllerProvider).value?.id;
  return switch (status) {
    BackendStatus.available || BackendStatus.emulator when uid != null =>
      FirestoreAchievementRepository(FirebaseFirestore.instance, uid),
    _ => FakeAchievementRepository(),
  };
}

@Riverpod(keepAlive: true)
Stream<List<UnlockedAchievement>> unlockedAchievements(Ref ref) =>
    ref.watch(achievementRepositoryProvider).watchUnlocked();

/// Checks stats against the catalogue, awards anything new, and returns the
/// freshly earned ones so the UI can celebrate exactly once.
@Riverpod(keepAlive: true)
class AwardAchievements extends _$AwardAchievements {
  @override
  void build() {}

  Future<List<Achievement>> award(AchievementStats stats) async {
    final repo = ref.read(achievementRepositoryProvider);
    final already = (await repo.watchUnlocked().first).map((i) => i.id).toSet();
    final earned = AchievementEngine.newlyEarned(stats, already);
    if (earned.isEmpty) return const [];
    await repo.unlock(earned, DateTime.now().toUtc());
    return earned;
  }
}
