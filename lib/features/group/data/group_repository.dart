import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../common/models/group_model.dart';
import '../../../common/models/group_session_model.dart';
import '../../../core/services/firestore_service.dart';

class GroupRepository {
  final FirestoreService _firestoreService;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  GroupRepository(this._firestoreService);

  Future<GroupModel?> getGroup(String groupId) async {
    final doc = await _firestoreService.getDocument('groups', groupId);
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
      activeSessionId: null,
      hasCompletedSession: group.hasCompletedSession,
      ownerUid: group.ownerUid,
      location: group.location,
      likeThreshold: group.likeThreshold,
      joinEnabled: true,
      invite: group.invite,
    );

    await _firestoreService.setDocument(
      'groups',
      group.groupId,
      normalizedGroup.toJson(),
    );
  }

  Future<void> joinGroupByInvite(
      String groupId, String code, String userId) async {
    final groupRef = _db.collection('groups').doc(groupId);
    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(groupRef);
      if (!snap.exists || snap.data() == null) {
        throw Exception('Group not found');
      }

      final group = GroupModel.fromJson(snap.data()!);
      if (group.invite?.code != code) {
        throw Exception('Invalid invite code');
      }
      if (group.joinEnabled != true) {
        throw Exception('Joining is currently disabled for this group');
      }
      if (group.members.contains(userId)) {
        return;
      }

      transaction.update(groupRef, {
        'members': FieldValue.arrayUnion([userId]),
      });
    });
  }

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
    final query = await _db
        .collection('groups')
        .where('invite.code', isEqualTo: normalizedCode)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('Invalid invite code');
    }

    final groupId = query.docs.first.id;
    final groupRef = _db.collection('groups').doc(groupId);

    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(groupRef);
      if (!snap.exists || snap.data() == null) {
        throw Exception('Group not found');
      }

      final group = GroupModel.fromJson(snap.data()!);
      if (group.invite?.code != normalizedCode) {
        throw Exception('Invalid invite code');
      }
      if (group.joinEnabled != true) {
        throw Exception('Joining is currently disabled for this group');
      }
      if (group.members.contains(userId)) {
        return;
      }

      transaction.update(groupRef, {
        'members': FieldValue.arrayUnion([userId]),
      });
    });

    return groupId;
  }

  Stream<List<GroupModel>> streamUserGroups(String userId) {
    return _db
        .collection('groups')
        .where('members', arrayContains: userId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => GroupModel.fromJson(doc.data())).toList());
  }

  Future<void> leaveGroup(String groupId, String userId) async {
    final doc = await _firestoreService.getDocument('groups', groupId);
    if (!doc.exists || doc.data() == null) {
      throw Exception('Group not found');
    }
    final group = GroupModel.fromJson(doc.data()!);
    final members = List<String>.from(group.members)..remove(userId);

    if (members.isEmpty) {
      await _firestoreService.deleteDocument('groups', groupId);
    } else {
      await _firestoreService.updateDocument('groups', groupId, {
        'members': members,
      });
    }
  }

  Future<void> syncFavorites(
      String groupId, List<String> sharedFavorites) async {
    await _firestoreService.updateDocument('groups', groupId, {
      'sharedFavorites': sharedFavorites,
    });
  }

  // --- Session & Swiping Logic ---

  /// Creates a brand-new session for [groupId].
  /// Called by the admin after choosing destination + threshold.
  Future<String> startSwipeSession({
    required String groupId,
    required String destination,
    required int threshold,
    required List<String> participantUids,
    required int swipeLimit,
    required List<String> placePool,
  }) async {
    final group = await getGroup(groupId);
    if (group == null) {
      throw Exception('Group not found');
    }
    if (participantUids.isEmpty) {
      throw Exception('Session must include at least one participant');
    }
    final invalidUids =
        participantUids.where((uid) => !group.members.contains(uid)).toList();
    if (invalidUids.isNotEmpty) {
      throw Exception('Participants must be group members');
    }
    if (swipeLimit <= 0) {
      throw Exception('Session must include at least one place');
    }

    final sessionId =
        _db.collection('groups').doc(groupId).collection('sessions').doc().id;

    final session = GroupSessionModel(
      sessionId: sessionId,
      destination: destination,
      status: 'in_progress',
      totalPlacesToSwipe: swipeLimit,
      swipeLimit: swipeLimit,
      placePool: placePool,
      participants: participantUids,
      threshold: threshold,
      swipeProgress: {for (final uid in participantUids) uid: 0},
      progressByUser: {for (final uid in participantUids) uid: 0},
      createdAt: DateTime.now(),
    );

    final batch = _db.batch();
    final sessionRef = _db
        .collection('groups')
        .doc(groupId)
        .collection('sessions')
        .doc(sessionId);

    batch.set(sessionRef, session.toJson());
    batch.update(_db.collection('groups').doc(groupId), {
      'activeSessionId': sessionId,
      'joinEnabled': false, // Prevent joining once session starts
    });

    await batch.commit();
    return sessionId;
  }

  /// Called after every swipe. Increments the member's progress,
  /// then checks if all members are done -- if so, auto-ends.
  Future<void> recordSwipeInSession({
    required String groupId,
    required String sessionId,
    required String userId,
    required String placeId,
    required bool liked,
  }) async {
    final groupRef = _db.collection('groups').doc(groupId);
    final sessionRef = groupRef.collection('sessions').doc(sessionId);
    final voteRef = sessionRef.collection('votes').doc(placeId);

    final sessionSnap = await sessionRef.get();
    if (!sessionSnap.exists || sessionSnap.data() == null) {
      throw Exception('Session not found');
    }
    final preSession = GroupSessionModel.fromJson(sessionSnap.data()!);
    if (preSession.isCompleted) {
      return;
    }
    if (!preSession.participants.contains(userId)) {
      throw Exception('User is not a participant in this session');
    }

    await _db.runTransaction((transaction) async {
      final sessionSnap = await transaction.get(sessionRef);
      if (!sessionSnap.exists || sessionSnap.data() == null) {
        throw Exception('Session not found');
      }

      final session = GroupSessionModel.fromJson(sessionSnap.data()!);
      if (session.isCompleted) {
        return;
      }
      if (!session.participants.contains(userId)) {
        throw Exception('User is not a participant in this session');
      }

      var updatedSession = session;
      final voteSnap = await transaction.get(voteRef);
      final likedBy = <String>{};
      final dislikedBy = <String>{};
      bool alreadyVoted = false;

      if (voteSnap.exists && voteSnap.data() != null) {
        final data = voteSnap.data()!;
        likedBy.addAll(
          (data['likedBy'] as List? ?? []).map((item) => item.toString()),
        );
        dislikedBy.addAll(
          (data['dislikedBy'] as List? ?? []).map((item) => item.toString()),
        );
        if (likedBy.contains(userId) || dislikedBy.contains(userId)) {
          alreadyVoted = true;
        }
      }

      if (!alreadyVoted) {
        final currentProgress = session.progressByUser ?? session.swipeProgress;
        final updatedProgress = Map<String, int>.from(currentProgress);
        updatedProgress[userId] = (updatedProgress[userId] ?? 0) + 1;

        updatedSession = session.copyWith(
          swipeProgress: updatedProgress,
          progressByUser: updatedProgress,
        );
      }

      if (liked) {
        dislikedBy.remove(userId);
        likedBy.add(userId);
      } else {
        likedBy.remove(userId);
        dislikedBy.add(userId);
      }

      if (voteSnap.exists) {
        transaction.update(voteRef, {
          'placeId': placeId,
          'likes': likedBy.length,
          'dislikes': dislikedBy.length,
          'likedBy': likedBy.toList(),
          'dislikedBy': dislikedBy.toList(),
        });
      } else {
        transaction.set(voteRef, {
          'placeId': placeId,
          'likes': likedBy.length,
          'dislikes': dislikedBy.length,
          'likedBy': likedBy.toList(),
          'dislikedBy': dislikedBy.toList(),
        });
      }

      if (updatedSession.allMembersDone) {
        final completedSession = updatedSession.copyWith(
          status: 'completed',
          endedAt: DateTime.now(),
          endedByUid: null,
        );
        transaction.update(sessionRef, {
          ...completedSession.toJson(),
          'endedByUid': null,
        });
        transaction.update(groupRef, {
          'activeSessionId': null,
          'hasCompletedSession': true,
        });
      } else if (!alreadyVoted) {
        transaction.update(sessionRef, updatedSession.toJson());
      }
    });
  }

  Future<GroupSessionModel?> getSession({
    required String groupId,
    required String sessionId,
  }) async {
    final snap = await _db
        .collection('groups')
        .doc(groupId)
        .collection('sessions')
        .doc(sessionId)
        .get();

    if (!snap.exists || snap.data() == null) {
      return null;
    }

    try {
      return GroupSessionModel.fromJson(snap.data()!);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearActiveSessionIfMatch({
    required String groupId,
    required String sessionId,
  }) async {
    final groupRef = _db.collection('groups').doc(groupId);

    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(groupRef);
      if (!snap.exists || snap.data() == null) {
        return;
      }

      final group = GroupModel.fromJson(snap.data()!);
      if (group.activeSessionId == sessionId) {
        transaction.update(groupRef, {
          'activeSessionId': null,
        });
      }
    });
  }

  /// Admin manually ends the session early.
  Future<void> endSessionManually({
    required String groupId,
    required String sessionId,
    required String adminUid,
  }) async {
    final batch = _db.batch();
    final groupRef = _db.collection('groups').doc(groupId);
    final sessionRef = groupRef.collection('sessions').doc(sessionId);
    final endedAt = DateTime.now();

    batch.update(sessionRef, {
      'status': 'completed',
      'endedAt': Timestamp.fromDate(endedAt),
      'endedByUid': adminUid,
    });

    batch.update(groupRef, {
      'activeSessionId': null,
      'hasCompletedSession': true,
    });

    await batch.commit();
  }

  /// Returns only places that reached the threshold.
  Future<List<Map<String, dynamic>>> getQualifiedPlaces({
    required String groupId,
    required String sessionId,
    required int threshold,
  }) async {
    final snap = await _db
        .collection('groups')
        .doc(groupId)
        .collection('sessions')
        .doc(sessionId)
        .collection('votes')
        .where('likes', isGreaterThanOrEqualTo: threshold)
        .orderBy('likes', descending: true)
        .get();

    return snap.docs.map((doc) => doc.data()).toList();
  }

  Future<List<GroupSessionModel>> getCompletedSessions(String groupId) async {
    final snap = await _db
        .collection('groups')
        .doc(groupId)
        .collection('sessions')
        .where('status', isEqualTo: 'completed')
        .orderBy('endedAt', descending: true)
        .get();

    return snap.docs
        .map((doc) => GroupSessionModel.fromJson(doc.data()))
        .toList();
  }

  /// Real-time stream of the active session -- drives UI reactivity.
  Stream<GroupSessionModel?> streamSession({
    required String groupId,
    required String sessionId,
  }) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('sessions')
        .doc(sessionId)
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) {
        return null;
      }
      try {
        return GroupSessionModel.fromJson(snap.data()!);
      } catch (_) {
        return null;
      }
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamSessionVotes(
      String groupId, String sessionId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('sessions')
        .doc(sessionId)
        .collection('votes')
        .orderBy('likes', descending: true)
        .snapshots();
  }
}
