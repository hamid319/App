import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:swipetrip/common/models/group_model.dart';
import 'package:swipetrip/core/services/firestore_service.dart';
import 'package:swipetrip/features/group/data/group_repository.dart';

class _MockFirestoreService extends Mock implements FirestoreService {}

/// The invite code must keep working after a group's first session.
void main() {
  late FakeFirebaseFirestore firestore;
  late GroupRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = GroupRepository(_MockFirestoreService(), firestore: firestore);
  });

  Future<void> seedGroup({
    String? activeSessionId,
    bool? joinEnabled = true,
    List<String> members = const ['owner'],
  }) {
    return firestore.collection('groups').doc('group-1').set({
      'groupId': 'group-1',
      'members': members,
      'ownerUid': 'owner',
      'sharedFavorites': <String>[],
      'hasCompletedSession': false,
      'activeSessionId': activeSessionId,
      if (joinEnabled != null) 'joinEnabled': joinEnabled,
      'invite': {'code': 'ABC123', 'createdAt': null},
    });
  }

  Future<Map<String, dynamic>> groupData() async =>
      (await firestore.collection('groups').doc('group-1').get()).data()!;

  Future<String> start() => repository.startSwipeSession(
        groupId: 'group-1',
        destination: 'Berlin',
        participantUids: ['owner'],
        swipeLimit: 1,
        placePool: ['place-1'],
      );

  test('joining by code is blocked while a session runs', () async {
    await seedGroup();
    await start();

    await expectLater(
      repository.joinGroupByCodeOnly('abc123', 'new-user'),
      throwsA(isA<Exception>()),
    );
    await expectLater(
      repository.joinGroupByInvite('group-1', 'ABC123', 'new-user'),
      throwsA(isA<Exception>()),
    );
    expect((await groupData())['members'], ['owner']);
  });

  test('admin ending the session reopens joining', () async {
    await seedGroup();
    final sessionId = await start();

    await repository.endSessionManually(
      groupId: 'group-1',
      sessionId: sessionId,
      adminUid: 'owner',
    );
    expect((await groupData())['joinEnabled'], isTrue);

    final joined = await repository.joinGroupByCodeOnly('abc123', 'new-user');
    expect(joined, 'group-1');
    expect((await groupData())['members'], ['owner', 'new-user']);
  });

  test('everyone finishing the session reopens joining', () async {
    await seedGroup();
    final sessionId = await start();

    await repository.recordSwipeInSession(
      groupId: 'group-1',
      sessionId: sessionId,
      userId: 'owner',
      placeId: 'place-1',
      liked: true,
    );
    final group = await groupData();
    expect(group['activeSessionId'], isNull);
    expect(group['joinEnabled'], isTrue);

    await repository.joinGroupByInvite('group-1', 'ABC123', 'new-user');
    expect((await groupData())['members'], contains('new-user'));
  });

  test('clearing a vanished session reopens joining', () async {
    await seedGroup(activeSessionId: 'gone', joinEnabled: false);

    await repository.clearActiveSessionIfMatch(
      groupId: 'group-1',
      sessionId: 'gone',
    );
    final group = await groupData();
    expect(group['activeSessionId'], isNull);
    expect(group['joinEnabled'], isTrue);
  });

  test('a stuck group (joinEnabled false, no session) is joinable', () async {
    await seedGroup(joinEnabled: false);

    await repository.joinGroupByCodeOnly('ABC123', 'new-user');
    expect((await groupData())['members'], ['owner', 'new-user']);
  });

  test('a group without the legacy flag is joinable', () async {
    await seedGroup(joinEnabled: null);

    await repository.joinGroupByInvite('group-1', 'ABC123', 'new-user');
    expect((await groupData())['members'], ['owner', 'new-user']);
  });

  test('a wrong code is still rejected', () async {
    await seedGroup();
    await expectLater(
      repository.joinGroupByInvite('group-1', 'WRONG1', 'new-user'),
      throwsA(isA<Exception>()),
    );
  });

  test('GroupModel.isJoinable follows the active session only', () {
    expect(
      const GroupModel(groupId: 'g', joinEnabled: false).isJoinable,
      isTrue,
    );
    expect(
      const GroupModel(groupId: 'g', joinEnabled: true, activeSessionId: 's')
          .isJoinable,
      isFalse,
    );
  });
}
