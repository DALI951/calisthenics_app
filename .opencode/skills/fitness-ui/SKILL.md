# Fitness UI

Dali's design system for this app — encode it, don't eyeball it.

- Dark-first: base #0A0A0F, surfaces slightly lighter, ONE red accent #DC2626 family. Light theme must remain accessible. No gradients, no glassmorphism, no clutter.
- Tokens in `lib/app/theme/`: app_colors, app_typography, app_spacing (4px grid), app_radius (8/12/16/pill), app_surface, app_motion (reduced-motion aware).
- Core components in `lib/core/widgets/` (AppCard, AppPrimaryButton, AppEmptyState, AppErrorState, FormErrorText, loading skeletons). Never inline raw Material styling for these patterns — reuse the components.
- Do NOT duplicate UI code. ExerciseCard/WorkoutCard/RestTimer/ProgressRing/StatCard/PRBadge/StreakCard live as shared components with consistent APIs (spec §39).
- Polish rules: perfect touch targets (48dp), visible focus, semantic labels + screen readers, no information by color alone, readable timer text, charts with labels (not decoration).
- Empty states must be motivating, e.g. "No friends yet → Add your first friend".
- Motion: only for meaningful moments — set complete, PR unlocked, workout complete, achievement unlock, rest transitions. Respect reduced-motion.
- How to verify: `dart format .` then `flutter analyze`, then run tests, then look at the screen with the seer agent when visual review is needed.