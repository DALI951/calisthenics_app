import 'package:calisthenics_app/features/friends/data/fake_friends_repository.dart';
import 'package:calisthenics_app/features/friends/data/friends_providers.dart';
import 'package:calisthenics_app/features/friends/data/friends_repository.dart';
import 'package:calisthenics_app/features/friends/domain/friend_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ayoub = UserProfile(
    uid: 'uid-ayoub',
    handle: 'ayoub111',
    displayName: 'Ayoub',
  );
  final sami = UserProfile(
    uid: 'uid-sami',
    handle: 'sami_tn',
    displayName: 'Sami',
  );

  ProviderContainer makeContainer({required FakeFriendsRepository repo}) {
    final c = ProviderContainer(
      overrides: [friendsRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test(
    'ensureProfile creates my public profile with the derived handle',
    () async {
      final c = makeContainer(
        repo: FakeFriendsRepository(ownUid: 'uid-me', ownHandle: 'dali951'),
      );
      final profile = await c.read(ownProfileProvider.future);
      expect(profile, isNotNull);
      expect(profile!.handle, 'dali951');
    },
  );

  test('search finds users by handle prefix, excluding me', () async {
    final c = makeContainer(
      repo: FakeFriendsRepository(
        ownUid: 'uid-me',
        ownHandle: 'dali951',
        backend: FakeFriendsBackend(users: {ayoub.uid: ayoub, sami.uid: sami}),
      ),
    );
    final results = await c.read(userSearchProvider('ayou').future);
    expect(results.map((u) => u.handle), contains('ayoub111'));
    expect(results.map((u) => u.handle), isNot(contains('dali951')));
  });

  test(
    'full request flow: send → incoming on other side → accept → friends',
    () async {
      // One shared backend = one server; two containers = two devices.
      final server = FakeFriendsBackend(
        users: {ayoub.uid: ayoub, sami.uid: sami},
      );
      final c = makeContainer(
        repo: FakeFriendsRepository(
          ownUid: 'uid-me',
          ownHandle: 'dali951',
          backend: server,
        ),
      );
      addTearDown(server.dispose);
      final repo = c.read(friendsRepositoryProvider);

      // I send a request to ayoub.
      await repo.sendRequest('ayoub111');
      final outgoing = await repo.watchOutgoingRequests().first;
      expect(outgoing, hasLength(1));
      expect(outgoing.single.toUid, ayoub.uid);
      expect(outgoing.single.fromHandle, 'dali951');

      // Ayoub's device sees it as incoming (live, no reload).
      final ayoubSide = makeContainer(
        repo: FakeFriendsRepository(
          ownUid: ayoub.uid,
          ownHandle: ayoub.handle,
          backend: server,
        ),
      );
      final otherRepo = ayoubSide.read(friendsRepositoryProvider);
      final incoming = await otherRepo.watchIncomingRequests().first;
      expect(incoming, hasLength(1));
      expect(incoming.single.fromUid, 'uid-me');

      // Ayoub accepts → BOTH sides see the friendship (realtime).
      await otherRepo.acceptRequest(incoming.single);

      expect(
        (await repo.watchFriends().first).map((f) => f.uid),
        contains(ayoub.uid),
      );
      expect(
        (await otherRepo.watchFriends().first).map((f) => f.uid),
        contains('uid-me'),
      );
      expect(await repo.watchIncomingRequests().first, isEmpty);
      expect(await repo.watchOutgoingRequests().first, isEmpty);
    },
  );

  test('decline removes the request and never creates a friendship', () async {
    final server = FakeFriendsBackend(users: {ayoub.uid: ayoub});
    addTearDown(server.dispose);
    final c = makeContainer(
      repo: FakeFriendsRepository(
        ownUid: 'uid-me',
        ownHandle: 'dali951',
        backend: server,
      ),
    );
    final repo = c.read(friendsRepositoryProvider);
    await repo.sendRequest('ayoub111');

    final other = makeContainer(
      repo: FakeFriendsRepository(
        ownUid: ayoub.uid,
        ownHandle: ayoub.handle,
        backend: server,
      ),
    );
    final otherRepo = other.read(friendsRepositoryProvider);
    final incoming = await otherRepo.watchIncomingRequests().first;
    await otherRepo.declineRequest(incoming.single);

    expect(await otherRepo.watchIncomingRequests().first, isEmpty);
    expect(await repo.watchFriends().first, isEmpty);
    expect(await otherRepo.watchFriends().first, isEmpty);
  });

  test('withdrawRequest cancels an outgoing request', () async {
    final server = FakeFriendsBackend(users: {ayoub.uid: ayoub});
    addTearDown(server.dispose);
    final repo = FakeFriendsRepository(
      ownUid: 'uid-me',
      ownHandle: 'dali951',
      backend: server,
    );
    makeContainer(repo: repo);

    await repo.sendRequest('ayoub111');
    final outgoing = await repo.watchOutgoingRequests().first;
    expect(outgoing, hasLength(1));
    await repo.withdrawRequest(outgoing.single);
    expect(await repo.watchOutgoingRequests().first, isEmpty);
  });

  test('removeFriend deletes the connection on both sides', () async {
    final server = FakeFriendsBackend(
      users: {ayoub.uid: ayoub, sami.uid: sami},
      friendships: {
        'uid-me': {ayoub.uid, sami.uid},
        ayoub.uid: {'uid-me'},
        sami.uid: {'uid-me'},
      },
    );
    addTearDown(server.dispose);
    final c = makeContainer(
      repo: FakeFriendsRepository(
        ownUid: 'uid-me',
        ownHandle: 'dali951',
        backend: server,
      ),
    );
    final repo = c.read(friendsRepositoryProvider);

    expect((await repo.watchFriends().first).length, 2);
    await repo.removeFriend(ayoub.uid);
    final after = await repo.watchFriends().first;
    expect(after.map((f) => f.uid), isNot(contains(ayoub.uid)));
    expect(after.map((f) => f.uid), contains(sami.uid));

    // Ayoub's side lost the connection too.
    final ayoubRepo = FakeFriendsRepository(
      ownUid: ayoub.uid,
      ownHandle: ayoub.handle,
      backend: server,
    );
    expect(await ayoubRepo.watchFriends().first, isEmpty);
  });

  test('sendRequest to unknown handle fails honestly', () async {
    final c = makeContainer(
      repo: FakeFriendsRepository(ownUid: 'uid-me', ownHandle: 'dali951'),
    );
    await expectLater(
      c.read(friendsRepositoryProvider).sendRequest('nobody99'),
      throwsA(isA<FriendsException>()),
    );
  });
}
