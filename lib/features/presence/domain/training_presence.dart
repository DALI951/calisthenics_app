/// Live "X is training right now" presence (spec §22). Backed by the
/// Firebase Realtime Database because it offers `onDisconnect` — presence
/// dies instantly when a client crashes or a phone dies, which Firestore
/// cannot do.
class TrainingPresence {
  const TrainingPresence({
    required this.uid,
    required this.handle,
    required this.exerciseName,
    required this.dayName,
    required this.startedAt,
  });

  final String uid;
  final String handle;
  final String exerciseName;
  final String dayName;
  final DateTime startedAt;

  Duration get elapsed => DateTime.now().toUtc().difference(startedAt);
}
