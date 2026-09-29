import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../workouts/domain/workout_program.dart';
import 'personal_maxes.dart';

/// How hard a block asks you to work. The journey walks up these, never down,
/// except for a planned deload.
enum BlockEmphasis {
  /// Learn the movement, low volume, plenty of reps in reserve.
  technique,

  /// Build work capacity.
  hypertrophy,

  /// Fewer sets, closer to your max, longer rests.
  strength,

  /// Low volume, near-max, skill work.
  skill,
}

/// One phase of a long training journey — never a one-off 4-day block that
/// ends and leaves you with nothing.
class ProgramBlock {
  const ProgramBlock({
    required this.id,
    required this.name,
    required this.weeks,
    required this.emphasis,
    required this.goal,
    this.increaseAfterWeeks = 2,
    this.deloadEveryWeeks = 6,
  });

  final String id;
  final String name;

  /// How many weeks you stay in this block.
  final int weeks;
  final BlockEmphasis emphasis;

  /// Shown to the athlete in plain words.
  final String goal;

  /// How many consecutive good sessions earn a rep increase.
  final int increaseAfterWeeks;

  /// A recovery week this often. Progress without recovery is a plateau.
  final int deloadEveryWeeks;
}

/// The order a long-term trainee moves through. This is the answer to "I want
/// to train for a long time, not 4 days": blocks that each last weeks, get
/// progressively harder, and repeat in a cycle.
abstract final class ProgramJourney {
  static const blocks = <ProgramBlock>[
    ProgramBlock(
      id: 'foundation',
      name: 'Foundation',
      weeks: 6,
      emphasis: BlockEmphasis.technique,
      goal: 'Learn the six core movements with clean reps. Volume builds, '
          'nothing is near failure.',
      increaseAfterWeeks: 2,
    ),
    ProgramBlock(
      id: 'build',
      name: 'Build',
      weeks: 8,
      emphasis: BlockEmphasis.hypertrophy,
      goal: 'More sets per movement, working around two reps from failure. '
          'This is where visible size comes from.',
      increaseAfterWeeks: 3,
      deloadEveryWeeks: 8,
    ),
    ProgramBlock(
      id: 'strength',
      name: 'Strength',
      weeks: 8,
      emphasis: BlockEmphasis.strength,
      goal: 'Heavier sets at a higher share of your max, longer rests. Sets '
          'drop, weight goes up.',
      increaseAfterWeeks: 3,
      deloadEveryWeeks: 8,
    ),
    ProgramBlock(
      id: 'skill',
      name: 'Skill',
      weeks: 6,
      emphasis: BlockEmphasis.skill,
      goal: 'Low volume, near-maximum effort on the hard skills: dips, '
          'muscle-ups, weighted pull-ups.',
      increaseAfterWeeks: 2,
      deloadEveryWeeks: 6,
    ),
  ];

  /// Blocks in order, wrapping back to the start — a repeating cycle rather
  /// than a program that ends.
  static ProgramBlock blockForWeek(int week) {
    if (week < 1) week = 1;
    var remaining = week;
    for (final b in blocks) {
      if (remaining <= b.weeks) return b;
      remaining -= b.weeks;
    }
    final cycle = blocks.fold<int>(0, (sum, b) => sum + b.weeks);
    return blockForWeek(((week - 1) % cycle) + 1);
  }
}

/// What a session should actually ask for today, after progression.
class ScaledTarget {
  const ScaledTarget({
    required this.sets,
    required this.targetMin,
    required this.targetMax,
    required this.targetSecondsMin,
    required this.targetSecondsMax,
    required this.restSeconds,
    this.isProgression = false,
  });

  final int sets;
  final int? targetMin;
  final int? targetMax;
  final int? targetSecondsMin;
  final int? targetSecondsMax;
  final int restSeconds;

  /// True when this target was raised from the planned one.
  final bool isProgression;
}

/// Turns a planned day into today's actual work.
///
/// The rules are the boring, well-tested ones: train each skill at a share of
/// your own max, keep two reps in reserve in the build phase, and only go
/// near failure when the block is a strength or skill block. When you have
/// beaten the top of the range, the target goes up — that is the part that
/// makes a long program actually progress instead of repeating forever.
class ProgressionEngine {
  const ProgressionEngine();

  /// Share of a declared max used for a hard set in each emphasis.
  static double workingShareFor(BlockEmphasis emphasis) => switch (emphasis) {
        BlockEmphasis.technique => 0.5,
        BlockEmphasis.hypertrophy => 0.7,
        BlockEmphasis.strength => 0.85,
        BlockEmphasis.skill => 0.9,
      };

  /// Rest in seconds for a working set, by emphasis.
  static int restFor(BlockEmphasis emphasis) => switch (emphasis) {
        BlockEmphasis.technique => 75,
        BlockEmphasis.hypertrophy => 90,
        BlockEmphasis.strength => 150,
        BlockEmphasis.skill => 180,
      };

  /// Scales one planned exercise for [week] using the athlete's [maxes].
  ///
  /// A declared max wins: it is the strongest signal the athlete gave us, and
  /// it is what makes sessions harder as they get stronger. Without a max the
  /// planned numbers are kept — never inflated, because guessing up is how
  /// people hurt themselves.
  ScaledTarget scale({
    required PlannedExercise planned,
    required int week,
    required BlockEmphasis emphasis,
    PersonalMaxes maxes = PersonalMaxes.empty,
  }) {
    final share = workingShareFor(emphasis);
    final rest = restFor(emphasis);
    final skill = _skillFor(planned.exerciseId);
    final max = skill == null ? null : maxes.valueFor(skill);

    // A deload week: keep the movements, cut the volume and the effort.
    final block = ProgramJourney.blockForWeek(week);
    final isDeload = block.deloadEveryWeeks > 0 &&
        week > 0 &&
        (week % block.deloadEveryWeeks) == 0;

    if (max == null) {
      return ScaledTarget(
        sets: isDeload ? math.max(1, planned.sets - 1) : planned.sets,
        targetMin: planned.targetMin,
        targetMax: planned.targetMax,
        targetSecondsMin: planned.targetSecondsMin,
        targetSecondsMax: planned.targetSecondsMax,
        restSeconds: rest,
      );
    }

    final scaled = maxes.workingTarget(skill!, share);
    if (skill == MaxSkill.plank) {
      return ScaledTarget(
        sets: isDeload ? math.max(1, planned.sets - 1) : planned.sets,
        targetMin: null,
        targetMax: null,
        targetSecondsMin: scaled,
        targetSecondsMax: scaled + (emphasis == BlockEmphasis.technique ? 20 : 10),
        restSeconds: rest,
      );
    }

    // Build a rep range around the share of the max: the bottom is
    // comfortable, the top is the working ceiling for this block.
    final lo = math.max(1, (scaled * 0.7).round());
    final hi = isDeload
        ? math.max(lo, (scaled * 0.8).round())
        : math.max(lo + 1, scaled);

    return ScaledTarget(
      sets: isDeload ? math.max(1, planned.sets - 1) : planned.sets,
      targetMin: lo,
      targetMax: hi,
      targetSecondsMin: null,
      targetSecondsMax: null,
      restSeconds: rest,
      isProgression: hi > (planned.targetMax ?? 0),
    );
  }

  /// Applies [scale] across a whole day.
  List<PlannedExercise> scaleDay({
    required ProgramDay day,
    required int week,
    required BlockEmphasis emphasis,
    PersonalMaxes maxes = PersonalMaxes.empty,
  }) {
    return [
      for (final planned in day.exercises)
        _applyScale(
          scale(
            planned: planned,
            week: week,
            emphasis: emphasis,
            maxes: maxes,
          ),
          planned,
        ),
    ];
  }

  PlannedExercise _applyScale(ScaledTarget t, PlannedExercise planned) =>
      planned.copyWith(
        sets: t.sets,
        targetMin: t.targetMin,
        targetMax: t.targetMax,
        targetSecondsMin: t.targetSecondsMin,
        targetSecondsMax: t.targetSecondsMax,
        restSeconds: t.restSeconds,
      );

  MaxSkill? _skillFor(String exerciseId) {
    for (final s in MaxSkill.values) {
      if (s.exerciseId == exerciseId) return s;
    }
    return null;
  }
}

/// Tracks how many weeks the athlete has completed, so the journey knows
/// where they are. Purely a counter — the real signal is whether the sets
/// actually got done.
@immutable
class JourneyProgress {
  const JourneyProgress({this.week = 1, this.startedAt});

  final int week;
  final DateTime? startedAt;

  JourneyProgress next() => JourneyProgress(week: week + 1, startedAt: startedAt);

  ProgramBlock get currentBlock => ProgramJourney.blockForWeek(week);
}
