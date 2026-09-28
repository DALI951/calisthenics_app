# Release Check

How this repo ships an APK. The build happens on GitHub — never locally.

## Pipeline (sitehub pattern, spec §1)
- `.github/workflows/build-apk.yml` builds on EVERY push to main: pub get → `dart run build_runner build` → `flutter analyze` → `flutter test` → `flutter build apk --release --dart-define=APP_ENV=prod` → publishes/updates GitHub Release `v<version>` (deleted+recreated, so the download URL always has the newest APK).
- Version: `pubspec.yaml` `version:` (e.g. `0.1.3+1` → release `v0.1.3+1`, asset `calisthenics_app-v0.1.3+1.apk`).

## Prerequisites for a working build
- `GOOGLE_SERVICES_JSON` repo secret (base64 of google-services.json) set; workflow decodes it before the build step. If the secret is missing CI still passes but the APK has no backend (BackendStatus.unavailable) — that's intentional.
- google-services plugin applies only when the json exists (conditional apply in `android/app/build.gradle.kts`), so CI never breaks on missing config.

## Gotchas learned (do not regress)
- NEVER reference `secrets.*` in workflow `if:` — GitHub rejects it ("workflow file issue"). Guard secrets in bash (`if [ -n "$VAR" ]`).
- Artifact storage quota on free tier: APKs go to Release assets (release storage is separate), not upload-artifact (except best-effort).
- Debug-signed release is personal-testing-only; store keystore task documented in docs/release-checklist.md.
- After each release: download the APK, install, verify sign-in + core loop (spec §86-87), then announce the version bump.