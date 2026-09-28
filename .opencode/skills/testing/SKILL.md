# Testing

The quality gates for this repo. Definitions of done per spec §46-47, §83.

## Layers
- Unit: pure domain — progression engine, rest-timer math, PR calculations, challenge state transitions, streak/date logic, AuthFailure mapping. No widgets.
- Widget: full-app flows with FakeAuthRepository + shared_preferences mocks (real router/theme/onboarding wiring) — sign-in, google sign-in, sign-out, onboarding, workout start, error paths.
- Integration (critical flows, doc-only or emulator-gated): sign-up → onboarding → Push Day → set → rest → background → resume (timer correctness) → finish → history → PR → friend request → challenge lifecycle → offline sync + duplicate prevention.

## Commands
- `dart run build_runner build` after annotated-file changes (generated files gitignored)
- `dart format --output=none --set-exit-if-changed .` — must pass
- `flutter analyze` — zero issues (fatal infos like CI)
- `flutter test` — all green
- Firebase emulators (auth/firestore/database): `firebase emulators:start` for backend repo tests where practical; seed data kept under test/fixtures.

## Must test (spec §46)
auth state, routing, progression engine, rest timer calculations, workout session state, PR calculations, challenge state transitions, friend permissions, privacy logic, offline sync, duplicate prevention, unauthorized access.

Minimal scenarios list lives in spec §47 (28 scenarios) — treat as the checklist for Phase 12.