# Workout Engine

Rules for the workout session + rest timer + progression (spec §14-15, §10-11).

## Session flow
Start → exercise → set → enter reps/time → confirm → rest → next set → next exercise → summary.

Supported operations: reps, duration, assisted reps, notes, skipped set, skipped exercise, exercise substitution, pause/resume workout, finish early, UNDO LAST SET.

## Persistence (spec §14, §31)
- Active session is persisted locally (shared_preferences, JSON draft) on every change; restoring after process death resumes the session.
- NEVER lose workout progress on accidental navigation. Confirm-before-discard UI when leaving a live session.
- Completed workouts are immutable records (spec §17, §60). If corrections are allowed later, keep an audit trail.

## Rest timer (spec §15, §70)
- Timestamp-based: state holds `restUntil` (end timestamp). A lightweight ticker only re-renders; on resume compute remaining from `DateTime.now()` vs `restUntil`. Correct after: rebuilds, navigation, backgrounding, suspension.
- Default 90–120s between normal sets; exercise-specific defaults from the Exercise model.
- Controls: pause, resume, skip, +15s, -15s, next exercise/set preview, visual progress ring.

## Progression engine (spec §10-11) — DETERMINISTIC + TESTED
- Input: per-set reps vs target range, sets completed, form confirmation, consistency, recent performance, pain/discomfort, recovery, difficulty.
- Behavior: hitting the top of the range with good technique raises the next target within the allowed range; sustained mastery shows "Ready to progress?" and recommends the next harder variation (from exercise.harderVariations).
- Never auto-increase for technique sacrifices. If pain reported → pause progression, safety message.
- Pure Dart, no widgets — unit tests mandatory (test/progression_engine_test.dart).

## Records & local data
- PRs (spec §18): lifetime / current-program / recent best, per exercise; never from incomplete or invalid sessions.