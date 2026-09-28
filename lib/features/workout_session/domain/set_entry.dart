import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

part 'set_entry.freezed.dart';

/// One recorded set inside a workout (spec §14). Immutable once written.
@freezed
abstract class SetEntry with _$SetEntry {
  const factory SetEntry({
    /// Stable id (client-generated) — idempotent sync, no duplicates.
    required String id,
    required String exerciseId,

    /// 1-based set number within this exercise's run.
    required int setNumber,

    /// Reps completed (null when timed or skipped).
    int? reps,

    /// Seconds completed (null when rep-based or skipped).
    int? seconds,

    /// Assisted/banded reps included in [reps] (e.g. 8 reps, 2 assisted).
    @Default(0) int assistedReps,

    /// True when the set was skipped on purpose.
    @Default(false) bool skipped,

    /// Optional user note ("last rep hard", "form great").
    String? note,

    /// Reports pain/discomfort (spec §28) — pauses progression, never
    /// encourages pushing through.
    @Default(false) bool painReported,

    /// UTC completion time.
    required DateTime completedAt,
  }) = _SetEntry;

  const SetEntry._();

  factory SetEntry.fromStorage(Map<String, Object?> json) => SetEntry(
    id: json['id'] as String,
    exerciseId: json['exerciseId'] as String,
    setNumber: json['setNumber'] as int,
    reps: json['reps'] as int?,
    seconds: json['seconds'] as int?,
    assistedReps: json['assistedReps'] as int? ?? 0,
    skipped: json['skipped'] as bool? ?? false,
    note: json['note'] as String?,
    painReported: json['painReported'] as bool? ?? false,
    completedAt: DateTime.parse(json['completedAt'] as String),
  );

  Map<String, Object?> toStorage() => {
    'id': id,
    'exerciseId': exerciseId,
    'setNumber': setNumber,
    'reps': reps,
    'seconds': seconds,
    'assistedReps': assistedReps,
    'skipped': skipped,
    'note': note,
    'painReported': painReported,
    'completedAt': completedAt.toIso8601String(),
  };

  /// Primary number for stat/PR purposes (reps or seconds).
  int get primaryValue {
    if (reps != null && reps! > 0) return reps!;
    return seconds ?? 0;
  }

  bool get isTimed => seconds != null && reps == null;

  /// Whether this set counts toward PRs (skipped/invalid sets never do,
  /// spec §18).
  bool get countsTowardRecords => !skipped && primaryValue > 0 && !painReported;
}
