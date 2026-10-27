import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';

@immutable
class PollOption {
  final String id;
  final String label;

  const PollOption({required this.id, required this.label});

  factory PollOption.fromJson(Map<String, dynamic> json) => PollOption(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'id': id, 'label': label};
}

/// A group decision: `groups/{groupId}/polls/{pollId}`.
///
/// Votes are a map uid → option id, so every member has at most one vote
/// and the security rules can check that a member only changed their own.
@immutable
class TripPoll {
  final String id;
  final String question;
  final List<PollOption> options;
  final Map<String, String> votes;
  final String createdBy;
  final DateTime? createdAt;
  final bool closed;

  /// Most options a poll may have (also enforced by the rules).
  static const maxOptions = 6;

  const TripPoll({
    required this.id,
    required this.question,
    required this.options,
    this.votes = const {},
    required this.createdBy,
    this.createdAt,
    this.closed = false,
  });

  /// Uids that chose [optionId].
  List<String> votersFor(String optionId) => [
        for (final entry in votes.entries)
          if (entry.value == optionId) entry.key,
      ];

  int votesFor(String optionId) => votersFor(optionId).length;

  String? voteOf(String uid) => votes[uid];

  /// Number of members who voted for an option that still exists.
  int get voterCount {
    final ids = {for (final o in options) o.id};
    return votes.values.where(ids.contains).length;
  }

  factory TripPoll.fromJson(String id, Map<String, dynamic> json) => TripPoll(
        id: id,
        question: json['question'] as String? ?? '',
        options: [
          for (final o in json['options'] as List? ?? const [])
            if (o is Map) PollOption.fromJson(Map<String, dynamic>.from(o)),
        ],
        votes: {
          for (final e in (json['votes'] as Map? ?? const {}).entries)
            if (e.value is String) '${e.key}': e.value as String,
        },
        createdBy: json['createdBy'] as String? ?? '',
        createdAt: json['createdAt'] is Timestamp
            ? (json['createdAt'] as Timestamp).toDate()
            : null,
        closed: json['closed'] as bool? ?? false,
      );

  /// Without [createdAt] the server time is written.
  Map<String, dynamic> toJson() => {
        'question': question,
        'options': [for (final o in options) o.toJson()],
        'votes': votes,
        'createdBy': createdBy,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
        'closed': closed,
      };
}
