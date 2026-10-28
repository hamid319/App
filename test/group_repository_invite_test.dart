import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:swipetrip/common/models/group_model.dart';
import 'package:swipetrip/core/services/firestore_service.dart';
import 'package:swipetrip/features/group/data/group_repository.dart';

class _MockFirestoreService extends Mock implements FirestoreService {}

/// Joining a trip by its invite code.
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
    }).then((_) => firestore
        .collection('inviteCodes')
        .doc('ABC123')
        .set({'groupId': 'group-1'}));
  }

  Future<Map<String, dynamic>> groupData() async =>
      (await firestore.collection('groups').doc('group-1').get()).data()!;

  test('joining works even with a swipe round of the old app still marked',
      () async {
    await seedGroup(activeSessionId: 'old-round', joinEnabled: false);
    await repository.joinGroupByInvite('group-1', 'ABC123', 'new-user');
    expect((await groupData())['members'], contains('new-user'));
  });

  test('a wrong code is still rejected', () async {
    await seedGroup();
    await expectLater(
      repository.joinGroupByInvite('group-1', 'WRONG1', 'new-user'),
      throwsA(isA<Exception>()),
    );
  });

  test('joining sends the code along and unknown codes fail', () async {
    await seedGroup();
    await repository.joinGroupByCodeOnly('abc123', 'new-user');
    final data = await groupData();
    expect(data['members'], contains('new-user'));
    expect(data['joinCode'], 'ABC123');

    await expectLater(
      repository.joinGroupByCodeOnly('WRONG1', 'other-user'),
      throwsA(isA<Exception>()),
    );
    await expectLater(
      repository.joinGroupByInvite('group-1', 'WRONG1', 'other-user'),
      throwsA(isA<Exception>()),
    );
  });

  test('a new group gets its invite code entry', () async {
    await repository.createGroup(const GroupModel(
      groupId: 'g2',
      members: ['owner'],
      ownerUid: 'owner',
      invite: GroupInvite(code: 'XYZ789'),
    ));
    final entry = await firestore.collection('inviteCodes').doc('XYZ789').get();
    expect(entry.data()?['groupId'], 'g2');
  });
}
