# UI Polish

Final-pass checklist (spec §54-58). Run before closing any phase.

- Awkward transitions, confusing labels, tiny buttons (<48dp), inconsistent spacing/typography, unnecessary dialogs, excessive loading, poor error messages, broken back behavior, keyboard issues, accidental navigation loss, inaccessible controls.
- Every list: intentional empty state. Loading: skeleton UI, never blank screens. Errors: what happened + what the user can do (spec §59).
- Motion on meaningful moments only (set complete, PR, workout complete, challenge complete, achievement, rest transitions) — subtle, haptic-aware where supported, reduced-motion respected.
- Visual feedback without annoying popups: SET COMPLETE ✓ / NEW PERSONAL RECORD / WORKOUT COMPLETE / CHALLENGE COMPLETE inline.

## How to run it
1. `dart format . && flutter analyze && flutter test` — zero issues, all green.
2. Walk the core loop on the emulator/device: sign-in → onboarding → today's workout → sets → rest → finish → summary → history → progress.
3. Verify existing features still work (auth, theme switch, sign-out).
4. Update README/docs if behavior changed.
5. Inspect git diff before commit.

Resist over-engineering (spec §85): simplest scalable UI, no decorative fea­tures.