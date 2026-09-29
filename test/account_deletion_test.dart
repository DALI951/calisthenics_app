import 'package:calisthenics_app/features/auth/domain/account_deletion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a clean run removes local, remote and the account', () async {
    final report = await AccountDeletionService(
      clearLocal: () async => 7,
      deleteFirestore: () async => 5,
      deleteRealtime: () async => 2,
      deleteAuthAccount: () async {},
    ).run();

    expect(report.remoteDocsDeleted, 7);
    expect(report.localKeysCleared, 7);
    expect(report.localCleared, isTrue);
    expect(report.accountDeleted, isTrue);
    expect(report.failures, isEmpty);
    expect(report.fullyRemoved, isTrue);
    // Shared docs are always disclosed, never silently kept.
    expect(report.needsServerCleanup, isTrue);
  });

  test(
    'a Firestore failure is reported, and the account is still deleted',
    () async {
      final report = await AccountDeletionService(
        clearLocal: () async => 3,
        deleteFirestore: () async => throw Exception('permission denied'),
        deleteRealtime: () async => 1,
        deleteAuthAccount: () async {},
      ).run();

      expect(report.failures, contains('your synced profile and history'));
      expect(
        report.accountDeleted,
        isTrue,
        reason: 'never leave someone stuck in a half-deleted account',
      );
      expect(report.localCleared, isTrue);
    },
  );

  test(
    'an auth failure is disclosed instead of pretending it worked',
    () async {
      final report = await AccountDeletionService(
        clearLocal: () async => 3,
        deleteFirestore: () async => 1,
        deleteRealtime: () async => 1,
        deleteAuthAccount: () async => throw Exception('recent login required'),
      ).run();

      expect(report.accountDeleted, isFalse);
      expect(report.failures, contains('your sign-in'));
      expect(report.fullyRemoved, isFalse);
    },
  );

  test('the report says the truth about shared data in plain words', () async {
    final report = await AccountDeletionService(
      clearLocal: () async => 1,
      deleteFirestore: () async => 1,
      deleteRealtime: () async => 0,
      deleteAuthAccount: () async {},
    ).run();

    final text = report.describe();
    expect(text, contains('Removed 1 synced record and 1 local setting'));
    expect(text, contains('Signed out'));
    expect(text, contains('training partner'));
  });
}
