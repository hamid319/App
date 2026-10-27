import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/common/models/group_model.dart';
import 'package:swipetrip/common/models/trip_expense.dart';
import 'package:swipetrip/common/models/trip_idea.dart';
import 'package:swipetrip/common/models/trip_plan.dart';
import 'package:swipetrip/common/models/trip_poll.dart';
import 'package:swipetrip/common/models/user_model.dart';

void main() {
  final created = DateTime(2026, 10, 20, 12);

  test('TripIdea round trip and defaults', () {
    final idea = TripIdea(
      id: 'i1',
      placeId: 'wd_Q1',
      title: 'Oceanário',
      addedBy: 'lea',
      likedBy: const ['lea', 'ozan'],
      source: IdeaSource.swipe,
      createdAt: created,
    );
    final json = idea.toJson();
    expect(json['source'], 'swipe');
    expect(json['createdAt'], Timestamp.fromDate(created));
    final back = TripIdea.fromJson('i1', json);
    expect(back.placeId, 'wd_Q1');
    expect(back.likes, 2);
    expect(back.isLikedBy('ozan'), isTrue);
    expect(back.source, IdeaSource.swipe);
    expect(back.createdAt, created);

    final empty = TripIdea.fromJson('x', {'placeId': ''});
    expect(empty.placeId, isNull);
    expect(empty.source, IdeaSource.manual);
    expect(empty.likedBy, isEmpty);
    expect(const TripIdea(id: 'n', title: 't', addedBy: 'a').toJson()['createdAt'],
        isA<FieldValue>());
  });

  test('sortIdeasByLikes: most liked first, then oldest', () {
    final ideas = [
      TripIdea(id: 'a', title: 'a', addedBy: 'x', likedBy: const ['1'], createdAt: DateTime(2026, 1, 2)),
      TripIdea(id: 'b', title: 'b', addedBy: 'x', likedBy: const ['1', '2'], createdAt: DateTime(2026, 1, 3)),
      TripIdea(id: 'c', title: 'c', addedBy: 'x', likedBy: const ['1'], createdAt: DateTime(2026, 1, 1)),
    ];
    expect(sortIdeasByLikes(ideas).map((i) => i.id), ['b', 'c', 'a']);
  });

  test('TripPoll round trip and vote counts', () {
    final poll = TripPoll(
      id: 'p',
      question: 'Wo übernachten wir?',
      options: const [
        PollOption(id: 'o0', label: 'Alfama'),
        PollOption(id: 'o1', label: 'Bairro Alto'),
      ],
      votes: const {'a': 'o0', 'b': 'o0', 'c': 'o1', 'd': 'gone'},
      createdBy: 'a',
      createdAt: created,
    );
    final back = TripPoll.fromJson('p', poll.toJson());
    expect(back.options.map((o) => o.label), ['Alfama', 'Bairro Alto']);
    expect(back.votesFor('o0'), 2);
    expect(back.votersFor('o1'), ['c']);
    expect(back.voteOf('b'), 'o0');
    expect(back.voterCount, 3);
    expect(back.closed, isFalse);
    expect(back.createdAt, created);
  });

  test('TripExpense round trip', () {
    final expense = TripExpense(
      id: 'e',
      title: 'Abendessen',
      amountCents: 14700,
      paidBy: 'lea',
      participants: const ['lea', 'ozan'],
      createdBy: 'lea',
      createdAt: created,
    );
    final json = expense.toJson();
    expect(json['amountCents'], 14700);
    expect(json['currency'], 'EUR');
    final back = TripExpense.fromJson('e', json);
    expect(back.amountCents, 14700);
    expect(back.participants, ['lea', 'ozan']);
    expect(back.paidBy, 'lea');
    expect(back.createdAt, created);
    expect(TripExpense.fromJson('z', {'amountCents': 12.0}).amountCents, 12);
  });

  test('TripPlan stores days as maps and is read back from the group', () {
    final plan = TripPlan(days: const [
      ['a', 'b'],
      [],
      ['c'],
    ], updatedAt: created);
    final json = plan.toJson();
    expect(json['days'], [
      {'placeIds': ['a', 'b']},
      {'placeIds': <String>[]},
      {'placeIds': ['c']},
    ]);
    final group = GroupModel.fromJson({'groupId': 'g', 'tripPlan': json});
    expect(group.tripPlan!.days, [
      ['a', 'b'],
      <String>[],
      ['c'],
    ]);
    expect(group.tripPlan!.stopCount, 3);
    expect(group.tripPlan!.allPlaceIds, ['a', 'b', 'c']);
    expect(const TripPlan(days: [[]]).isEmpty, isTrue);
    expect(GroupModel.fromJson({'groupId': 'g'}).tripPlan, isNull);
  });

  test('UserModel keeps an optional PayPal handle', () {
    final user = UserModel.fromJson(
        {'uid': 'u', 'email': '', 'paypalHandle': 'lea'});
    expect(user.paypalHandle, 'lea');
    expect(user.toJson()['paypalHandle'], 'lea');
    expect(user.withPaypalHandle('  ').paypalHandle, isNull);
    expect(const UserModel(uid: 'u', email: '').toJson().containsKey('paypalHandle'),
        isFalse);
  });
}
