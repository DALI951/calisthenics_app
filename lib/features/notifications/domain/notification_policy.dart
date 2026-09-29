import 'notification.dart';

class AppNotification {
  const AppNotification({
    required this.kind,
    required this.title,
    required this.body,
    required this.at,
  });

  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime at;
}

/// Anti-spam gate (spec §35: "Do not spam", "no compulsive app checking").
/// Every notification in the app must pass through [decide].
class NotificationPolicy {
  const NotificationPolicy._();

  /// At most this many ambient (non-personal) notifications per hour.
  static const ambientPerHour = 3;

  /// Same message within this window is swallowed.
  static const dedupeWindow = Duration(minutes: 10);

  /// Social nudges need a 6h cooldown — no "come back and check" pressure.
  static const socialCooldown = Duration(hours: 6);

  static bool _inQuietHours(DateTime at) {
    final h = at.hour;
    return h >= NotificationSettings.quietHoursStart ||
        h < NotificationSettings.quietHoursEnd;
  }

  /// Decides whether a notification may be delivered right now.
  static bool decide({
    required NotificationKind kind,
    required String title,
    required DateTime now,
    required NotificationSettings settings,
    required List<AppNotification> recent,
  }) {
    // 1. The user must have enabled this kind.
    if (!settings.isOn(kind)) return false;

    // 2. A rest timer finishing mid-workout is always fine, even at night.
    if (kind == NotificationKind.restTimerDone) return true;

    final personal = NotificationSettings.personal.contains(kind);

    // 3. Quiet hours silence ambient noise; personal requests still get in.
    if (_inQuietHours(now) && !personal) return false;

    // 4. Dedupe identical messages.
    if (recent.any(
      (n) =>
          n.kind == kind &&
          n.title == title &&
          now.difference(n.at) < dedupeWindow,
    )) {
      return false;
    }

    // 5. Ambient hourly cap, so a busy afternoon can't become a ping storm.
    if (!personal) {
      final lastHour = recent
          .where(
            (n) =>
                !NotificationSettings.personal.contains(n.kind) &&
                now.difference(n.at) < const Duration(hours: 1),
          )
          .length;
      if (lastHour >= ambientPerHour) return false;
    }

    // 6. Social nudges (friend training, challenge ending) get a long cooldown.
    if (kind == NotificationKind.friendStartedTraining ||
        kind == NotificationKind.challengeEndingSoon) {
      if (recent.any(
        (n) => n.kind == kind && now.difference(n.at) < socialCooldown,
      )) {
        return false;
      }
    }

    return true;
  }
}
