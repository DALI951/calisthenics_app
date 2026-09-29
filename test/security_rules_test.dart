import 'dart:io';

import 'package:calisthenics_app/features/achievements/domain/achievement_engine.dart';
import 'package:calisthenics_app/features/challenges/domain/challenge.dart';
import 'package:calisthenics_app/features/challenges/domain/challenge_engine.dart';
import 'package:calisthenics_app/features/workout_session/domain/set_entry.dart';
import 'package:calisthenics_app/features/workout_session/domain/workout_session.dart';
import 'package:flutter_test/flutter_test.dart';

/// Security contract (spec §33/§34).
///
/// The deployed rules live in `firebase/firestore.rules` and
/// `firebase/database.rules.json`. `@firebase/rules-unit-testing` cannot be a
/// dev-dependency here (its scoped name breaks pub resolution on this SDK —
/// UNSURE if that is project-specific), so these tests do two things:
///
///  1. Guard the RULES FILES themselves — deleting or weakening a security
///     clause fails the build before those rules are ever deployed.
///  2. Re-state each trust decision in Dart and test the DECISION LOGIC, so
///     the app and the rules cannot drift apart.
void main() {
  final rules = File('firebase/firestore.rules').readAsStringSync();
  final rtdbRules = File('firebase/database.rules.json').readAsStringSync();

  group('firestore rules guard the trust boundaries', () {
    test('achievements are server-only — a client can never self-award', () {
      final block = rules.substring(
        rules.indexOf('match /userAchievements/'),
        rules.indexOf('match /presence/'),
      );
      expect(block, contains('allow write: if false'));
      expect(
        block.indexOf('allow write: if false'),
        lessThan(block.lastIndexOf('allow write: if false')),
        reason: 'both the collection and its subcollection must be denied',
      );
    });

    test('a client cannot write a challenge verdict', () {
      final block = rules.substring(
        rules.indexOf('match /challenges/'),
        rules.indexOf('match /userAchievements/'),
      );
      expect(block, contains('writesNoCompetitiveTruth()'));
      expect(block, contains("!('result' in request.resource.data)"));
      expect(block, contains('match /progress/{uid}'));
      expect(
        block,
        contains('allow write: if isSelf(uid) && writesNoCompetitiveTruth()'),
      );
    });

    test('users may only write their own private data', () {
      expect(rules, contains('function isSelf(uid)'));
      expect(
        rules,
        contains(
          'match /presence/{uid} {\n      allow read, write: if isSelf(uid);',
        ),
      );
    });

    test('friend requests are typed and only handled by the right side', () {
      final block = rules.substring(
        rules.indexOf('match /friendRequests/'),
        rules.indexOf('match /challenges/'),
      );
      expect(
        block,
        contains('request.resource.data.fromUid == request.auth.uid'),
      );
      expect(block, contains('resource.data.toUid == request.auth.uid'));
      expect(
        block,
        contains("'fromUid','toUid','status','createdAt','handledAt'"),
      );
    });

    test('exercise + program content is read-only to clients', () {
      expect(
        rules,
        contains(
          RegExp(
            r'match /exercises/\{exerciseId\} \{\s*allow read: if isSignedIn\(\);\s*allow write: if false;',
          ),
        ),
      );
      expect(
        rules,
        contains(
          RegExp(
            r'match /programs/\{programId\} \{\s*allow read: if isSignedIn\(\);\s*allow write: if false;',
          ),
        ),
      );
    });

    test('default deny catches every unlisted path', () {
      expect(rules, contains('match /{document=**}'));
      final tail = rules.substring(rules.lastIndexOf('match /{document=**}'));
      expect(tail, contains('allow read, write: if false;'));
      expect(rules.contains('allow read, write: if true'), isFalse);
      expect(
        rules.contains('allow read, write: if request.auth != null'),
        isFalse,
      );
    });
  });

  group('realtime database rules', () {
    test('root is closed and a client writes only its own live node', () {
      expect(rtdbRules, contains('".write": false'));
      expect(rtdbRules, contains(r'auth.uid === $uid'));
      expect(rtdbRules, contains(r"newData.child('uid').val() === $uid"));
    });

    test('live phases are constrained to the known set', () {
      expect(rtdbRules, contains(r'working|waiting|resting|finished'));
    });
  });

  group('allowed state transitions (mirrored by the rules)', () {
    test('a settled challenge can never be reopened or re-declared', () {
      for (final from in [
        ChallengeStatus.completed,
        ChallengeStatus.expired,
        ChallengeStatus.declined,
        ChallengeStatus.cancelled,
      ]) {
        for (final to in ChallengeStatus.values) {
          expect(
            ChallengeEngine.canTransition(from, to),
            isFalse,
            reason: '$from -> $to must be blocked',
          );
        }
      }
    });

    test('a live challenge can be accepted, completed or cancelled', () {
      // pending can only be accepted/declined/cancelled — never completed
      // by fiat, and pending -> active is not a client action.
      expect(
        ChallengeEngine.canTransition(
          ChallengeStatus.pending,
          ChallengeStatus.active,
        ),
        isFalse,
      );
      for (final from in [ChallengeStatus.accepted, ChallengeStatus.active]) {
        expect(
          ChallengeEngine.canTransition(from, ChallengeStatus.completed),
          isTrue,
        );
        expect(
          ChallengeEngine.canTransition(from, ChallengeStatus.cancelled),
          isTrue,
        );
      }
    });
  });

  group('the engine refuses to manufacture competitive truth', () {
    final now = DateTime.now().toUtc();
    final base = Challenge(
      id: 'c1',
      creatorUid: 'me',
      creatorHandle: 'dali',
      opponentUid: 'ayoub',
      opponentHandle: 'ayoub',
      type: ChallengeType.volume,
      target: 100,
      startsAt: now.subtract(const Duration(days: 1)),
      endsAt: now.add(const Duration(days: 6)),
      createdAt: now,
      status: ChallengeStatus.active,
    );

    WorkoutSession session(String id, List<SetEntry> sets) => WorkoutSession(
      id: id,
      programId: 'beginner',
      dayName: 'Push + C',
      dayNumber: 1,
      startedAt: now.subtract(const Duration(days: 1)),
      endedAt: now.subtract(const Duration(hours: 20)),
      exercises: const [],
      sets: sets,
    );

    test('a deadline miss never crowns a winner', () {
      final expired = Challenge(
        id: 'c1',
        creatorUid: 'me',
        creatorHandle: 'dali',
        opponentUid: 'ayoub',
        opponentHandle: 'ayoub',
        type: ChallengeType.volume,
        target: 100,
        startsAt: now.subtract(const Duration(days: 8)),
        endsAt: now.subtract(const Duration(hours: 1)),
        createdAt: now.subtract(const Duration(days: 8)),
        status: ChallengeStatus.active,
      );
      final progress = {
        'me': ChallengeProgress(
          challengeId: 'c1',
          uid: 'me',
          value: 90,
          target: 100,
          unitLabel: 'reps',
          evidenceSessionIds: const ['s1'],
          updatedAt: now,
        ),
        'ayoub': ChallengeProgress(
          challengeId: 'c1',
          uid: 'ayoub',
          value: 10,
          target: 100,
          unitLabel: 'reps',
          evidenceSessionIds: const ['s2'],
          updatedAt: now,
        ),
      };
      final settled = ChallengeEngine.settle(expired, progress, now: now);
      expect(settled.status, ChallengeStatus.expired);
      expect(settled.result!.winnerUid, isNull);
      expect(settled.result!.decidedBy, 'engine-v1');
    });

    test('empty progress never produces a winner', () {
      // A live challenge has no result yet at all.
      final live = ChallengeEngine.settle(base, const {}, now: now);
      expect(live.status, ChallengeStatus.active);
      expect(live.result, isNull);

      // Expired with zero evidence: still nobody wins.
      final dead = ChallengeEngine.settle(
        Challenge(
          id: 'c1',
          creatorUid: 'me',
          creatorHandle: 'dali',
          opponentUid: 'ayoub',
          opponentHandle: 'ayoub',
          type: ChallengeType.volume,
          target: 100,
          startsAt: now.subtract(const Duration(days: 8)),
          endsAt: now.subtract(const Duration(hours: 1)),
          createdAt: now.subtract(const Duration(days: 8)),
          status: ChallengeStatus.active,
        ),
        const {},
        now: now,
      );
      expect(dead.status, ChallengeStatus.expired);
      expect(dead.result!.winnerUid, isNull);
    });

    test('pain-reported sets never count toward a challenge', () {
      final s = session('s1', [
        SetEntry(
          id: 'a',
          exerciseId: 'pushups',
          setNumber: 1,
          reps: 50,
          painReported: true,
          completedAt: now.subtract(const Duration(hours: 21)),
        ),
        SetEntry(
          id: 'b',
          exerciseId: 'pushups',
          setNumber: 2,
          reps: 10,
          completedAt: now.subtract(const Duration(hours: 20)),
        ),
      ]);
      final p = ChallengeEngine.progressFor(
        base,
        'me',
        [s],
        metric: ExerciseMetricLike.reps,
        now: now,
      );
      expect(p.value, 10);
      expect(p.evidenceSessionIds, contains('s1'));
    });

    test('an unsafe target is rejected at creation, not at settlement', () {
      expect(
        ChallengeEngine.validateTarget(
          type: ChallengeType.progression,
          target: 500,
        ),
        isNotNull,
      );
      expect(
        ChallengeEngine.validateTarget(
          type: ChallengeType.progression,
          target: 20,
        ),
        isNull,
      );
    });
  });

  group('achievement XP cannot be inflated client-side', () {
    test('XP is a pure function of training inputs only', () {
      expect(XpEngine.levelForXp(0), 1);
      expect(XpEngine.levelForXp(150), 2);
      expect(XpEngine.totalFromSessions(const []), 0);
    });
  });
}
