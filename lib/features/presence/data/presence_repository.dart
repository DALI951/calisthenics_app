import 'dart:async';

import '../domain/training_presence.dart';

/// Realtime training-presence seam (spec §22).
abstract class PresenceRepository {
  /// Live presence for ONE friend (null when offline). Privacy: callers
  /// may only pass uids the user is actually friends with (Phase 12
  /// security rules enforce this server-side too).
  Stream<TrainingPresence?> watchPresence(String uid, {required String handle});

  /// Marks me as training (expires automatically on disconnect).
  Future<void> goOnlineForTraining({
    required String exerciseName,
    required String dayName,
  });

  /// Clears my presence immediately.
  Future<void> stopTraining();
}

/// No-op presence (backend unavailable / signed out).
class NoOpPresenceRepository implements PresenceRepository {
  const NoOpPresenceRepository();

  @override
  Stream<TrainingPresence?> watchPresence(
    String uid, {
    required String handle,
  }) => Stream.value(null);

  @override
  Future<void> goOnlineForTraining({
    required String exerciseName,
    required String dayName,
  }) async {}

  @override
  Future<void> stopTraining() async {}
}

/// Combines per-friend presence streams into ONE live list (drops offline
/// friends, newest first). Pure stream combinator — unit-tested.
Stream<List<TrainingPresence>> combinePresenceWatches(
  List<Stream<TrainingPresence?>> streams,
) {
  if (streams.isEmpty) return Stream.value(const []);
  return _combine(streams);
}

Stream<List<TrainingPresence>> _combine(
  List<Stream<TrainingPresence?>> streams,
) {
  final controller = StreamController<List<TrainingPresence>>();
  final values = List<TrainingPresence?>.filled(streams.length, null);
  final subs = <StreamSubscription<TrainingPresence?>>[];

  void emit() {
    final live = values.whereType<TrainingPresence>().toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    if (!controller.isClosed) controller.add(live);
  }

  controller.onListen = () {
    for (var i = 0; i < streams.length; i++) {
      subs.add(
        streams[i].listen((v) {
          values[i] = v;
          emit();
        }, onError: controller.addError),
      );
    }
  };
  controller.onCancel = () async {
    for (final s in subs) {
      await s.cancel();
    }
  };
  return controller.stream;
}
