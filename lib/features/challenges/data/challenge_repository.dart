import '../domain/challenge.dart';

class ChallengeException implements Exception {
  ChallengeException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Challenges seam (Firestore `challenges/{id}` + `progress/{uid}`).
///
/// Honesty rules (spec §23/§"clients cannot arbitrarily declare challenge
/// victories"): a client may write ONLY its own progress doc and only with
/// evidence session ids; the result is decided by `ChallengeEngine`.
abstract class ChallengeRepository {
  /// Challenges where I am creator or opponent (two merged queries).
  Stream<List<Challenge>> watchMyChallenges();

  /// Live progress published by each participant.
  Stream<List<ChallengeProgress>> watchProgress(String challengeId);

  Future<Challenge> create(Challenge challenge);

  /// Publishes MY progress for this challenge (derived from my history).
  Future<void> publishProgress(ChallengeProgress progress);

  /// Status transitions: accept / decline / cancel (creator only).
  Future<void> setStatus(Challenge challenge, ChallengeStatus next);

  /// Persists the engine-decided result alongside the final status.
  Future<void> finalize(Challenge challenge);
}

/// In-memory challenges (tests + local-only fallback).
class FakeChallengeRepository implements ChallengeRepository {
  FakeChallengeRepository({String? myUid}) : _myUid = myUid ?? 'local-me';

  final String _myUid;
  final _challenges = <String, Challenge>{};
  final _progress = <String, Map<String, ChallengeProgress>>{};
  final _listeners = <_Listener>[];

  // ---- test helpers ----
  void seed(Challenge c, {Map<String, ChallengeProgress> progress = const {}}) {
    _challenges[c.id] = c;
    if (progress.isNotEmpty) _progress[c.id] = Map.of(progress);
    _emit();
  }

  Challenge? byId(String id) => _challenges[id];

  // ---- interface ----
  @override
  Stream<List<Challenge>> watchMyChallenges() => Stream.multi((c) {
    final l = _Listener(
      emit: () => c.add(
        _challenges.values
            .where((c) => c.creatorUid == _myUid || c.opponentUid == _myUid)
            .toList()
          ..sort((a, b) => b.endsAt.compareTo(a.endsAt)),
      ),
    );
    _listeners.add(l);
    c.onCancel = () => _listeners.remove(l);
    l.emit();
  });

  @override
  Stream<List<ChallengeProgress>> watchProgress(String challengeId) =>
      Stream.multi((c) {
        final l = _Listener(
          emit: () =>
              c.add((_progress[challengeId] ?? const {}).values.toList()),
        );
        _listeners.add(l);
        c.onCancel = () => _listeners.remove(l);
        l.emit();
      });

  @override
  Future<Challenge> create(Challenge challenge) async {
    if (_challenges.containsKey(challenge.id)) {
      throw ChallengeException('Challenge already exists.');
    }
    if (challenge.creatorUid == challenge.opponentUid) {
      throw ChallengeException('Pick a friend, not yourself.');
    }
    _challenges[challenge.id] = challenge;
    _emit();
    return challenge;
  }

  @override
  Future<void> publishProgress(ChallengeProgress progress) async {
    final c = _challenges[progress.challengeId];
    if (c == null) {
      throw ChallengeException('Challenge not found.');
    }
    if (progress.uid != c.creatorUid && progress.uid != c.opponentUid) {
      throw ChallengeException('You are not part of this challenge.');
    }
    _progress.putIfAbsent(c.id, () => {})[progress.uid] = progress;
    _emit();
  }

  @override
  Future<void> setStatus(Challenge challenge, ChallengeStatus next) async {
    final stored = _challenges[challenge.id];
    if (stored == null) throw ChallengeException('Challenge not found.');
    if (stored.status == next) return;
    _challenges[challenge.id] = stored.copyWith(status: next);
    _emit();
  }

  @override
  Future<void> finalize(Challenge challenge) async {
    _challenges[challenge.id] = challenge;
    _emit();
  }

  void _emit() {
    for (final l in List.of(_listeners)) {
      l.emit();
    }
  }
}

class _Listener {
  _Listener({required this.emit});
  final void Function() emit;
}
