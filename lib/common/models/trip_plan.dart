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

  // Manual edits. Each returns a new plan without [updatedAt], so saving it
  // writes the server time.

  List<List<String>> get _copy => [
        for (final d in days) [...d]
      ];

  /// Moves the stop at [from] to [to] within [day] ([to] as in the list
  /// after removing it).
  TripPlan reorder(int day, int from, int to) {
    final copy = _copy;
    if (day >= copy.length || from < 0 || from >= copy[day].length) {
      return this;
    }
    final id = copy[day].removeAt(from);
    copy[day].insert(to.clamp(0, copy[day].length), id);
    return TripPlan(days: copy);
  }

  /// Takes [placeId] out of whichever day has it and adds it at the end of
  /// [day]; also how a wishlist place is added.
  TripPlan moveToDay(String placeId, int day) {
    if (day < 0 || day >= days.length) return this;
    final copy = [
      for (final d in days) d.where((id) => id != placeId).toList()
    ];
    copy[day].add(placeId);
    return TripPlan(days: copy);
  }

  TripPlan remove(String placeId) => TripPlan(days: [
        for (final d in days) d.where((id) => id != placeId).toList(),
      ]);

  /// Swaps the stops of two days, e.g. when it rains on one of them.
  TripPlan swapDays(int a, int b) {
    if (a == b || a >= days.length || b >= days.length) return this;
    final copy = _copy;
    final first = copy[a];
    copy[a] = copy[b];
    copy[b] = first;
    return TripPlan(days: copy);
  }

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
