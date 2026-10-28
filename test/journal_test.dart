import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/common/models/group_model.dart';
import 'package:swipetrip/common/models/journal_entry.dart';
import 'package:swipetrip/common/models/trip_expense.dart';
import 'package:swipetrip/common/models/trip_plan.dart';
import 'package:swipetrip/common/utils/trip_journal.dart';
import 'package:swipetrip/features/group/data/journal_repository.dart';

class _FakeStore implements JournalPhotoStore {
  final files = <String>{};
  int uploads = 0;

  /// Index of the upload that fails, -1 for none.
  int failAt = -1;

  @override
  Future<String> upload(String path, Uint8List bytes,
      {required String authorUid}) async {
    if (uploads++ == failAt) throw Exception('network');
    files.add(path);
    return 'https://example.test/$path';
  }

  @override
  Future<void> delete(String path) async => files.remove(path);
}

JournalPhotoUpload _photo() =>
    (bytes: Uint8List.fromList([1, 2, 3]), width: 400, height: 300);

JournalEntry _entry(String day, {int photos = 0, String id = 'e'}) =>
    JournalEntry(
      id: id,
      authorUid: 'a',
      day: day,
      text: 'x',
      photos: [
        for (var i = 0; i < photos; i++)
          JournalPhoto(path: '$id/$i', url: 'u$id$i', width: 1, height: 1),
      ],
    );

void main() {
  group('JournalRepository', () {
    late FakeFirebaseFirestore db;
    late _FakeStore store;
    late JournalRepository repo;

    setUp(() {
      db = FakeFirebaseFirestore();
      store = _FakeStore();
      repo = JournalRepository(firestore: db, photos: store);
    });

    test('add uploads photos first, then writes the entry', () async {
      final progress = <int>[];
      final id = await repo.addEntry('g',
          authorUid: 'a',
          day: '2026-10-30',
          text: '  Pastéis  ',
          photos: [_photo(), _photo()],
          onProgress: (done, _) => progress.add(done));

      final entry = (await repo.streamEntries('g').first).single;
      expect(entry.id, id);
      expect(entry.text, 'Pastéis');
      expect(entry.photos.map((p) => p.path), [
        'trips/g/journal/$id/0.jpg',
        'trips/g/journal/$id/1.jpg',
      ]);
      expect(entry.photos.first.width, 400);
      expect(store.files, hasLength(2));
      expect(progress, [1, 2]);
    });

    test('a failed upload deletes the uploaded files and writes nothing',
        () async {
      store.failAt = 2;
      await expectLater(
        repo.addEntry('g',
            authorUid: 'a',
            day: '2026-10-30',
            text: '',
            photos: [_photo(), _photo(), _photo()]),
        throwsException,
      );
      expect(store.files, isEmpty);
      expect((await db.collection('groups/g/journal').get()).docs, isEmpty);
    });

    test('an entry needs text or a photo', () {
      expect(
          () =>
              repo.addEntry('g', authorUid: 'a', day: '2026-10-30', text: ' '),
          throwsArgumentError);
    });

    test('edit text, delete removes the photos and the entry', () async {
      await repo.addEntry('g',
          authorUid: 'a', day: '2026-10-30', text: 'a', photos: [_photo()]);
      var entry = (await repo.streamEntries('g').first).single;

      await repo.editText('g', entry, ' b ');
      entry = (await repo.streamEntries('g').first).single;
      expect(entry.text, 'b');

      await repo.deleteEntry('g', entry);
      expect(store.files, isEmpty);
      expect(await repo.streamEntries('g').first, isEmpty);
    });

    test('entries come by day, then by time', () async {
      await repo.addEntry('g', authorUid: 'a', day: '2026-10-31', text: '3');
      await repo.addEntry('g', authorUid: 'a', day: '2026-10-30', text: '1');
      await repo.addEntry('g', authorUid: 'b', day: '2026-10-30', text: '2');
      final entries = await repo.streamEntries('g').first;
      expect(entries.map((e) => e.text), ['1', '2', '3']);
    });
  });

  group('day grouping', () {
    final days = [DateTime(2026, 10, 29), DateTime(2026, 10, 30)];

    test('trip days are numbered, other days only dated', () {
      final grouped = groupJournalByDay([
        _entry('2026-10-28', id: '0'),
        _entry('2026-10-30', id: '1'),
        _entry('2026-10-30', id: '2'),
      ], days);
      expect(grouped.map((d) => d.tripDay), [null, 2]);
      expect(grouped.last.date, DateTime(2026, 10, 30));
      expect(grouped.last.entries.map((e) => e.id), ['1', '2']);
    });

    test('new entries default to today during the trip, else day one', () {
      expect(defaultJournalDay(days, DateTime(2026, 10, 30, 15)),
          DateTime(2026, 10, 30));
      expect(defaultJournalDay(days, DateTime(2026, 11, 5)), days.first);
      expect(defaultJournalDay(const [], DateTime(2026, 11, 5, 9)),
          DateTime(2026, 11, 5));
    });
  });

  group('recap', () {
    final group = GroupModel(
      groupId: 'g',
      members: const ['a', 'b', 'c'],
      tripStart: DateTime(2026, 10, 29),
      tripEnd: DateTime(2026, 11, 1),
      tripPlan: const TripPlan(days: [
        ['p1', 'p2'],
        ['p3'],
      ]),
    );

    test('stats count days, plan places, photos and costs per person', () {
      final stats = tripRecapStats(
        group,
        entries: [
          _entry('2026-10-29', photos: 2),
          _entry('2026-10-30', photos: 1)
        ],
        expenses: const [
          TripExpense(
              id: '1',
              title: 't',
              amountCents: 1000,
              paidBy: 'a',
              participants: ['a', 'b', 'c'],
              createdBy: 'a'),
          TripExpense(
              id: '2',
              title: 't',
              amountCents: 500,
              paidBy: 'b',
              participants: ['b'],
              createdBy: 'b'),
        ],
        ideaCount: 9,
      );
      expect(stats.days, 4);
      expect(stats.members, 3);
      expect(stats.places, 3);
      expect(stats.photos, 3);
      expect(stats.totalCents, 1500);
      expect(stats.perPersonCents, 500);
    });

    test('without a plan the wishlist counts; undated trips count entry days',
        () {
      final stats = tripRecapStats(
        GroupModel(groupId: 'g', members: const ['a']),
        entries: [
          _entry('2026-10-29'),
          _entry('2026-10-29'),
          _entry('2026-11-02')
        ],
        expenses: const [],
        ideaCount: 4,
      );
      expect(stats.places, 4);
      expect(stats.days, 2);
      expect(stats.perPersonCents, 0);
    });

    test('collage: newest photo of each day first, then the rest', () {
      final photos = recapPhotos([
        _entry('2026-10-29', photos: 3, id: 'a'),
        _entry('2026-10-30', photos: 2, id: 'b'),
      ], max: 4);
      expect(photos.map((p) => p.path), ['b/1', 'a/2', 'b/0', 'a/1']);
    });
  });
}
