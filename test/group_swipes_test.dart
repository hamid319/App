import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/common/models/trip_idea.dart';
import 'package:swipetrip/common/utils/group_swipes.dart';

MemberSwipes _m(String uid, Map<String, SwipeVote> votes, {String? veto}) =>
    MemberSwipes(uid: uid, votes: votes, veto: veto);

const _like = SwipeVote.like;
const _super = SwipeVote.superLike;
const _nope = SwipeVote.nope;

void main() {
  test('match threshold: alone 1, else a majority of at least 2', () {
    expect([1, 2, 3, 4, 5, 6].map(matchThreshold), [1, 2, 2, 3, 3, 4]);
  });

  test('a majority makes a match, fewer likes do not', () {
    final members = ['a', 'b', 'c', 'd'];
    final t = tallySwipes([
      _m('a', {'p1': _like, 'p2': _like}),
      _m('b', {'p1': _like, 'p2': _nope}),
      _m('c', {'p1': _like}),
      _m('d', {'p1': _nope}),
    ], members);
    expect(t['p1']!.isMatch(4), isTrue); // 3 of 4
    expect(t['p2']!.isMatch(4), isFalse); // 1 of 4
  });

  test('a super-like matches with one more like', () {
    final members = ['a', 'b', 'c', 'd', 'e'];
    final t = tallySwipes([
      _m('a', {'p': _super}),
      _m('b', {'p': _like}),
    ], members);
    expect(t['p']!.likedBy, ['a', 'b']);
    expect(t['p']!.score, 3);
    expect(t['p']!.isMatch(5), isTrue); // threshold alone would be 3
  });

  test('one veto removes a match, however popular', () {
    final members = ['a', 'b', 'c'];
    final t = tallySwipes([
      _m('a', {'p': _super}),
      _m('b', {'p': _like}),
      _m('c', {'p': _like}, veto: 'p'),
    ], members);
    expect(t['p']!.isMatch(3), isFalse);
  });

  test('swipes of people who left the trip do not count', () {
    final t = tallySwipes([
      _m('a', {'p': _like}),
      _m('gone', {'p': _like}),
    ], ['a', 'b']);
    expect(t['p']!.likedBy, ['a']);
    expect(t['p']!.isMatch(2), isFalse);
  });

  test('wishlist: matches join the ideas, ranked, without duplicates', () {
    final members = ['a', 'b'];
    final tallies = tallySwipes([
      _m('a', {'p1': _super, 'p2': _like, 'p3': _like}),
      _m('b', {'p1': _like, 'p2': _like, 'p3': _like}, veto: 'p3'),
    ], members);
    final ideas = [
      const TripIdea(
          id: 'i1', placeId: 'p2', title: 'Tram', addedBy: 'a', likedBy: []),
      const TripIdea(id: 'i2', title: 'Fado bar', addedBy: 'b'),
    ];
    final list = wishlistWithMatches(ideas, tallies, 2);

    expect(list.map((i) => i.id), [swipeIdeaId('p1'), 'i1', 'i2']);
    expect(list.first.source, IdeaSource.swipe);
    expect(isSwipeMatchIdea(list.first), isTrue);
    // The existing idea for p2 took the swipe likes instead of a copy.
    expect(list[1].likedBy, containsAll(['a', 'b']));
    // p3 was vetoed.
    expect(list.any((i) => i.placeId == 'p3'), isFalse);
  });

  test('stored votes are read leniently', () {
    final m = MemberSwipes.fromJson('a', {
      'votes': {'p1': 1, 'p2': 2, 'p3': 0, 'p4': 7, 'p5': 'x'},
      'veto': 'p9',
    });
    expect(m.votes, {'p1': _like, 'p2': _super, 'p3': _nope});
    expect(m.veto, 'p9');
  });
}
