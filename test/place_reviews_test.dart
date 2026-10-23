import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/common/models/place_review.dart';
import 'package:swipetrip/features/places/data/review_repository.dart';

void main() {
  late FakeFirebaseFirestore db;
  late ReviewRepository repo;

  Future<void> review(String uid, int rating, {String text = ''}) =>
      repo.saveReview(
        placeId: 'wd_Q1',
        uid: uid,
        rating: rating,
        text: text,
        authorName: 'Name $uid',
        language: 'de',
      );

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = ReviewRepository(firestore: db);
  });

  test('one review per user and place, editing keeps it a single review',
      () async {
    await review('u1', 4, text: '  Schöner Blick  ');
    await review('u1', 5, text: 'Noch schöner');

    final mine = await repo.myReview('wd_Q1', 'u1');
    expect(mine?.rating, 5);
    expect(mine?.text, 'Noch schöner');
    expect(mine?.authorName, 'Name u1');
    expect(mine?.hidden, isFalse);
    expect((await repo.watchReviews('wd_Q1').first).length, 1);
  });

  test('the average shows only from three reviews on', () async {
    await review('u1', 5);
    await review('u2', 4);
    var summary = await repo.summary('wd_Q1');
    expect(summary.count, 2);
    expect(summary.showsAverage, isFalse);

    await review('u3', 3);
    summary = await repo.summary('wd_Q1');
    expect(summary.count, 3);
    expect(summary.average, closeTo(4.0, 0.001));
    expect(summary.showsAverage, isTrue);
    expect(await repo.summary('wd_Q2'), same(ReviewSummary.empty));
  });

  test('a report hides the review from the list but keeps its stars',
      () async {
    await review('u1', 1, text: 'Unfreundlicher Text');
    await review('u2', 5);

    await repo.reportReview(
        placeId: 'wd_Q1', authorUid: 'u1', reporterUid: 'u2');

    final visible = await repo.watchReviews('wd_Q1').first;
    expect(visible.map((r) => r.uid), ['u2']);
    expect((await repo.summary('wd_Q1')).count, 2);
    final report = await db
        .doc('places/wd_Q1/reviews/u1/reports/u2')
        .get();
    expect(report.exists, isTrue);

    // Editing does not unhide a reported review.
    await review('u1', 2, text: 'Neuer Text');
    expect((await repo.myReview('wd_Q1', 'u1'))?.hidden, isTrue);
  });

  test('deleting removes the review', () async {
    await review('u1', 3);
    await repo.deleteReview('wd_Q1', 'u1');
    expect(await repo.myReview('wd_Q1', 'u1'), isNull);
  });
}
