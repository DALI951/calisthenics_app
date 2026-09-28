/// Canonical Firebase path constants.
///
/// Single place that owns collection/document/path strings — Firestore rules,
/// RTDB rules and Dart code all derive from this table. See the firebase
/// architecture skill for the full data model rationale.
abstract final class AppIds {
  // ---- Cloud Firestore collections --------------------------------------
  static const String users = 'users';
  static const String userProfiles = 'userProfiles';
  static const String friendships = 'friendships';
  static const String friendRequests = 'friendRequests';
  static const String exercises = 'exercises';
  static const String programs = 'programs';
  static const String programWeeks = 'programWeeks';
  static const String workoutSessions = 'workoutSessions';
  static const String workoutSets = 'workoutSets';
  static const String personalRecords = 'personalRecords';
  static const String challenges = 'challenges';
  static const String challengeProgress = 'challengeProgress';
  static const String achievements = 'achievements';
  static const String userAchievements = 'userAchievements';
  static const String notifications = 'notifications';
  static const String reports = 'reports';

  // ---- Realtime Database paths (transient presence only) ----------------
  static const String rtdbPresence = 'presence';
  static const String rtdbTrainTogether = 'trainTogether';

  // ---- SharedPreferences keys ---------------------------------------------
  static const String prefPrefix = 'calisthenics.';
  static const String prefOnboardingCompleted =
      '${prefPrefix}onboarding.completed';
  static const String prefThemeMode = '${prefPrefix}settings.themeMode';
  static const String prefUnits = '${prefPrefix}settings.units';
  static const String prefNotificationsEnabled =
      '${prefPrefix}settings.notifications.enabled';

  /// Version stamp written to user profiles so future migrations can detect
  /// stale clients (program versioning, data consistency rules).
  static const int appDataVersion = 1;
}
