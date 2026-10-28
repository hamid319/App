import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:swipetrip/core/services/firestore_service.dart';
import 'package:swipetrip/features/group/data/group_repository.dart';

class _MockFirestoreService extends Mock implements FirestoreService {}

void main() {
  late FakeFirebaseFirestore firestore;
  late GroupRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = GroupRepository(
      _MockFirestoreService(),
      firestore: firestore,
    );
  });

  Future<void> seedGroup({
    required List<String> members,
    String ownerUid = 'owner',
    String? activeSessionId,
  }) {
    return firestore.collection('groups').doc('group-1').set({
      'groupId': 'group-1',
      'members': members,
      'ownerUid': ownerUid,
      'sharedFavorites': <String>[],
      'hasCompletedSession': false,
      'activeSessionId': activeSessionId,
      'joinEnabled': true,
    });
  }

  Future<Map<String, dynamic>?> readGroup() async =>
      (await firestore.collection('groups').doc('group-1').get()).data();

  group('leaveGroup (4.3)', () {
    test('owner leaving hands ownership to a remaining member', () async {
      await seedGroup(members: ['owner', 'user-2', 'user-3']);

      await repository.leaveGroup('group-1', 'owner');

      final group = (await readGroup())!;
      expect(group['members'], ['user-2', 'user-3']);
      expect(group['ownerUid'], 'user-2');
    });

    test('non-owner leaving keeps the owner', () async {
      await seedGroup(members: ['owner', 'user-2']);

      await repository.leaveGroup('group-1', 'user-2');

      final group = (await readGroup())!;
      expect(group['members'], ['owner']);
      expect(group['ownerUid'], 'owner');
    });

    test('last member leaving deletes the group', () async {
      await seedGroup(members: ['owner']);

      await repository.leaveGroup('group-1', 'owner');

      expect(await readGroup(), isNull);
    });
  });

}
