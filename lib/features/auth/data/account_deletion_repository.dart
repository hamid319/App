import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../../common/models/journal_entry.dart';
import '../../group/data/group_repository.dart' show tripTombstone;

/// Removes everything a user stored, before their Firebase Auth user is
/// deleted (the security rules need the signed-in user for every step).
///
/// Every step is idempotent, so a deletion interrupted by a re-login prompt
/// can simply run again.
///
/// What stays: expenses, ideas and polls in trips that still have other
/// members (the user's own journal entries and photos there are deleted) (their balances and plans depend on them; the app shows a neutral
/// member name once the profile is gone), and report markers under reviews,
/// which clients cannot delete.
class AccountDeletionRepository {
  AccountDeletionRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestoreOverride = firestore,
        _storageOverride = storage;

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseStorage? _storageOverride;

  // Resolved lazily, so tests only need the services they exercise.
  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseStorage get _storage => _storageOverride ?? FirebaseStorage.instance;

  /// Writes per batch, below Firestore's limit of 500.
  static const _batchSize = 400;

  /// Runs every cleanup step in the order the rules require: trips first
  /// (they check the group document), the profile document last.
  Future<void> deleteUserData(String uid) async {
    await leaveAllTrips(uid);
    await deleteReviews(uid);
    await deleteSoloSwipes(uid);
    await deleteProfilePhoto(uid);
    await deleteUserDocument(uid);
  }

  /// Takes [uid] out of every trip. A trip the user is alone in is deleted
  /// with its contents and invite code; in a shared trip the user is removed
  /// and, if they organized it, the longest-standing other member takes over.
  Future<void> leaveAllTrips(String uid) async {
    final groups = await _db
        .collection('groups')
        .where('members', arrayContains: uid)
        .get();
    for (final doc in groups.docs) {
      final deleted = await _db.runTransaction((transaction) async {
        final current = (await transaction.get(doc.reference)).data();
        if (current == null || current['ownerUid'] != uid) return false;
        final members = current['members'];
        if (members is! List || members.length != 1 || members.single != uid) {
          return false;
        }
        transaction.set(doc.reference, tripTombstone);
        return true;
      });
      if (!deleted) await _leaveTrip(doc.reference, doc.data(), uid);
    }
  }

  Future<void> _leaveTrip(
    DocumentReference<Map<String, dynamic>> groupRef,
    Map<String, dynamic> group,
    String uid,
  ) async {
    // Personal memories and swipes go; before leaving, while the rules
    // still see a member.
    await _deleteJournal(groupRef, authorUid: uid);
    await groupRef.collection('swipes').doc(uid).delete();
    await groupRef.collection('packingProgress').doc(uid).delete();
    if (group['ownerUid'] == uid) {
      // The web invite shows the organizer's first name; drop it while the
      // user still owns the trip (only the owner may write the entry).
      await _withInviteEntry(groupRef.id, group, (ref) async {
        await ref.update({'ownerName': FieldValue.delete()});
      });
    }

    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(groupRef);
      final data = snap.data();
      if (data == null) return;
      final members = List<String>.from(data['members'] as List? ?? []);
      if (!members.contains(uid)) return;
      final others = members.where((m) => m != uid).toList();
      transaction.update(groupRef, {
        'members': FieldValue.arrayRemove([uid]),
        // members[0] of the remaining list joined first.
        if (data['ownerUid'] == uid && others.isNotEmpty)
          'ownerUid': others.first,
      });
    });
  }

  /// Journal entries of a trip (only [authorUid]'s when given) with their
  /// photos in Storage. The paths come from the entries, so no Storage
  /// listing (and no list rule) is needed.
  Future<void> _deleteJournal(
    DocumentReference<Map<String, dynamic>> groupRef, {
    String? authorUid,
  }) async {
    Query<Map<String, dynamic>> query = groupRef.collection('journal');
    if (authorUid != null) {
      query = query.where('authorUid', isEqualTo: authorUid);
    }
    final entries = await query.get();
    for (final doc in entries.docs) {
      final photos = doc.data()['photos'];
      if (photos is! List) continue;
      for (final photo in photos) {
        final path = photo is Map ? photo['path'] : null;
        if (JournalPhoto.isPathForEntry(path, groupRef.id, doc.id)) {
          await _deleteFile(path as String);
        }
      }
    }
    await _deleteDocs(entries);
  }

  /// Runs [action] on the trip's `inviteCodes` entry if it exists and still
  /// points at this trip. The rules reject deleting a missing entry.
  Future<void> _withInviteEntry(
    String groupId,
    Map<String, dynamic> group,
    Future<void> Function(DocumentReference<Map<String, dynamic>> ref) action,
  ) async {
    final invite = group['invite'];
    final code = invite is Map ? invite['code'] : null;
    if (code is! String || code.isEmpty) return;
    final ref = _db.collection('inviteCodes').doc(code.toUpperCase());
    final snap = await ref.get();
    if (snap.data()?['groupId'] != groupId) return;
    await action(ref);
  }

  /// The user's place reviews (`places/{placeId}/reviews/{uid}`, field
  /// `uid`). Needs the collection-group rule and the `reviews.uid` index
  /// override; until both are deployed the query fails and the reviews are
  /// left in place rather than blocking the account deletion.
  Future<void> deleteReviews(String uid) async {
    final QuerySnapshot<Map<String, dynamic>> reviews;
    try {
      reviews = await _db
          .collectionGroup('reviews')
          .where('uid', isEqualTo: uid)
          .get();
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition' && e.code != 'permission-denied') {
        rethrow;
      }
      debugPrint('Reviews of $uid not deleted: $e');
      return;
    }
    await _deleteDocs(reviews);
  }

  /// Solo swipe history (`swipeResults`, field `userId`).
  Future<void> deleteSoloSwipes(String uid) async {
    await _deleteDocs(await _db
        .collection('swipeResults')
        .where('userId', isEqualTo: uid)
        .get());
  }

  /// `profile_images/{uid}.jpg` in Storage; nothing to do when there is none.
  Future<void> deleteProfilePhoto(String uid) =>
      _deleteFile('profile_images/$uid.jpg');

  /// Deletes a Storage file; a missing one is fine (runs are repeatable).
  Future<void> _deleteFile(String path) async {
    try {
      await _storage.ref(path).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }

  /// The user document, its subcollections (hidden-gem tips, packing
  /// lists) and the public profile.
  Future<void> deleteUserDocument(String uid) async {
    final user = _db.collection('users').doc(uid);
    await _deleteDocs(await user.collection('cityTips').get());
    await _deleteDocs(await user.collection('packing').get());
    await user.delete();
    await _db.collection('publicProfiles').doc(uid).delete();
  }

  Future<void> _deleteDocs(QuerySnapshot<Map<String, dynamic>> snapshot) async {
    final docs = snapshot.docs;
    for (var i = 0; i < docs.length; i += _batchSize) {
      final batch = _db.batch();
      for (final doc in docs.skip(i).take(_batchSize)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
