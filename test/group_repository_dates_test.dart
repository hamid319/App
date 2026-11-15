import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:swipetrip/common/models/group_model.dart';
import 'package:swipetrip/core/services/firestore_service.dart';
import 'package:swipetrip/features/group/data/group_repository.dart';

class _MockFirestoreService extends Mock implements FirestoreService {}

/// Setting the dates of an existing trip ("Next steps" on the trips tab).
void main() {
  test('updateTripDates stores both dates and keeps the rest', () async {
    final firestore = FakeFirebaseFirestore();
    final repository =
        GroupRepository(_MockFirestoreService(), firestore: firestore);
    await firestore.collection('groups').doc('g1').set({
      'groupId': 'g1',
      'groupName': 'Hihi',
      'members': ['owner'],
      'ownerUid': 'owner',
    });

    await repository.updateTripDates(
        'g1', DateTime(2027, 5, 1), DateTime(2027, 5, 4));

    final doc = await firestore.collection('groups').doc('g1').get();
    final group = GroupModel.fromJson(doc.data()!);
    expect(group.tripStart, DateTime(2027, 5, 1));
    expect(group.tripEnd, DateTime(2027, 5, 4));
    expect(group.groupName, 'Hihi');
  });
}
