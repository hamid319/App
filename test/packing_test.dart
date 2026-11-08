import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/common/models/group_model.dart';
import 'package:swipetrip/common/models/packing.dart';
import 'package:swipetrip/common/utils/packing_template.dart';
import 'package:swipetrip/common/utils/suitcase_progress.dart';
import 'package:swipetrip/features/group/data/packing_repository.dart';

void main() {
  group('suggestedPackingList', () {
    test('counts clothes by days and picks summer things', () {
      final list = suggestedPackingList(
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 7, 5),
        countryCode: 'GB',
      );
      final byKey = {for (final i in list) i.key: i};
      expect(byKey['socks']!.qty, 5);
      expect(byKey['tshirts']!.qty, 5);
      expect(byKey, contains('sunscreen'));
      expect(byKey, isNot(contains('gloves')));
      expect(byKey, contains('plugAdapter'));
      expect(list.map((i) => i.id).toSet().length, list.length);
    });

    test('winter, long trip, no adapter in Germany', () {
      final list = suggestedPackingList(
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 1, 20),
        countryCode: 'DE',
      );
      final byKey = {for (final i in list) i.key: i};
      expect(byKey['tshirts']!.qty, 7);
      expect(byKey['underwear']!.qty, 10);
      expect(byKey, contains('gloves'));
      expect(byKey, isNot(contains('plugAdapter')));
    });

    test('without dates: no counts, rain jacket', () {
      final list = suggestedPackingList();
      expect(list.every((i) => i.qty == null), isTrue);
      expect(list.any((i) => i.key == 'rainJacket'), isTrue);
    });
  });

  test('progress counts own items and shared ones the user brings', () {
    const mine = [
      PackingItem(id: 'a', category: PackingCategory.own, done: true),
      PackingItem(id: 'b', category: PackingCategory.own),
    ];
    const shared = [
      SharedPackingItem(
          id: 's1',
          title: 'Speaker',
          addedBy: 'x',
          bringer: 'me',
          packed: true),
      SharedPackingItem(
          id: 's2', title: 'Cards', addedBy: 'x', bringer: 'other'),
      SharedPackingItem(id: 's3', title: 'Shampoo', addedBy: 'x'),
    ];
    final p = packingProgressOf(mine, shared, 'me');
    expect((p.done, p.total, p.percent, p.complete), (2, 3, 67, false));
    expect(const PackingProgress(done: 0, total: 0).complete, isFalse);
  });

  test('reminder the evening before, skipped when packed or past', () {
    final now = DateTime(2026, 6, 1, 12);
    final trips = [
      GroupModel(groupId: 'soon', tripStart: DateTime(2026, 6, 10)),
      GroupModel(groupId: 'packed', tripStart: DateTime(2026, 6, 10)),
      GroupModel(groupId: 'past', tripStart: DateTime(2026, 6, 1)),
      const GroupModel(groupId: 'undated'),
    ];
    final times = packingReminderTimes(trips, {'packed'}, now);
    expect(times.map((t) => t.trip.groupId), ['soon']);
    expect(times.single.at, DateTime(2026, 6, 9, 18));
  });

  test('packed trips add miles', () {
    expect(
      suitcaseProgress(trips: 1, stamps: const [], packedTrips: 2).miles,
      milesPerTrip + 2 * milesPerPackedTrip,
    );
  });

  test('repository: own list stays private, progress and shared list',
      () async {
    final db = FakeFirebaseFirestore();
    final repo = PackingRepository(firestore: db);
    final items = suggestedPackingList();
    final done = [items.first.copyWith(done: true), ...items.skip(1)];
    await repo.saveMyList(
        'u1', 'g1', done, packingProgressOf(done, const [], 'u1'));

    expect((await repo.streamMyList('u1', 'g1').first)!.first.done, isTrue);
    final progress = await repo.streamProgress('g1').first;
    expect(progress['u1']!.done, 1);
    expect(progress['u1']!.total, items.length);
    final progressDoc = await db.doc('groups/g1/packingProgress/u1').get();
    expect(progressDoc.data()!.keys, isNot(contains('items')));

    await repo.addShared('g1', '  Speaker  ', 'u2');
    final shared = await repo.streamShared('g1').first;
    expect(shared.single.title, 'Speaker');
    expect(shared.single.bringer, isNull);
    await repo.setBringer('g1', shared.single.id, 'u1');
    await repo.setSharedPacked('g1', shared.single.id, true);
    final taken = (await repo.streamShared('g1').first).single;
    expect((taken.bringer, taken.packed), ('u1', true));

    await repo.saveProgress(
        'u1', 'g1', const PackingProgress(done: 3, total: 3));
    expect(await repo.streamPackedTripIds('u1').first, {'g1'});
    // Saving progress keeps the own list.
    expect(await repo.streamMyList('u1', 'g1').first, isNotNull);
  });
}
