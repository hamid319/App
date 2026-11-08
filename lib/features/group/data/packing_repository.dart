import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../common/models/packing.dart';

/// Packing lists of a trip.
///
/// - Own list: `users/{uid}/packing/{groupId}`, private to the member.
/// - Progress: `groups/{groupId}/packingProgress/{uid}`, done/total only, so
///   the group sees percentages but not what anyone packs.
/// - Shared list: `groups/{groupId}/packingShared/{id}`, things one member
///   brings for everybody.
class PackingRepository {
  PackingRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Most items a list may hold (the rules enforce the same).
  static const maxItems = 150;

  CollectionReference<Map<String, dynamic>> _mine(String uid) =>
      _db.collection('users').doc(uid).collection('packing');

  DocumentReference<Map<String, dynamic>> _group(String groupId) =>
      _db.collection('groups').doc(groupId);

  CollectionReference<Map<String, dynamic>> _progress(String groupId) =>
      _group(groupId).collection('packingProgress');

  CollectionReference<Map<String, dynamic>> _shared(String groupId) =>
      _group(groupId).collection('packingShared');

  /// The member's own list; null until they first change it (the screen
  /// then shows the suggested list).
  Stream<List<PackingItem>?> streamMyList(String uid, String groupId) =>
      _mine(uid).doc(groupId).snapshots().map((doc) {
        final items = doc.data()?['items'];
        if (items is! List) return null;
        return [
          for (final i in items)
            if (i is Map) PackingItem.fromJson(Map<String, dynamic>.from(i)),
        ];
      });

  /// Trips the member has fully packed for (miles and reminders).
  Stream<Set<String>> streamPackedTripIds(String uid) => _mine(uid)
      .where('complete', isEqualTo: true)
      .snapshots()
      .map((snap) => {for (final d in snap.docs) d.id});

  /// Saves the own list and the progress the group sees, in one batch.
  Future<void> saveMyList(
    String uid,
    String groupId,
    List<PackingItem> items,
    PackingProgress progress,
  ) {
    final batch = _db.batch()
      ..set(_mine(uid).doc(groupId), {
        'items': [for (final i in items.take(maxItems)) i.toJson()],
        'complete': progress.complete,
        'updatedAt': FieldValue.serverTimestamp(),
      })
      ..set(_progress(groupId).doc(uid), _progressJson(progress));
    return batch.commit();
  }

  /// Progress changed through the shared list only.
  Future<void> saveProgress(
      String uid, String groupId, PackingProgress progress) {
    final batch = _db.batch()
      ..set(
          _mine(uid).doc(groupId),
          {
            'complete': progress.complete,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true))
      ..set(_progress(groupId).doc(uid), _progressJson(progress));
    return batch.commit();
  }

  Map<String, dynamic> _progressJson(PackingProgress p) => {
        'done': p.done,
        'total': p.total,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// Every member's progress (uid -> progress).
  Stream<Map<String, PackingProgress>> streamProgress(String groupId) =>
      _progress(groupId).snapshots().map((snap) => {
            for (final d in snap.docs)
              d.id: PackingProgress(
                done: (d.data()['done'] as num?)?.toInt() ?? 0,
                total: (d.data()['total'] as num?)?.toInt() ?? 0,
              ),
          });

  /// The shared list, oldest first.
  Stream<List<SharedPackingItem>> streamShared(String groupId) =>
      _shared(groupId).snapshots().map((snap) {
        final far = DateTime(9999);
        return [
          for (final d in snap.docs) SharedPackingItem.fromJson(d.id, d.data())
        ]..sort((a, b) => (a.createdAt ?? far).compareTo(b.createdAt ?? far));
      });

  Future<void> addShared(String groupId, String title, String uid) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) throw ArgumentError('A shared item needs a title');
    return _shared(groupId).add({
      'title': trimmed.length > 60 ? trimmed.substring(0, 60) : trimmed,
      'addedBy': uid,
      'bringer': null,
      'packed': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Takes the item ([uid]) or hands it back (null), unpacked either way.
  Future<void> setBringer(String groupId, String itemId, String? uid) =>
      _shared(groupId).doc(itemId).update({'bringer': uid, 'packed': false});

  Future<void> setSharedPacked(String groupId, String itemId, bool packed) =>
      _shared(groupId).doc(itemId).update({'packed': packed});

  Future<void> deleteShared(String groupId, String itemId) =>
      _shared(groupId).doc(itemId).delete();
}
