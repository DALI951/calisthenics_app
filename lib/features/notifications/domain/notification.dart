/// The notification kinds the app can send (spec §35). Granular opt-in per
/// kind, no surprises.
enum NotificationKind {
  friendRequest,
  challengeInvite,
  challengeEndingSoon,
  challengeCompleted,
  friendStartedTraining,
  restTimerDone,
  workoutReminder,
}

/// Defaults chosen against the spec: social nudges are OFF unless asked for,
/// rest-timer completion is ON because the user is mid-workout.
const notificationKindDefaults = <NotificationKind, bool>{
  NotificationKind.friendRequest: true,
  NotificationKind.challengeInvite: true,
  NotificationKind.challengeEndingSoon: true,
  NotificationKind.challengeCompleted: true,
  NotificationKind.friendStartedTraining: false,
  NotificationKind.restTimerDone: true,
  NotificationKind.workoutReminder: false,
};

class NotificationSettings {
  const NotificationSettings(this.enabled);

  final Set<NotificationKind> enabled;

  static const defaults = NotificationSettings({
    NotificationKind.friendRequest,
    NotificationKind.challengeInvite,
    NotificationKind.challengeEndingSoon,
    NotificationKind.challengeCompleted,
    NotificationKind.restTimerDone,
  });

  bool isOn(NotificationKind kind) => enabled.contains(kind);

  NotificationSettings toggle(NotificationKind kind, bool on) {
    final next = Set<NotificationKind>.from(enabled);
    if (on) {
      next.add(kind);
    } else {
      next.remove(kind);
    }
    return NotificationSettings(next);
  }

  /// Quiet hours: 22:00 → 08:00 local. Personal requests (a friend asking
  /// you something directly) may still come through; anything ambient stays
  /// silent.
  static const quietHoursStart = 22;
  static const quietHoursEnd = 8;

  /// These are addressed to YOU and may break through quiet hours.
  static const personal = {
    NotificationKind.friendRequest,
    NotificationKind.challengeInvite,
  };
}
