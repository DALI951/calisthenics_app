import 'package:firebase_database/firebase_database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/services/backend_status.dart';
import '../../auth/data/auth_providers.dart';
import '../../friends/data/friends_providers.dart';
import '../domain/training_presence.dart';
import 'backend_presence_repositories.dart';
import 'presence_repository.dart';

part 'presence_providers.g.dart';

/// Presence backend seam — RTDB when available, honest no-op otherwise.
@Riverpod(keepAlive: true)
PresenceRepository presenceRepository(Ref ref) {
  final status = ref.watch(backendStatusProvider);
  final uid = ref.watch(authControllerProvider).value?.id;
  return switch (status) {
    BackendStatus.available || BackendStatus.emulator => RtdbPresenceRepository(
      FirebaseDatabase.instance,
      uid,
    ),
    BackendStatus.unavailable => NoOpPresenceRepository(),
  };
}

/// Live list of friends currently training (spec §22). Privacy: built
/// ONLY from my friend list — I never watch strangers' presence.
@Riverpod(keepAlive: true)
Stream<List<TrainingPresence>> friendsPresence(Ref ref) {
  final repo = ref.watch(presenceRepositoryProvider);
  final myUid = ref.watch(authControllerProvider).value?.id;
  final friends = ref.watch(friendsListProvider).value ?? const [];
  final streams = [
    for (final f in friends)
      if (f.uid != myUid) repo.watchPresence(f.uid, handle: f.handle),
  ];
  return combinePresenceWatches(streams);
}
