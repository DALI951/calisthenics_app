# Firebase Architecture

Backend layout for this project (spec §32-34). Firebase is a service, isolated behind repositories.

- Identity: Firebase Auth. Emulator-first: no production google-services.json required to develop — `lib/core/services/firebase_bootstrap.dart` initializes programmatically with emulator options (auth 9099, firestore 8080, database 9000, storage 9199 via 10.0.2.2) in `APP_ENV=dev`; `APP_ENV=prod` uses the real project from google-services.json.
  - `BackendStatus` (unavailable/emulator/available) gates features — the UI shows an honest "local build" state instead of fake data.
- Durable data: Cloud Firestore. Live/transient: Realtime Database (presence, train-together). Media: Storage. Trusted logic: Cloud Functions (only where client trust is unacceptable).
- Collections (conceptual, Firestore): users, userProfiles, friendships, friendRequests, exercises, programs, programWeeks, workoutSessions, workoutSets, personalRecords, challenges, challengeProgress, achievements, userAchievements, notifications, reports.
- Repository pattern: `Firebase*Repository` implements an abstract interface used by providers; tests swap in in-memory fakes. No Firebase types leak into widgets.
- Workout writes are idempotent: client-generated UUID as document id (`uuid` package), `set(..., SetOptions(merge))`.
- Cost control (spec §71-72): no persistent listeners — subscribe only while a screen needs live data; dispose in `ref.onDispose`. Paginate history (`limit` + `startAfter`). Never hold whole collections in memory.

## Secrets
- `google-services.json`: NEVER committed (gitignored). CI gets it from repo secret `GOOGLE_SERVICES_JSON` (base64) decoded by the workflow into `android/app/` before the build step — bash guard, never in step `if:`.
- `GOOGLE_SERVER_CLIENT_ID` const for google_sign_in is public (OAuth client IDs are not secrets).