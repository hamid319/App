import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';

/// Where an idea on a trip's wishlist came from.
enum IdeaSource {
  manual,
  swipe,
  link;

  static IdeaSource fromJson(Object? value) => switch (value) {
        'swipe' => IdeaSource.swipe,
        'link' => IdeaSource.link,
        _ => IdeaSource.manual,
      };
}

/// One entry of a trip's wishlist: `groups/{groupId}/ideas/{ideaId}`.
/// Ideas with a [placeId] can go into the day plan.
@immutable
class TripIdea {
  final String id;
  final String? placeId;
  final String title;
  final String addedBy;
  final List<String> likedBy;
  final IdeaSource source;
  final DateTime? createdAt;

  const TripIdea({
    required this.id,
    this.placeId,
    required this.title,
    required this.addedBy,
    this.likedBy = const [],
    this.source = IdeaSource.manual,
    this.createdAt,
  });

  int get likes => likedBy.length;

  bool isLikedBy(String uid) => likedBy.contains(uid);

  factory TripIdea.fromJson(String id, Map<String, dynamic> json) => TripIdea(
        id: id,
        placeId: (json['placeId'] as String?)?.isEmpty == true
            ? null
            : json['placeId'] as String?,
        title: json['title'] as String? ?? '',
        addedBy: json['addedBy'] as String? ?? '',
        likedBy: [for (final uid in json['likedBy'] as List? ?? const []) '$uid'],
        source: IdeaSource.fromJson(json['source']),
        createdAt: _date(json['createdAt']),
      );

  /// Without [createdAt] the server time is written.
  Map<String, dynamic> toJson() => {
        'placeId': placeId,
        'title': title,
        'addedBy': addedBy,
        'likedBy': likedBy,
        'source': source.name,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
      };
}

/// Most liked first; equal likes keep the order they were added in.
List<TripIdea> sortIdeasByLikes(Iterable<TripIdea> ideas) {
  final list = List.of(ideas);
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  list.sort((a, b) {
    final byLikes = b.likes.compareTo(a.likes);
    if (byLikes != 0) return byLikes;
    final byTime = (a.createdAt ?? epoch).compareTo(b.createdAt ?? epoch);
    if (byTime != 0) return byTime;
    return a.id.compareTo(b.id);
  });
  return list;
}

DateTime? _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  return null;
}
