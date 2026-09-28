# Security Review

Checklist before calling any feature done (spec §33-34, §53, §74-75).

## Mandatory pass
- Firestore rules (`firestore.rules`) and RTDB rules (`database.rules`): ownership, friendship, challenge participation, field types, allowed state transitions. Deny-by-default.
- Users modify only their own private data; friends see only permitted subsets; exercise/program content is not user-editable.
- Clients CANNOT arbitrarily award achievements or declare challenge victories (rules + state transitions; document why Cloud Functions are/aren't needed).
- No privileged Firebase credentials in the client. google-services.json never committed; CI injects from secret.

## Per-feature checks
- Auth: wrong password, nonexistent account, weak password, email-in-use, network, Firebase unavailable, deletion, logout — all human-readable, no raw exceptions leaked (AppFailure layer).
- Workout writes: idempotent (client UUID + merge), duplicates impossible.
- Challenges: no "client says I did 1000 reps" trust; progress only from attached session records; completed challenges immutable from the client.
- Privacy: friend-visible data is a strict subset; private notes/health data never exposed; no location.
- Input validation: typed models at boundaries, missing fields handled gracefully for old records.
- Logging: developer info only, no tokens/passwords/sensitive fitness data.

## Secrets sweep
`git ls-files | Select-String "google-services|\.env|key|secret"` before any commit. Run `firebase.json` + rules through `firebase deploy --only firestore:rules,storage,realtime` as part of Phase 12.