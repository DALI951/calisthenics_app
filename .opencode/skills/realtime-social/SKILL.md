# Realtime Social

Friends, presence, train-together (spec §20-22, §73, §86-87).

## Presence
- Realtime Database keyed by uid: `presence/<uid>/` with ONE small node — status (offline/online/training/resting/paused), workoutId, exerciseId, setNumber, updatedAt. NO per-second tick writes; update only on meaningful state changes. onClick it is ephemeral: cleared on finish/exit (`.onDisconnect` where supported + explicit cleanup).
- Privacy gate: training/online visibility is controlled by the user's privacy settings BEFORE any read (rule-level + client-side).
- Never expose location. No background location.

## Friends
- Search by username only. Request → accept/decline → friend. Remove and block supported in the data model (blocking hides and prevents future requests).
- Friend-visible data is a strict subset: public profile + chosen PRs + recent workouts + level/streak + achievements + weekly activity. Private workout data and notes NEVER visible to friends. No sensitive health info shared.

## Train together (spec §22, §9)
- Two friends run the same day: same exercise, same set numbering, per-person progress, rest phase sync, completion + encouragement. NOT surveillance, no video.
- Room model: `trainTogether/<sessionId>` with participants, currentExercise, currentSet, each user's progress, restingUntil per user; presence rules prevent cheating (progress only advances via completed-set writes).

## Cost (spec §71)
- Listen only while the friends/home context is on screen; dispose in ref.onDispose. Avoid extra database writes. Challenge/anti-cheat rule from spec §74: clients cannot declare victories — state transitions validated in rules (and Cloud Functions where we document them).