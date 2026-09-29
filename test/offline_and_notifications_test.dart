import 'package:calisthenics_app/core/sync/offline_write_queue.dart';
import 'package:calisthenics_app/core/sync/sync_status.dart';
import 'package:calisthenics_app/features/notifications/domain/notification.dart';
import 'package:calisthenics_app/features/notifications/domain/notification_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('offline queue', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('stable ids make identical writes idempotent', () {
      const payload = {'b': 2, 'a': 1};
      expect(
        PendingWrite.idFor('workoutHistory', payload),
        PendingWrite.idFor('workoutHistory', const {'a': 1, 'b': 2}),
      );
      expect(
        PendingWrite.idFor('workoutHistory', payload),
        isNot(PendingWrite.idFor('friends', payload)),
      );
    });

    test('enqueueing the same data twice queues ONE write', () async {
      final q = OfflineWriteQueue();
      await q.load();
      await q.enqueue('workoutHistory', const {'id': 's1'});
      await q.enqueue('workoutHistory', const {'id': 's1'});
      expect(q.writes.length, 1);
    });

    test('data survives a restart (persisted outbox)', () async {
      final q = OfflineWriteQueue();
      await q.load();
      await q.enqueue('workoutHistory', const {
        'id': 's1',
      }, now: DateTime.utc(2026, 1, 1));
      final reloaded = OfflineWriteQueue();
      await reloaded.load();
      expect(reloaded.writes.length, 1);
      expect(reloaded.writes.single.payload['id'], 's1');
    });

    test('flush removes only what was sent, keeps order', () async {
      final q = OfflineWriteQueue();
      await q.load();
      await q.enqueue('workoutHistory', const {'id': 'a'});
      await q.enqueue('workoutHistory', const {'id': 'b'});
      final sent = <String>[];
      final n = await q.flush(
        (w) async => sent.add(w.payload['id']! as String),
      );
      expect(n, 2);
      expect(sent, ['a', 'b']);
      expect(q.writes, isEmpty);
    });

    test(
      'a failure keeps the data and marks it failed, never loses it',
      () async {
        final q = OfflineWriteQueue();
        await q.load();
        await q.enqueue('workoutHistory', const {'id': 'a'});
        await q.flush((_) async => throw Exception('offline'));
        expect(q.writes.length, 1);
        expect(q.failedCount, 1);
        expect(q.writes.single.lastError, contains('offline'));
        // Retry works once the network is back.
        final n = await q.flush((_) async {});
        expect(n, 1);
        expect(q.writes, isEmpty);
      },
    );

    test('flush stops at the first failure to preserve ordering', () async {
      final q = OfflineWriteQueue();
      await q.load();
      await q.enqueue('workoutHistory', const {'id': 'a'});
      await q.enqueue('workoutHistory', const {'id': 'b'});
      final attempted = <String>[];
      await q.flush((w) async {
        attempted.add(w.payload['id']! as String);
        throw Exception('boom');
      });
      expect(attempted, ['a']);
      expect(q.writes.length, 2, reason: 'b must stay queued, not be lost');
    });

    test('status labels are honest about the three states', () {
      expect(const SyncStatus.synced().label, 'Synced');
      expect(
        const SyncStatus(phase: SyncPhase.pending, pendingCount: 1).label,
        'Pending sync (1)',
      );
      expect(
        const SyncStatus(phase: SyncPhase.failed, failedCount: 2).label,
        contains('data is safe'),
      );
    });
  });

  group('notification policy', () {
    bool decide(
      NotificationKind kind, {
      required DateTime now,
      NotificationSettings? settings,
      List<AppNotification> recent = const [],
      String title = 'x',
    }) => NotificationPolicy.decide(
      kind: kind,
      title: title,
      now: now,
      settings: settings ?? NotificationSettings.defaults,
      recent: recent,
    );

    test('a kind the user disabled never gets through', () {
      expect(
        decide(NotificationKind.workoutReminder, now: DateTime(2026, 1, 1, 12)),
        isFalse,
        reason: 'workout reminders are opt-in',
      );
    });

    test('friend started training requires explicit opt-in', () {
      final off = NotificationSettings.defaults;
      expect(
        decide(
          NotificationKind.friendStartedTraining,
          now: DateTime(2026, 1, 1, 12),
          settings: off,
        ),
        isFalse,
      );
      final on = off.toggle(NotificationKind.friendStartedTraining, true);
      expect(
        decide(
          NotificationKind.friendStartedTraining,
          now: DateTime(2026, 1, 1, 12),
          settings: on,
        ),
        isTrue,
      );
    });

    test('rest timer always gets through — the user is mid-workout', () {
      expect(
        decide(
          NotificationKind.restTimerDone,
          now: DateTime(2026, 1, 1, 23, 30),
          settings: NotificationSettings.defaults,
        ),
        isTrue,
      );
    });

    test('quiet hours silence ambient notifications (22:00 - 08:00)', () {
      final s = NotificationSettings.defaults.toggle(
        NotificationKind.challengeEndingSoon,
        true,
      );
      expect(
        decide(
          NotificationKind.challengeEndingSoon,
          now: DateTime(2026, 1, 1, 23),
          settings: s,
        ),
        isFalse,
      );
      expect(
        decide(
          NotificationKind.challengeEndingSoon,
          now: DateTime(2026, 1, 1, 7, 30),
          settings: s,
        ),
        isFalse,
      );
      expect(
        decide(
          NotificationKind.challengeEndingSoon,
          now: DateTime(2026, 1, 1, 12),
          settings: s,
        ),
        isTrue,
      );
    });

    test('a direct friend request still breaks through quiet hours', () {
      expect(
        decide(
          NotificationKind.friendRequest,
          now: DateTime(2026, 1, 1, 23, 30),
        ),
        isTrue,
      );
    });

    test('identical messages are deduped inside 10 minutes', () {
      final at = DateTime(2026, 1, 1, 12);
      final recent = [
        AppNotification(
          kind: NotificationKind.challengeCompleted,
          title: 'Challenge done',
          body: '',
          at: at,
        ),
      ];
      expect(
        decide(
          NotificationKind.challengeCompleted,
          now: at.add(const Duration(minutes: 5)),
          recent: recent,
          title: 'Challenge done',
        ),
        isFalse,
      );
      expect(
        decide(
          NotificationKind.challengeCompleted,
          now: at.add(const Duration(minutes: 20)),
          recent: recent,
          title: 'Challenge done',
        ),
        isTrue,
      );
    });

    test('ambient notifications are capped at 3 per hour (no ping storms)', () {
      final at = DateTime(2026, 1, 1, 12);
      final recent = [
        for (var i = 0; i < 3; i++)
          AppNotification(
            kind: NotificationKind.challengeCompleted,
            title: 'c$i',
            body: '',
            at: at.add(Duration(minutes: i)),
          ),
      ];
      expect(
        decide(
          NotificationKind.challengeCompleted,
          now: at.add(const Duration(minutes: 30)),
          recent: recent,
          title: 'c4',
        ),
        isFalse,
      );
    });

    test('social nudges have a 6h cooldown', () {
      final s = NotificationSettings.defaults.toggle(
        NotificationKind.friendStartedTraining,
        true,
      );
      final at = DateTime(2026, 1, 1, 10);
      final recent = [
        AppNotification(
          kind: NotificationKind.friendStartedTraining,
          title: 'a',
          body: '',
          at: at,
        ),
      ];
      expect(
        decide(
          NotificationKind.friendStartedTraining,
          now: at.add(const Duration(hours: 2)),
          settings: s,
          recent: recent,
          title: 'b',
        ),
        isFalse,
      );
      expect(
        decide(
          NotificationKind.friendStartedTraining,
          now: at.add(const Duration(hours: 7)),
          settings: s,
          recent: recent,
          title: 'b',
        ),
        isTrue,
      );
    });
  });
}
