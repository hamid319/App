import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/common/models/trip_expense.dart';
import 'package:swipetrip/common/models/trip_plan.dart';
import 'package:swipetrip/features/group/data/trip_repository.dart';

void main() {
  late FakeFirebaseFirestore db;
  late TripRepository repo;

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = TripRepository(firestore: db);
    await db.collection('groups').doc('g').set({
      'groupId': 'g',
      'members': ['a', 'b'],
    });
  });

  test('a bad legacy day plan does not hide the trip or other trips', () async {
    await db.doc('groups/bad-plan').set({
      'groupId': 'bad-plan',
      'members': ['a'],
      'tripPlan': {
        'days': [
          {'placeIds': 'broken'},
          {'placeIds': ['p1', 17, 'invalid/path']},
        ],
      },
    });
    final trips = await repo.streamUserTrips('a').first;
    expect(trips.map((g) => g.groupId), unorderedEquals(['g', 'bad-plan']));
    expect(trips.singleWhere((g) => g.groupId == 'bad-plan').tripPlan!.days,
        [<String>[], ['p1']]);
  });

  test('malformed legacy receipt items and options cannot hide valid records',
      () async {
    const expense = TripExpense(
        id: '', title: 'Meal', amountCents: 100, paidBy: 'a',
        participants: ['a'], createdBy: 'a');
    final expenseId = await repo.addExpense('g', expense);
    await db.doc('groups/g/expenses/malformed').set({
      ...expense.toJson(),
      'items': [{'id': 'i0', 'name': 42, 'amountCents': 100}],
    });
    final pollId = await repo.createPoll('g',
        question: 'Where?', options: ['Market', 'Park'], uid: 'a');
    await db.doc('groups/g/polls/malformed').set({
      'question': 'Bad option',
      'options': [{'id': 'o0', 'label': 17}],
    });
    expect((await repo.streamExpenses('g').first).single.id, expenseId);
    expect((await repo.streamPolls('g').first).single.id, pollId);
  });

  test('ideas: the author likes their idea, likes toggle per uid', () async {
    final id = await repo.addIdea('g', title: '  Oceanário ', uid: 'a', placeId: 'p1');
    var ideas = await repo.streamIdeas('g').first;
    expect(ideas.single.title, 'Oceanário');
    expect(ideas.single.likedBy, ['a']);

    await repo.setIdeaLiked('g', id, 'b', true);
    await repo.setIdeaLiked('g', id, 'a', false);
    ideas = await repo.streamIdeas('g').first;
    expect(ideas.single.likedBy, ['b']);

    expect(() => repo.addIdea('g', title: ' ', uid: 'a'), throwsArgumentError);
  });

  test('polls: one vote per member, voting again changes or clears it',
      () async {
    final id = await repo.createPoll('g',
        question: 'Wo?', options: ['Alfama', ' ', 'Bairro Alto'], uid: 'a');
    var poll = (await repo.streamPolls('g').first).single;
    expect(poll.options.map((o) => o.label), ['Alfama', 'Bairro Alto']);

    await repo.vote('g', id, 'a', poll.options.first.id);
    await repo.vote('g', id, 'b', poll.options.first.id);
    await repo.vote('g', id, 'b', poll.options.last.id);
    poll = (await repo.streamPolls('g').first).single;
    expect(poll.votesFor('o0'), 1);
    expect(poll.votesFor('o1'), 1);

    await repo.vote('g', id, 'a', null);
    poll = (await repo.streamPolls('g').first).single;
    expect(poll.voteOf('a'), isNull);

    expect(() => repo.createPoll('g', question: 'Q', options: ['one'], uid: 'a'),
        throwsArgumentError);
  });

  test('expenses: validated and stored in cents', () async {
    await repo.addExpense(
      'g',
      const TripExpense(
        id: '',
        title: 'Dinner',
        amountCents: 4500,
        paidBy: 'a',
        participants: ['a', 'b'],
        createdBy: 'a',
      ),
    );
    final list = await repo.streamExpenses('g').first;
    expect(list.single.amountCents, 4500);
    expect(list.single.currency, 'EUR');

    expect(
      () => repo.addExpense(
        'g',
        const TripExpense(
          id: '',
          title: 'Zero',
          amountCents: 0,
          paidBy: 'a',
          participants: ['a'],
          createdBy: 'a',
        ),
      ),
      throwsArgumentError,
    );
  });

  test('the day plan is saved on the group', () async {
    await repo.saveTripPlan('g', const TripPlan(days: [['p1', 'p2'], ['p3']]));
    final data = (await db.collection('groups').doc('g').get()).data()!;
    expect((data['tripPlan'] as Map)['days'], [
      {'placeIds': ['p1', 'p2']},
      {'placeIds': ['p3']},
    ]);
  });
}
