import '../domain/workout_program.dart';

/// The programs the app knows about.
///
/// There is deliberately **no preset program**. The athlete builds their own
/// week (see ActiveProgramController) and builds each session itself, so
/// nothing forces a fixed split on anyone. `blank` is only the starting point
/// for a new athlete: seven rest days with nothing in them.
abstract final class ProgramRegistry {
  static const String blankProgramId = 'blank-v1';

  /// An empty week. Starting here is honest: nothing is programmed until you
  /// programme it.
  static final WorkoutProgram blank = WorkoutProgram(
    id: blankProgramId,
    name: 'My week',
    version: 1,
    days: [
      for (var d = 1; d <= 7; d++)
        ProgramDay(
          dayNumber: d,
          type: ProgramDayType.rest,
          name: 'Rest',
          exercises: const [],
        ),
    ],
  );

  static final Map<String, WorkoutProgram> _byId = {blank.id: blank};

  static WorkoutProgram? byId(String id) => _byId[id];

  static List<WorkoutProgram> get all => List.unmodifiable(_byId.values);
}
