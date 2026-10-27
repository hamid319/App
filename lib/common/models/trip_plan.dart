import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';

/// The trip's day plan, stored on the group as `tripPlan`: for every trip
/// day the places in walking order. Built from the wishlist by any member.
@immutable
class TripPlan {
  final List<List<String>> days;
  final DateTime? updatedAt;

  const TripPlan({required this.days, this.updatedAt});

  bool get isEmpty => days.every((d) => d.isEmpty);

  int get stopCount => days.fold(0, (total, d) => total + d.length);

  List<String> get allPlaceIds => [for (final d in days) ...d];

  // Firestore has no nested arrays, so each day is a map.
  factory TripPlan.fromJson(Map<String, dynamic> json) => TripPlan(
        days: [
          for (final day in json['days'] as List? ?? const [])
            if (day is Map)
              [for (final id in day['placeIds'] as List? ?? const []) '$id'],
        ],
        updatedAt: json['updatedAt'] is Timestamp
            ? (json['updatedAt'] as Timestamp).toDate()
            : null,
      );

  /// Without [updatedAt] the server time is written.
  Map<String, dynamic> toJson() => {
        'days': [
          for (final day in days) {'placeIds': day},
        ],
        'updatedAt': updatedAt != null
            ? Timestamp.fromDate(updatedAt!)
            : FieldValue.serverTimestamp(),
      };
}
