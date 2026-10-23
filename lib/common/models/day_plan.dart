import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';

/// The day plan the group admin builds from a finished session's matches,
/// stored on the session as `dayPlan`. Members only read it.
@immutable
class DayPlan {
  /// Places in visiting order.
  final List<String> placeIds;

  /// True: the route ends near where the admin is (e.g. the accommodation)
  /// and starts at the farthest place. False: it starts near them.
  final bool endNearOrigin;
  final DateTime? updatedAt;

  const DayPlan({
    required this.placeIds,
    this.endNearOrigin = true,
    this.updatedAt,
  });

  factory DayPlan.fromJson(Map<String, dynamic> json) => DayPlan(
        placeIds: (json['placeIds'] as List? ?? const [])
            .map((id) => id.toString())
            .toList(),
        endNearOrigin: json['endNearOrigin'] as bool? ?? true,
        updatedAt: json['updatedAt'] is Timestamp
            ? (json['updatedAt'] as Timestamp).toDate()
            : null,
      );

  Map<String, dynamic> toJson() => {
        'placeIds': placeIds,
        'endNearOrigin': endNearOrigin,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
