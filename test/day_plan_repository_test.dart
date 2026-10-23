import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:swipetrip/common/models/day_plan.dart';
import 'package:swipetrip/common/models/group_session_model.dart';
import 'package:swipetrip/core/services/firestore_service.dart';
import 'package:swipetrip/features/group/data/group_repository.dart';

class _MockFirestoreService extends Mock implements FirestoreService {}

void main() {
  late FakeFirebaseFirestore db;
  late GroupRepository repo;
  final session = db0Path('g1', 's1');

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = GroupRepository(_MockFirestoreService(), firestore: db);
    await db.doc(session).set({
      'sessionId': 's1',
      'destination': 'Berlin',
      'status': 'completed',
      'totalPlacesToSwipe': 10,
      'participants': ['a', 'b', 'c', 'd'],
      'swipeProgress': <String, int>{},
      'createdAt': DateTime(2026, 10, 23),
    });
    for (final (id, likes) in [
      ('one', 1),
      ('two', 2),
      ('three', 3),
      ('all', 4)
    ]) {
      await db.doc('$session/votes/$id').set({'placeId': id, 'likes': likes});
    }
  });

  test('only places liked by a majority (at least 2) are matches', () async {
    final four = await repo.getQualifiedPlaces(
        groupId: 'g1', sessionId: 's1', participantCount: 4);
    expect(four.map((v) => v['placeId']), ['all', 'three']);

    final two = await repo.getQualifiedPlaces(
        groupId: 'g1', sessionId: 's1', participantCount: 2);
    expect(two.map((v) => v['placeId']), ['all', 'three', 'two']);
  });

  test('the day plan is stored on the session and read back', () async {
    await repo.saveDayPlan(
      'g1',
      's1',
      const DayPlan(placeIds: ['three', 'all'], endNearOrigin: false),
    );
    final data = (await db.doc(session).get()).data()!;
    final stored = GroupSessionModel.fromJson(data).dayPlan!;
    expect(stored.placeIds, ['three', 'all']);
    expect(stored.endNearOrigin, isFalse);
  });
}

String db0Path(String groupId, String sessionId) =>
    'groups/$groupId/sessions/$sessionId';
