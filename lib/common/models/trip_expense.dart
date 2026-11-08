import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';

/// One line of a scanned receipt, in euro cents.
@immutable
class ReceiptItem {
  /// Stable within its expense, so claims survive edits of other lines.
  final String id;
  final String name;

  /// The name as printed, when [name] is a translation.
  final String? original;
  final int amountCents;

  /// Shared by all participants instead of claimed (tax, bread, tip).
  final bool forAll;

  const ReceiptItem({
    required this.id,
    required this.name,
    this.original,
    required this.amountCents,
    this.forAll = false,
  });

  factory ReceiptItem.fromJson(Map<String, dynamic> json) => ReceiptItem(
        id: '${json['id'] ?? ''}',
        name: json['name'] as String? ?? '',
        original: json['original'] as String?,
        amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
        forAll: json['forAll'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (original != null) 'original': original,
        'amountCents': amountCents,
        'forAll': forAll,
      };

  ReceiptItem copyWith({String? name, int? amountCents, bool? forAll}) =>
      ReceiptItem(
        id: id,
        name: name ?? this.name,
        original: original,
        amountCents: amountCents ?? this.amountCents,
        forAll: forAll ?? this.forAll,
      );
}

/// A shared cost of a trip: `groups/{groupId}/expenses/{expenseId}`.
/// Amounts are integer cents, split equally between [participants]; a
/// receipt ([items] not empty) is split by what each member claimed.
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

  /// Lines of a scanned receipt; [amountCents] is their sum plus [tipCents].
  final List<ReceiptItem> items;

  /// Tip on top of a receipt, shared by all participants.
  final int tipCents;

  bool get isReceipt => items.isNotEmpty;

  static const defaultCurrency = 'EUR';

  /// Thrown (as a [StateError]) when someone else's expense is changed.
  static const notCreatorMessage = 'Only the creator can change this expense';

  const TripExpense({
    required this.id,
    required this.title,
    required this.amountCents,
    this.currency = defaultCurrency,
    required this.paidBy,
    required this.participants,
    required this.createdBy,
    this.createdAt,
    this.items = const [],
    this.tipCents = 0,
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
        items: [
          for (final item in json['items'] as List? ?? const [])
            if (item is Map)
              ReceiptItem.fromJson(Map<String, dynamic>.from(item)),
        ],
        tipCents: (json['tipCents'] as num?)?.toInt() ?? 0,
      );

  /// Only whoever added an expense may edit or delete it.
  bool isEditableBy(String uid) => uid.isNotEmpty && createdBy == uid;

  TripExpense copyWith({
    String? title,
    int? amountCents,
    String? paidBy,
    List<String>? participants,
    List<ReceiptItem>? items,
    int? tipCents,
  }) =>
      TripExpense(
        id: id,
        title: title ?? this.title,
        amountCents: amountCents ?? this.amountCents,
        currency: currency,
        paidBy: paidBy ?? this.paidBy,
        participants: participants ?? this.participants,
        createdBy: createdBy,
        createdAt: createdAt,
        items: items ?? this.items,
        tipCents: tipCents ?? this.tipCents,
      );

  /// Without [createdAt] the server time is written.
  Map<String, dynamic> toJson() => {
        'title': title,
        'amountCents': amountCents,
        'currency': currency,
        'paidBy': paidBy,
        'participants': participants,
        'createdBy': createdBy,
        if (isReceipt) 'items': [for (final i in items) i.toJson()],
        if (isReceipt) 'tipCents': tipCents,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
      };
}
