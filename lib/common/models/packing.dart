import 'package:cloud_firestore/cloud_firestore.dart';

/// Groups of a member's own packing list, in the order they are shown.
enum PackingCategory {
  documents,
  tech,
  clothes,
  toiletries,
  weather,
  other,
  own
}

/// One thing on a member's own (private) packing list. Suggested items
/// carry a [key] the app names in its language; own ones a [name].
class PackingItem {
  const PackingItem({
    required this.id,
    required this.category,
    this.key,
    this.name,
    this.qty,
    this.done = false,
  });

  final String id;
  final PackingCategory category;
  final String? key;
  final String? name;

  /// How many, e.g. socks for a five-day trip.
  final int? qty;
  final bool done;

  PackingItem copyWith({bool? done}) => PackingItem(
        id: id,
        category: category,
        key: key,
        name: name,
        qty: qty,
        done: done ?? this.done,
      );

  factory PackingItem.fromJson(Map<String, dynamic> json) => PackingItem(
        id: '${json['id'] ?? ''}',
        category: PackingCategory.values.asNameMap()[json['category']] ??
            PackingCategory.own,
        key: json['key'] as String?,
        name: json['name'] as String?,
        qty: (json['qty'] as num?)?.toInt(),
        done: json['done'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category.name,
        if (key != null) 'key': key,
        if (name != null) 'name': name,
        if (qty != null) 'qty': qty,
        'done': done,
      };
}

/// Something one member brings for the whole group (speaker, sunscreen).
class SharedPackingItem {
  const SharedPackingItem({
    required this.id,
    required this.title,
    required this.addedBy,
    this.bringer,
    this.packed = false,
    this.createdAt,
  });

  final String id;
  final String title;
  final String addedBy;

  /// Who brings it; null while nobody has taken it.
  final String? bringer;

  /// Ticked off by the bringer once it is in their suitcase.
  final bool packed;
  final DateTime? createdAt;

  factory SharedPackingItem.fromJson(String id, Map<String, dynamic> json) =>
      SharedPackingItem(
        id: id,
        title: '${json['title'] ?? ''}',
        addedBy: '${json['addedBy'] ?? ''}',
        bringer: json['bringer'] as String?,
        packed: json['packed'] == true,
        createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
      );
}

/// How far one member has packed; the only part of their list others see.
class PackingProgress {
  const PackingProgress({required this.done, required this.total});

  final int done;
  final int total;

  bool get complete => total > 0 && done >= total;
  int get percent => total == 0 ? 0 : (done * 100 / total).round();
}

/// The member's progress: their own items plus the shared ones they bring.
PackingProgress packingProgressOf(
  List<PackingItem> mine,
  List<SharedPackingItem> shared,
  String uid,
) {
  final bringing = shared.where((s) => s.bringer == uid);
  return PackingProgress(
    done: mine.where((i) => i.done).length +
        bringing.where((s) => s.packed).length,
    total: mine.length + bringing.length,
  );
}
