import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';

@immutable
class GroupSessionModel {
  const GroupSessionModel({
    required this.sessionId,
    required this.destination,
    required this.status,
    required this.totalPlacesToSwipe,
    required this.participants,
    required this.threshold,
    required this.swipeProgress,
    required this.createdAt,
    this.endedAt,
    this.endedByUid,
  });

  final String sessionId;
  final String destination; // "Tokyo" or "Germany" -- user-chosen string
  final String status; // 'in_progress' | 'completed'
  final int totalPlacesToSwipe;
  final List<String> participants;
  final int threshold; // Min likes to qualify
  final Map<String, int> swipeProgress; // { uid: swipeCount }
  final DateTime createdAt;
  final DateTime? endedAt; // Set on session close
  final String? endedByUid; // null = auto-end, uid = manual end

  bool get isCompleted => status == 'completed';

  /// Auto-end check: every participant has swiped every card
  bool get allMembersDone =>
      participants.isNotEmpty &&
      totalPlacesToSwipe > 0 &&
      participants.every(
        (uid) => (swipeProgress[uid] ?? 0) >= totalPlacesToSwipe,
      );

  GroupSessionModel copyWith({
    String? sessionId,
    String? destination,
    String? status,
    int? totalPlacesToSwipe,
    List<String>? participants,
    int? threshold,
    Map<String, int>? swipeProgress,
    DateTime? createdAt,
    DateTime? endedAt,
    String? endedByUid,
  }) {
    return GroupSessionModel(
      sessionId: sessionId ?? this.sessionId,
      destination: destination ?? this.destination,
      status: status ?? this.status,
      totalPlacesToSwipe: totalPlacesToSwipe ?? this.totalPlacesToSwipe,
      participants: participants ?? this.participants,
      threshold: threshold ?? this.threshold,
      swipeProgress: swipeProgress ?? this.swipeProgress,
      createdAt: createdAt ?? this.createdAt,
      endedAt: endedAt ?? this.endedAt,
      endedByUid: endedByUid ?? this.endedByUid,
    );
  }

  factory GroupSessionModel.fromJson(Map<String, dynamic> json) {
    final createdAt = _parseDateTime(json['createdAt']);
    if (createdAt == null) {
      throw FormatException('Invalid createdAt for GroupSessionModel');
    }

    return GroupSessionModel(
      sessionId: json['sessionId'] as String,
      destination: json['destination'] as String,
      status: json['status'] as String? ?? 'in_progress',
      totalPlacesToSwipe: _parseInt(json['totalPlacesToSwipe']),
      participants: _stringList(json['participants']),
      threshold: _parseInt(json['threshold']),
      swipeProgress: _intMap(json['swipeProgress']),
      createdAt: createdAt,
      endedAt: _parseDateTime(json['endedAt']),
      endedByUid: json['endedByUid'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'destination': destination,
        'status': status,
        'totalPlacesToSwipe': totalPlacesToSwipe,
        'participants': participants,
        'threshold': threshold,
        'swipeProgress': swipeProgress,
        'createdAt': Timestamp.fromDate(createdAt),
        if (endedAt != null) 'endedAt': Timestamp.fromDate(endedAt!),
        if (endedByUid != null) 'endedByUid': endedByUid,
      };
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList();
  }
  return const <String>[];
}

Map<String, int> _intMap(dynamic value) {
  if (value is Map) {
    final result = <String, int>{};
    value.forEach((key, item) {
      result[key.toString()] = _parseInt(item);
    });
    return result;
  }
  return const <String, int>{};
}
