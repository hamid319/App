import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/common/models/sync_status.dart';
import 'package:swipetrip/common/models/trip_expense.dart';
import 'package:swipetrip/common/utils/money.dart';
import 'package:swipetrip/core/errors/user_message.dart';
import 'package:swipetrip/features/group/data/trip_repository.dart';
import 'package:swipetrip/l10n/app_localizations_de.dart';

void main() {
  late FakeFirebaseFirestore db;
  late TripRepository repo;

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = TripRepository(firestore: db);
    await db.collection('groups').doc('g').set({
      'groupId': 'g',
      'groupName': 'Lisbon',
      'members': ['a', 'b'],
    });
    await db.collection('groups').doc('other').set({
      'groupId': 'other',
      'members': ['b'],
    });
  });

  Future<TripExpense> addDinner() async {
    final id = await repo.addExpense(
      'g',
      TripExpense(
        id: '',
        title: 'Dinner',
        amountCents: 4500,
        paidBy: 'a',
        participants: const ['a', 'b'],
        createdBy: 'a',
        createdAt: DateTime(2026, 6, 1),
      ),
    );
    return (await repo.streamExpenses('g').first).singleWhere((e) => e.id == id);
  }

  group('expenses: edit and delete', () {
    test('the creator edits title, amount, payer and participants', () async {
      final dinner = await addDinner();
      await repo.updateExpense(
        'g',
        dinner.copyWith(
          title: 'Dinner + wine',
          amountCents: 5200,
          paidBy: 'b',
          participants: ['b'],
        ),
        uid: 'a',
      );
      final saved = (await repo.streamExpenses('g').first).single;
      expect(saved.title, 'Dinner + wine');
      expect(saved.amountCents, 5200);
      expect(saved.paidBy, 'b');
      expect(saved.participants, ['b']);
      // Creator and creation time are untouched (the rules require it).
      expect(saved.createdBy, 'a');
      expect(saved.createdAt, DateTime(2026, 6, 1));
    });

    test('an edit is validated like a new expense', () async {
      final dinner = await addDinner();
      expect(
        () => repo.updateExpense('g', dinner.copyWith(amountCents: 0),
            uid: 'a'),
        throwsArgumentError,
      );
    });

    test('a non-creator can neither edit nor delete', () async {
      final dinner = await addDinner();
      await expectLater(
        repo.updateExpense('g', dinner.copyWith(amountCents: 1), uid: 'b'),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        repo.deleteExpense('g', dinner, uid: 'b'),
        throwsA(isA<StateError>()),
      );
      // Signed out counts as nobody.
      await expectLater(
        repo.deleteExpense('g', dinner, uid: ''),
        throwsA(isA<StateError>()),
      );
      final stored = (await repo.streamExpenses('g').first).single;
      expect(stored.amountCents, 4500);
    });

    test('the creator deletes, and balances lose the expense', () async {
      final dinner = await addDinner();
      await repo.deleteExpense('g', dinner, uid: 'a');
      expect(await repo.streamExpenses('g').first, isEmpty);
    });

    test('isEditableBy only for the creator', () {
      const e = TripExpense(
        id: 'x',
        title: 't',
        amountCents: 1,
        paidBy: 'b',
        participants: ['b'],
        createdBy: 'a',
      );
      expect(e.isEditableBy('a'), isTrue);
      // Paying is not owning.
      expect(e.isEditableBy('b'), isFalse);
      expect(e.isEditableBy(''), isFalse);
    });

    test('the guard message is translated', () {
      final de = AppLocalizationsDe();
      expect(
        userMessage(StateError(TripExpense.notCreatorMessage),
            fallback: 'x', l10n: de),
        de.errorExpenseNotCreator,
      );
    });
  });

  group('add a place to a trip', () {
    test('adds a manual idea with the place, liked by the adder', () async {
      final result = await repo.addPlaceIdea('g',
          placeId: 'wd_Q1', title: 'Oceanário', uid: 'a');
      expect(result.added, isTrue);
      final idea = (await repo.streamIdeas('g').first).single;
      expect(idea.id, result.id);
      expect(idea.placeId, 'wd_Q1');
      expect(idea.title, 'Oceanário');
      expect(idea.likedBy, ['a']);
      final raw =
          (await db.doc('groups/g/ideas/${result.id}').get()).data()!;
      // Must stay a value the rules' isValidIdea accepts.
      expect(raw['source'], 'manual');
    });

    test('a place already on the wishlist is not added twice', () async {
      final first = await repo.addPlaceIdea('g',
          placeId: 'wd_Q1', title: 'Oceanário', uid: 'a');
      final second = await repo.addPlaceIdea('g',
          placeId: 'wd_Q1', title: 'Oceanário', uid: 'b');
      expect(second.added, isFalse);
      expect(second.id, first.id);
      expect(await repo.streamIdeas('g').first, hasLength(1));
    });

    test('streamHasPlaceIdea follows the wishlist', () async {
      expect(await repo.streamHasPlaceIdea('g', 'wd_Q1').first, isFalse);
      await repo.addPlaceIdea('g',
          placeId: 'wd_Q1', title: 'Oceanário', uid: 'a');
      expect(await repo.streamHasPlaceIdea('g', 'wd_Q1').first, isTrue);
      expect(await repo.streamHasPlaceIdea('g', 'wd_Q2').first, isFalse);
    });

    test('streamUserTrips lists only trips the user is in', () async {
      final a = await repo.streamUserTrips('a').first;
      expect(a.map((g) => g.groupId), ['g']);
      final b = await repo.streamUserTrips('b').first;
      expect(b.map((g) => g.groupId).toSet(), {'g', 'other'});
    });
  });

  group('offline state', () {
    test('cache beats pending writes, pending writes beat synced', () {
      expect(SyncStatus.combine(const []), SyncStatus.synced);
      expect(
        SyncStatus.combine(const [
          (fromCache: false, pendingWrites: false),
          (fromCache: false, pendingWrites: true),
        ]),
        SyncStatus.syncing,
      );
      expect(
        SyncStatus.combine(const [
          (fromCache: false, pendingWrites: true),
          (fromCache: true, pendingWrites: false),
        ]),
        SyncStatus.offline,
      );
    });

    test('trip sync status emits from snapshot metadata', () async {
      // The fake serves from "server": nothing to show.
      expect(await repo.streamTripSyncStatus('g').first, SyncStatus.synced);
    });
  });

  group('amount input', () {
    test('round-trips through parseAmountToCents in both languages', () {
      for (final cents in [1, 50, 1250, 4500, 123456]) {
        for (final locale in ['de', 'en']) {
          final input = centsToAmountInput(cents, locale);
          expect(parseAmountToCents(input), cents, reason: '$locale $input');
        }
      }
      expect(centsToAmountInput(1250, 'de'), '12,50');
      expect(centsToAmountInput(1250, 'en'), '12.50');
    });
  });
}
