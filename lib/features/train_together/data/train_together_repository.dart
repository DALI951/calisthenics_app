import 'dart:async';

import '../domain/live_pair_state.dart';

/// Train-Together seam: RTDB `liveSessions/{pairId}/{uid}` (self node only)
/// + `liveSessions/{pairId}/cheers/{uid}`.
abstract class TrainTogetherRepository {
  Stream<LiveAthleteState?> watchPartner(String pairId, String partnerUid);
  Stream<LiveAthleteState?> watchMe(String pairId);

  /// Publishes MY live state (set number, phase, exercise).
  Future<void> publishMe(String pairId, LiveAthleteState state);

  /// Leave the live session (fires on finish, discard and app close).
  Future<void> leave(String pairId);

  /// Cheer feed (auto-expires in the UI after a few seconds).
  Stream<List<Cheer>> watchCheers(String pairId);
  Future<void> sendCheer(String pairId, String emoji);

  /// Last known rest length for the pair, so both timers match.
  int restSeconds(String pairId);
  DateTime? restStartedAt(String pairId);
}

/// In-memory implementation — tests + the honest no-backend fallback.
class FakeTrainTogetherRepository implements TrainTogetherRepository {
  FakeTrainTogetherRepository({required this.myUid, this.myHandle = 'me'});

  final String myUid;
  final String myHandle;

  final _nodes = <String, Map<String, LiveAthleteState>>{};
  final _cheers = <String, List<Cheer>>{};
  final _restSeconds = <String, int>{};
  final _restStarted = <String, DateTime>{};
  final _controllers = <String, StreamController<void>>{};

  StreamController<void> _ctrl(String pairId) =>
      _controllers.putIfAbsent(pairId, () {
        final c = StreamController<void>.broadcast();
        c.onListen = () => c.add(null);
        return c;
      });

  /// Test helper: a partner device publishing state.
  void simulatePartner(
    String pairId,
    String partnerUid,
    LiveAthleteState state,
  ) {
    _nodes.putIfAbsent(pairId, () => <String, LiveAthleteState>{})[partnerUid] =
        state;
    _ctrl(pairId).add(null);
  }

  /// Test helper: partner crashes (node removed by onDisconnect).
  void dropPartner(String pairId, String partnerUid) {
    _nodes[pairId]?.remove(partnerUid);
    _ctrl(pairId).add(null);
  }

  @override
  Stream<LiveAthleteState?> watchMe(String pairId) async* {
    yield _nodes[pairId]?[myUid];
    yield* _ctrl(pairId).stream.map((_) => _nodes[pairId]?[myUid]);
  }

  @override
  Stream<LiveAthleteState?> watchPartner(String pairId, String partnerUid) =>
      _ctrl(pairId).stream
          .map((_) => _nodes[pairId]?[partnerUid])
          .startWith(_nodes[pairId]?[partnerUid]);

  @override
  Future<void> publishMe(String pairId, LiveAthleteState state) async {
    _nodes.putIfAbsent(pairId, () => <String, LiveAthleteState>{})[myUid] =
        state;
    _restSeconds[pairId] = 90;
    _ctrl(pairId).add(null);
  }

  @override
  Future<void> leave(String pairId) async {
    _nodes[pairId]?.remove(myUid);
    _ctrl(pairId).add(null);
  }

  @override
  Stream<List<Cheer>> watchCheers(String pairId) async* {
    yield _cheers[pairId] ?? const [];
    yield* _ctrl(pairId).stream.map((_) => _cheers[pairId] ?? const []);
  }

  @override
  Future<void> sendCheer(String pairId, String emoji) async {
    (_cheers[pairId] ??= []).add(
      Cheer(fromHandle: myHandle, emoji: emoji, at: DateTime.now().toUtc()),
    );
    _ctrl(pairId).add(null);
  }

  @override
  int restSeconds(String pairId) => _restSeconds[pairId] ?? 90;

  @override
  DateTime? restStartedAt(String pairId) => _restStarted[pairId];
}

extension _StartWith<T> on Stream<T> {
  Stream<T> startWith(T value) async* {
    yield value;
    yield* this;
  }
}
