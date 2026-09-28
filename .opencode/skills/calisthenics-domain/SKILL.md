# Calisthenics Domain

The fitness domain model — the source of truth for this app's rules.

## Program (spec §9)
- The Beginner program is DATA, not hardcoded UI: `lib/features/workouts/data/program_registry.dart` loads versioned programs (`program-version` field); spec §9 defines 4 training days in a 7-day week (DO NOT make 5 training days):
  - Day1 Push+Core, Day2 Pull+Core, Day3 Rest, Day4 Legs+Core, Day5 Full Body, Day6-7 Rest.
- `ProgramDay.dayAt(weekdaySlot)` maps Monday=1.

## Exercise domain (spec §12)
- 27-exercise V1 library: 8 push, 8 pull, 6 legs, 5 core. Difficulty beginner+intermediate only (advanced is Phase-2 content — guarded by test).
- Every exercise: id, name, category, muscleGroups, difficulty, equipment, instructions, techniqueCues, commonMistakes, easierVariations, harderVariations, prerequisites, metric (reps/time), recommendedRest, safetyNotes, tags, contentVersion.
- Bump `contentVersion` whenever technique/safety text changes.
- Substitution rules: equipment-aware. No pull-up bar? Pull-ups → Australian row. No parallel bars? Dips → progression. Never assume equipment.

## Safety (spec §67)
- Beginners only. No max-effort challenges, no pushing through significant pain — if pain is reported, pause progression and show the documented safety message (rest + trusted adult/coach/healthcare professional). Never diagnose.
- Technique over numbers. Never encourage sacrificing form for reps.

## Timers (spec §15, §70)
- NEVER decrement integers. Rest/streak/timer math is timestamp/duration based so state survives backgrounding. Test the calculations.