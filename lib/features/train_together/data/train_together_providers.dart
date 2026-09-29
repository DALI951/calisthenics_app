import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/services/backend_status.dart';
import '../../auth/data/auth_providers.dart';
import '../../workout_session/domain/workout_session.dart';
import '../../workout_session/presentation/workout_session_controller.dart';
import '../domain/live_pair_state.dart';
import '../domain/train_together_engine.dart';
import 'rtdb_train_together_repository.dart';
import 'train_together_repository.dart';

part 'train_together_providers.g.dart';

/// Deterministic pair id for two friends (same as friend docs).
String trainPairId(String a, String b) {
  final ids = [a, b]..sort();
  return '${ids.first}__${ids.last}';
}

@Riverpod(keepAlive: true)
TrainTogetherRepository trainTogetherRepository(Ref ref) {
  final status = ref.watch(backendStatusProvider);
  final user = ref.watch(authControllerProvider).value;
  return switch (status) {
    BackendStatus.available ||
    BackendStatus.emulator => RtdbTrainTogetherRepository(
      FirebaseDatabase.instance,
      user?.id,
      myHandle: user?.displayLabel.toLowerCase() ?? 'me',
    ),
    BackendStatus.unavailable => FakeTrainTogetherRepository(
      myUid: user?.id ?? 'local-me',
      myHandle: user?.displayLabel.toLowerCase() ?? 'me',
    ),
  };
}

/// Live synchronized view for one partner (spec §22).
@Riverpod(keepAlive: true)
Stream<LivePairState?> trainTogether(Ref ref, String partnerUid) {
  final repo = ref.watch(trainTogetherRepositoryProvider);
  final me = ref.watch(authControllerProvider).value;
  final uid = me?.id;
  if (uid == null) return Stream.value(null);
  final pairId = trainPairId(uid, partnerUid);

  return Stream.multi((c) {
    LiveAthleteState? myState;
    LiveAthleteState? partnerState;
    void emit() {
      final now = DateTime.now().toUtc();
      final partner = partnerState == null
          ? null
          : (TrainTogetherEngine.isStale(partnerState, now)
                ? null
                : partnerState);
      c.add(
        LivePairState(
          me: myState,
          partner: partner,
          restSeconds: repo.restSeconds(pairId),
          restStartedAt: repo.restStartedAt(pairId),
        ),
      );
    }

    final subMe = repo.watchMe(pairId).listen((v) {
      myState = v;
      emit();
    }, onError: c.addError);
    final subPartner = repo.watchPartner(pairId, partnerUid).listen((v) {
      partnerState = v;
      emit();
    }, onError: c.addError);
    c.onCancel = () async {
      await subMe.cancel();
      await subPartner.cancel();
    };
  });
}

/// Pushes my live state from the workout session controller.
@Riverpod(keepAlive: true)
class TrainTogetherSession extends _$TrainTogetherSession {
  String? _partnerUid;
  String? _pairId;

  @override
  void build() {}

  /// Starts mirroring my session to this partner.
  void start(String partnerUid) {
    _partnerUid = partnerUid;
    syncNow();
  }

  void stop() {
    final pairId = _pairId;
    _partnerUid = null;
    _pairId = null;
    if (pairId != null) {
      unawaited(ref.read(trainTogetherRepositoryProvider).leave(pairId));
    }
  }

  /// Call on every session change (set recorded, skip, rest, finish).
  void syncNow() {
    final uid = ref.read(authControllerProvider).value?.id;
    final partner = _partnerUid;
    final session = ref.read(workoutSessionControllerProvider);
    if (uid == null || partner == null || session == null) {
      if (session == null) stop();
      return;
    }
    _pairId ??= trainPairId(uid, partner);
    final idx = session.currentExerciseIndex(session.sets);
    final exercise = idx < session.exercises.length
        ? session.exercises[idx]
        : session.exercises.lastOrNull;
    final doneForExercise = exercise == null
        ? 0
        : session.setsFor(exercise.exerciseId).length;
    final phase = switch (session.phase) {
      WorkoutPhase.resting => LivePhase.waiting,
      WorkoutPhase.finished => LivePhase.finished,
      _ =>
        doneForExercise >= (exercise?.sets ?? 0) && exercise != null
            ? LivePhase.waiting
            : LivePhase.working,
    };
    unawaited(
      ref
          .read(trainTogetherRepositoryProvider)
          .publishMe(
            _pairId!,
            LiveAthleteState(
              uid: uid,
              handle:
                  ref.read(authControllerProvider).value?.displayLabel ?? 'me',
              exerciseName: exercise?.name ?? '',
              setNumber: (doneForExercise + 1).clamp(1, 999),
              totalSets: exercise?.sets ?? 0,
              phase: phase,
              updatedAt: DateTime.now().toUtc(),
            ),
          ),
    );
  }
}
