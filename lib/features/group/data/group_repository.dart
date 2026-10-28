import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../common/models/group_model.dart';
import '../../../core/services/firestore_service.dart';

class GroupRepository {
  GroupRepository(
    this._firestoreService, {
    FirebaseFirestore? firestore,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _usesInjectedFirestore = firestore != null;

  final FirestoreService _firestoreService;
  final FirebaseFirestore _db;
  final bool _usesInjectedFirestore;

  Future<GroupModel?> getGroup(String groupId) async {
    final doc = _usesInjectedFirestore
        ? await _db.collection('groups').doc(groupId).get()
        : await _firestoreService.getDocument('groups', groupId);
    if (doc.exists && doc.data() != null) {
      return GroupModel.fromJson(doc.data()!);
    }
    return null;
  }

  Future<void> createGroup(GroupModel group) async {
    if (group.members.isEmpty) {
      throw Exception('Group must include at least one member');
    }

    final normalizedGroup = GroupModel(
      groupId: group.groupId,
      groupName: group.groupName,
      members: group.members,
      sharedFavorites: group.sharedFavorites,
      createdAt: group.createdAt ?? DateTime.now(),
      ownerUid: group.ownerUid,
      location: group.location,
      invite: group.invite,
      tripStart: group.tripStart,
      tripEnd: group.tripEnd,
    );

    if (_usesInjectedFirestore) {
      await _db
          .collection('groups')
          .doc(group.groupId)
          .set(normalizedGroup.toJson());
    } else {
      await _firestoreService.setDocument(
        'groups',
        group.groupId,
        normalizedGroup.toJson(),
      );
    }
    await ensureInviteIndex(normalizedGroup);
  }

  /// Invite codes live in `inviteCodes/{code}` (`groupId`), so someone who
  /// is not a member yet can resolve a code without being able to read or
  /// list groups. Groups themselves are readable by members only.
  DocumentReference<Map<String, dynamic>> _inviteDoc(String code) =>
      _db.collection('inviteCodes').doc(code.toUpperCase());

  /// Writes the code's lookup entry with what the web invite shows before
  /// joining (trip name, city, owner's first name). Called when a group is
  /// created and by the owner's app for every own group (idempotent).
  Future<void> ensureInviteIndex(GroupModel group, {String? ownerName}) async {
    final code = group.invite?.code ?? '';
    if (code.isEmpty) return;
    String? short(String? v, int max) {
      final t = v?.trim();
      if (t == null || t.isEmpty) return null;
      return t.length <= max ? t : t.substring(0, max);
    }

    final title = short(group.groupName, 80);
    final city = short(group.location?.cityName, 80);
    final owner = short(ownerName?.split(' ').first, 60);
    await _inviteDoc(code).set({
      'groupId': group.groupId,
      'createdAt': FieldValue.serverTimestamp(),
      if (title != null) 'title': title,
      if (city != null) 'cityName': city,
      if (owner != null) 'ownerName': owner,
    });
  }

  Future<void> joinGroupByInvite(
      String groupId, String code, String userId) async {
    await _joinWithCode(groupId, code.toUpperCase(), userId);
  }

  /// Not usable for people outside the group: joining needs the invite code
  /// (the security rules check it). Kept for members re-joining a group
  /// they can already read.
  Future<void> joinGroup(String groupId, String userId) async {
    final groupRef = _db.collection('groups').doc(groupId);
    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(groupRef);
      if (!snap.exists || snap.data() == null) {
        throw Exception('Group not found');
      }

      final group = GroupModel.fromJson(snap.data()!);
      if (group.members.contains(userId)) {
        return;
      }

      transaction.update(groupRef, {
        'members': FieldValue.arrayUnion([userId]),
      });
    });
  }

  Future<String> joinGroupByCodeOnly(String code, String userId) async {
    final normalizedCode = code.toUpperCase();
    final invite = await _inviteDoc(normalizedCode).get();
    final groupId = invite.data()?['groupId'];
    if (!invite.exists || groupId is! String || groupId.isEmpty) {
      throw Exception('Invalid invite code');
    }
    await _joinWithCode(groupId, normalizedCode, userId);
    return groupId;
  }

  /// Adds [userId] to the group and sends the [code] along as `joinCode`,
  /// which the rules compare with the group's invite code. A non-member
  /// cannot read the group first, so the checks run client-side only when
  /// the read is allowed (already a member, or tests without rules).
  Future<void> _joinWithCode(String groupId, String code, String userId) async {
    final groupRef = _db.collection('groups').doc(groupId);
    try {
      final snap = await groupRef.get();
      if (snap.exists && snap.data() != null) {
        final group = GroupModel.fromJson(snap.data()!);
        if (group.members.contains(userId)) return;
        if (group.invite?.code != code) {
          throw Exception('Invalid invite code');
        }
      } else if (!snap.exists) {
        throw Exception('Group not found');
      }
    } on FirebaseException catch (e) {
      // Not a member yet: reading is not allowed, the rules decide below.
      if (e.code != 'permission-denied') rethrow;
    }

    try {
      await groupRef.update({
        'members': FieldValue.arrayUnion([userId]),
        'joinCode': code,
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        // Wrong code, or a swipe session is running.
        throw Exception('Invalid invite code or joining is closed right now');
      }
      rethrow;
    }
  }

  Stream<List<GroupModel>> streamUserGroups(String userId) {
    return _db
        .collection('groups')
        .where('members', arrayContains: userId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => GroupModel.fromJson(doc.data())).toList());
  }

  /// Removes [userId] from the group inside a transaction, so a concurrent
  /// join is not lost. When the owner leaves, ownership passes to the
  /// longest-standing remaining member; otherwise nobody could start or end
  /// sessions again. The last member leaving deletes the group.
  Future<void> leaveGroup(String groupId, String userId) async {
    final groupRef = _db.collection('groups').doc(groupId);
    // The member's swipes go with them (the matches ignore them anyway).
    await groupRef.collection('swipes').doc(userId).delete();
    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(groupRef);
      if (!snap.exists || snap.data() == null) {
        throw Exception('Group not found');
      }
      final group = GroupModel.fromJson(snap.data()!);
      if (!group.members.contains(userId)) return;

      final remaining = group.members.where((m) => m != userId).toList();
      if (remaining.isEmpty) {
        transaction.delete(groupRef);
        return;
      }

      transaction.update(groupRef, {
        'members': FieldValue.arrayRemove([userId]),
        if (group.ownerUid == userId) 'ownerUid': remaining.first,
      });
    });
  }

  Future<void> deleteGroup(String groupId) async {
    if (_usesInjectedFirestore) {
      await _db.collection('groups').doc(groupId).delete();
    } else {
      await _firestoreService.deleteDocument('groups', groupId);
    }
  }

  Future<void> syncFavorites(
      String groupId, List<String> sharedFavorites) async {
    final data = {'sharedFavorites': sharedFavorites};
    if (_usesInjectedFirestore) {
      await _db.collection('groups').doc(groupId).update(data);
    } else {
      await _firestoreService.updateDocument('groups', groupId, data);
    }
  }
}
