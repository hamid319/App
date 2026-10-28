import '../models/trip_idea.dart';

/// A member's answer to a place in the trip's swipe deck.
enum SwipeVote {
  nope(0),
  like(1),
  superLike(2);

  const SwipeVote(this.value);

  /// Stored in `groups/{groupId}/swipes/{uid}.votes`.
  final int value;

  static SwipeVote? fromValue(Object? v) => switch (v) {
        0 => nope,
        1 => like,
        2 => superLike,
        _ => null,
      };
}

/// One member's swipes on a trip: `groups/{groupId}/swipes/{uid}`.
class MemberSwipes {
  const MemberSwipes({
    required this.uid,
    this.votes = const {},
    this.veto,
  });

  final String uid;

  /// Place id -> vote.
  final Map<String, SwipeVote> votes;

  /// The one place this member never wants to go to, if any.
  final String? veto;

  factory MemberSwipes.fromJson(String uid, Map<String, dynamic> json) {
    final raw = json['votes'];
    return MemberSwipes(
      uid: uid,
      votes: {
        if (raw is Map)
          for (final e in raw.entries)
            if (SwipeVote.fromValue(e.value) case final v?) '${e.key}': v,
      },
      veto: json['veto'] is String ? json['veto'] as String : null,
    );
  }
}

/// Likes a place needs to be a group match: a majority of the members and
/// at least 2 (product decision, POSSIBLE_ERRORS 10.1). Someone planning
/// alone matches with every like. 2 people: both, 3: 2, 4: 3, 5: 3.
int matchThreshold(int memberCount) {
  if (memberCount <= 1) return 1;
  final majority = memberCount ~/ 2 + 1;
  return majority < 2 ? 2 : majority;
}

/// How the group answered one place.
class PlaceTally {
  const PlaceTally({
    required this.placeId,
    required this.likedBy,
    required this.superLikedBy,
    required this.vetoedBy,
  });

  final String placeId;

  /// Everyone who liked it, super-likes included.
  final List<String> likedBy;
  final List<String> superLikedBy;
  final List<String> vetoedBy;

  /// Ranking points: a super-like counts twice.
  int get score => likedBy.length + superLikedBy.length;

  /// Not vetoed, and liked by enough members. A super-like makes a place a
  /// match as soon as one more member likes it.
  bool isMatch(int memberCount) =>
      vetoedBy.isEmpty &&
      (likedBy.length >= matchThreshold(memberCount) ||
          (superLikedBy.isNotEmpty && likedBy.length >= 2));
}

/// Every place someone liked or vetoed, by place id. Swipes of people who
/// left the trip are ignored ([members]).
Map<String, PlaceTally> tallySwipes(
    Iterable<MemberSwipes> swipes, List<String> members) {
  final liked = <String, List<String>>{};
  final superLiked = <String, List<String>>{};
  final vetoed = <String, List<String>>{};
  for (final m in swipes) {
    if (!members.contains(m.uid)) continue;
    m.votes.forEach((placeId, vote) {
      if (vote == SwipeVote.nope) return;
      (liked[placeId] ??= []).add(m.uid);
      if (vote == SwipeVote.superLike) (superLiked[placeId] ??= []).add(m.uid);
    });
    if (m.veto case final v?) (vetoed[v] ??= []).add(m.uid);
  }
  return {
    for (final id in {...liked.keys, ...vetoed.keys})
      id: PlaceTally(
        placeId: id,
        likedBy: liked[id] ?? const [],
        superLikedBy: superLiked[id] ?? const [],
        vetoedBy: vetoed[id] ?? const [],
      ),
  };
}

/// The trip's wishlist: the ideas members added, plus the group's swipe
/// matches as ideas of their own (not stored; derived from the swipes).
/// A match on a place that is already an idea adds its likes to that idea.
/// Vetoed matches are left out; ideas added by hand stay.
List<TripIdea> wishlistWithMatches(
  List<TripIdea> ideas,
  Map<String, PlaceTally> tallies,
  int memberCount,
) {
  final matches = {
    for (final t in tallies.values)
      if (t.isMatch(memberCount)) t.placeId: t,
  };
  final merged = [
    for (final idea in ideas)
      if (matches[idea.placeId] case final t?)
        TripIdea(
          id: idea.id,
          placeId: idea.placeId,
          title: idea.title,
          addedBy: idea.addedBy,
          likedBy: {...idea.likedBy, ...t.likedBy}.toList(),
          superLikes: t.superLikedBy.length,
          source: idea.source,
          createdAt: idea.createdAt,
        )
      else
        idea,
  ];
  final onList = {for (final i in ideas) i.placeId};
  for (final t in matches.values) {
    if (onList.contains(t.placeId)) continue;
    merged.add(TripIdea(
      id: swipeIdeaId(t.placeId),
      placeId: t.placeId,
      title: '',
      addedBy: t.likedBy.first,
      likedBy: t.likedBy,
      superLikes: t.superLikedBy.length,
      source: IdeaSource.swipe,
    ));
  }
  return sortIdeasByLikes(merged);
}

/// Id of a wishlist entry that exists only as a swipe match.
String swipeIdeaId(String placeId) => 'swipe:$placeId';

bool isSwipeMatchIdea(TripIdea idea) => idea.id.startsWith('swipe:');
