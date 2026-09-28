import 'package:calisthenics_app/features/workout_session/presentation/workout_session_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RestTimerState (spec §15, §70 — timestamp math, no counters)', () {
    test('remainingAt is computed from now, never decremented', () {
      final now = DateTime.now();
      final state = RestTimerState(
        exerciseId: 'push_up',
        setNumber: 2,
        restUntil: now.add(const Duration(seconds: 90)),
        totalSeconds: 90,
      );
      expect(
        state.remainingAt(now.add(const Duration(seconds: 30))),
        const Duration(seconds: 60),
      );
      // Negative → zero, not negative counts.
      expect(
        state.remainingAt(now.add(const Duration(seconds: 91))),
        Duration.zero,
      );
    });

    test('pause freezes remaining; resume re-anchors restUntil', () {
      final now = DateTime.now();
      final state = RestTimerState(
        exerciseId: 'plank',
        setNumber: 1,
        restUntil: now.add(const Duration(minutes: 1)),
        totalSeconds: 60,
      );
      final at10 = now.add(const Duration(seconds: 10));
      final paused = state.copyWith(
        pausedRemaining: state.remainingAt(at10), // 50s left
      );
      expect(paused.isPaused, isTrue);
      // Even a minute later, paused state still reports 50s.
      expect(
        paused.remainingAt(now.add(const Duration(minutes: 1))),
        const Duration(seconds: 50),
      );
    });

    test('JSON round-trip preserves paused state', () {
      final now = DateTime.now();
      final state = RestTimerState(
        exerciseId: 'push_up',
        setNumber: 3,
        restUntil: now.add(const Duration(seconds: 45)),
        totalSeconds: 45,
        pausedRemaining: const Duration(seconds: 20),
      );
      final restored = RestTimerState.fromJson(state.toJson());
      expect(restored.pausedRemaining, const Duration(seconds: 20));
      expect(restored.totalSeconds, 45);
      expect(restored.exerciseId, 'push_up');
    });
  });

  group('RestTimerController', () {
    test('start/add/pause/resume/skip transitions', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ctrl = container.read(restTimerControllerProvider.notifier);
      RestTimerState? t;

      ctrl.start(60, exerciseId: 'push_up', setNumber: 1);
      t = container.read(restTimerControllerProvider.notifier).state;
      expect(t, isNotNull);
      expect(t!.totalSeconds, 60);

      ctrl.addSeconds(15);
      t = container.read(restTimerControllerProvider.notifier).state;
      expect(
        t!.restUntil.difference(DateTime.now()).inSeconds,
        greaterThan(70),
      );

      ctrl.pause();
      t = container.read(restTimerControllerProvider.notifier).state;
      expect(t!.isPaused, isTrue);

      ctrl.resume();
      t = container.read(restTimerControllerProvider.notifier).state;
      expect(t!.isPaused, isFalse);

      ctrl.skip();
      t = container.read(restTimerControllerProvider.notifier).state;
      expect(t, isNull);
    });
  });
}
