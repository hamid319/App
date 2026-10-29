import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/common/utils/group_swipes.dart';
import 'package:swipetrip/features/group/data/trip_repository.dart';

void main() {
  late FakeFirebaseFirestore db;
  late TripRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = TripRepository(firestore: db);
  });

  Future<MemberSwipes> mine() async =>
      (await repo.streamSwipes('g').first).singleWhere((m) => m.uid == 'me');

  test('votes add up in one document per member, undo removes one', () async {
    await repo.setSwipeVote('g', 'me', 'p1', SwipeVote.like);
    await repo.setSwipeVote('g', 'me', 'p2', SwipeVote.superLike);
    await repo.setSwipeVote('g', 'me', 'p3', SwipeVote.nope);
    expect((await mine()).votes, {
      'p1': SwipeVote.like,
      'p2': SwipeVote.superLike,
      'p3': SwipeVote.nope,
    });

    await repo.setSwipeVote('g', 'me', 'p2', null);
    expect((await mine()).votes.keys, unorderedEquals(['p1', 'p3']));
  });

  test('a veto is also a nope, and moving it keeps one veto', () async {
    await repo.setSwipeVote('g', 'me', 'p1', SwipeVote.like);
    await repo.setSwipeVeto('g', 'me', 'p2');
    var m = await mine();
    expect(m.veto, 'p2');
    expect(m.votes['p2'], SwipeVote.nope);
    expect(m.votes['p1'], SwipeVote.like);

    await repo.setSwipeVeto('g', 'me', 'p3');
    m = await mine();
    expect(m.veto, 'p3');

    await repo.setSwipeVeto('g', 'me', null);
    expect((await mine()).veto, isNull);
  });

  test('check-ins merge into the user document', () async {
    await db.collection('users').doc('me').set({
      'uid': 'me',
      'favorites': ['x']
    });
    await repo.checkIn('me', 'lisbon');
    await repo.checkIn('me', 'porto');
    expect((await repo.streamCheckIns('me').first).keys,
        unorderedEquals(['lisbon', 'porto']));
    expect((await db.collection('users').doc('me').get()).data()!['favorites'],
        ['x']);
  });
}
