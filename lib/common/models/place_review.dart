import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';

/// A user's review of a place, stored at `places/{placeId}/reviews/{uid}`:
/// one per user and place.
@immutable
class PlaceReview {
  /// Longest review text, kept in sync with firestore.rules.
  static const maxTextLength = 500;

  final String uid;
  final String placeId;

  /// 1 to 5 stars.
  final int rating;
  final String text;

  /// Display name at the time of writing; empty when the user has none.
  final String authorName;

  /// App language the review was written in ("en", "de").
  final String language;

  /// Set when someone reported the review; hidden reviews are not listed
  /// until a moderator clears the flag, but their stars still count.
  final bool hidden;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PlaceReview({
    required this.uid,
    required this.placeId,
    required this.rating,
    this.text = '',
    this.authorName = '',
    this.language = 'en',
    this.hidden = false,
    this.createdAt,
    this.updatedAt,
  });

  factory PlaceReview.fromJson(Map<String, dynamic> json) => PlaceReview(
        uid: json['uid'] as String,
        placeId: json['placeId'] as String,
        rating: (json['rating'] as num).toInt(),
        text: json['text'] as String? ?? '',
        authorName: json['authorName'] as String? ?? '',
        language: json['language'] as String? ?? 'en',
        hidden: json['hidden'] as bool? ?? false,
        createdAt: _date(json['createdAt']),
        updatedAt: _date(json['updatedAt']),
      );

  static DateTime? _date(Object? value) =>
      value is Timestamp ? value.toDate() : null;
}

/// Number of reviews of a place and their average stars.
@immutable
class ReviewSummary {
  /// The average is shown only from this many reviews on, so a single
  /// review does not decide how a place looks.
  static const minCountForAverage = 3;

  final int count;
  final double? average;

  const ReviewSummary({required this.count, this.average});

  static const empty = ReviewSummary(count: 0);

  bool get showsAverage => count >= minCountForAverage && average != null;
}
