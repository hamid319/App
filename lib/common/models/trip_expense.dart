import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';

/// A shared cost of a trip: `groups/{groupId}/expenses/{expenseId}`.
/// Amounts are integer cents, split equally between [participants].
@immutable
class TripExpense {
  final String id;
  final String title;
  final int amountCents;
  final String currency;
  final String paidBy;
  final List<String> participants;
  final String createdBy;
  final DateTime? createdAt;

  static const defaultCurrency = 'EUR';

  const TripExpense({
    required this.id,
    required this.title,
    required this.amountCents,
    this.currency = defaultCurrency,
    required this.paidBy,
    required this.participants,
    required this.createdBy,
    this.createdAt,
  });

  factory TripExpense.fromJson(String id, Map<String, dynamic> json) =>
      TripExpense(
        id: id,
        title: json['title'] as String? ?? '',
        amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
        currency: json['currency'] as String? ?? defaultCurrency,
        paidBy: json['paidBy'] as String? ?? '',
        participants: [
          for (final uid in json['participants'] as List? ?? const []) '$uid',
        ],
        createdBy: json['createdBy'] as String? ?? '',
        createdAt: json['createdAt'] is Timestamp
            ? (json['createdAt'] as Timestamp).toDate()
            : null,
      );

  /// Without [createdAt] the server time is written.
  Map<String, dynamic> toJson() => {
        'title': title,
        'amountCents': amountCents,
        'currency': currency,
        'paidBy': paidBy,
        'participants': participants,
        'createdBy': createdBy,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
      };
}
