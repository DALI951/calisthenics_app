/// Sync state shown to the user (spec §31): exactly three honest states.
enum SyncPhase {
  /// Everything is stored remotely.
  synced,

  /// Stored locally, waiting for connectivity.
  pending,

  /// A write failed after retries — the data is SAFE locally, never lost.
  failed,
}

class SyncStatus {
  const SyncStatus({
    required this.phase,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.lastSyncedAt,
    this.lastError,
  });

  const SyncStatus.synced({DateTime? at})
    : phase = SyncPhase.synced,
      pendingCount = 0,
      failedCount = 0,
      lastSyncedAt = at,
      lastError = null;

  final SyncPhase phase;
  final int pendingCount;
  final int failedCount;
  final DateTime? lastSyncedAt;

  /// Why the last flush failed — surfaced, never swallowed.
  final String? lastError;

  bool get isClean => phase == SyncPhase.synced;

  /// Human wording. Never alarming, never blaming the user.
  String get label => switch (phase) {
    SyncPhase.synced => 'Synced',
    SyncPhase.pending =>
      pendingCount == 1 ? 'Pending sync (1)' : 'Pending sync ($pendingCount)',
    SyncPhase.failed => 'Sync failed — your data is safe',
  };

  SyncStatus copyWith({
    SyncPhase? phase,
    int? pendingCount,
    int? failedCount,
    DateTime? lastSyncedAt,
    String? lastError,
    bool clearError = false,
  }) => SyncStatus(
    phase: phase ?? this.phase,
    pendingCount: pendingCount ?? this.pendingCount,
    failedCount: failedCount ?? this.failedCount,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    lastError: clearError ? null : (lastError ?? this.lastError),
  );
}
