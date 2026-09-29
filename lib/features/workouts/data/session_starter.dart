import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../workout_session/presentation/workout_session_controller.dart';
import '../domain/workout_program.dart';

/// Turns a hand-picked list of movements into a one-off program day the normal
/// session controller can run.
///
/// Lives next to the starter (not in the widget) so the rule "a built session
/// is a real day" is testable without pumping a screen.
ProgramDay buildSessionDay(List<PlannedExercise> exercises) => ProgramDay(
      dayNumber: 1,
      type: ProgramDayType.training,
      name: 'My session',
      exercises: exercises,
    );

/// Starts a hand-built session.
///
/// The session is a real one: same controller, same progression scaling, same
/// history write. Only the plan comes from the athlete instead of a preset,
/// which is the whole point.
class SessionStarter {
  static const adHocProgramId = 'ad-hoc-session';

  const SessionStarter();

  Future<void> startBuilt(BuildContext context, ProgramDay day) =>
      start(context, day, programName: 'My session');

  Future<void> start(
    BuildContext context,
    ProgramDay day, {
    required String programName,
  }) async {
    final ref = ProviderScope.containerOf(context, listen: false);
    if (ref.read(workoutSessionControllerProvider) != null) {
      // A workout is already running — never silently replace it.
      context.push('/app/workouts/session');
      return;
    }
    final program = WorkoutProgram(
      id: adHocProgramId,
      name: programName,
      version: 1,
      days: [day],
    );
    ref.read(workoutSessionControllerProvider.notifier).start(program, day);
    if (context.mounted) context.push('/app/workouts/session');
  }
}
