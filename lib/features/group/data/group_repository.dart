import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../common/models/group_model.dart';
import '../../../common/models/day_plan.dart';
import '../../../common/models/group_session_model.dart';
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
      activeSessionId: null,
      hasCompletedSession: group.hasCompletedSession,
      ownerUid: group.ownerUid,
      location: group.location,
      joinEnabled: true,
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
        if (!group.isJoinable) {
          throw Exception('Joining is currently disabled for this group');
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

  // --- Session & Swiping Logic ---

  /// Creates a brand-new session for [groupId].
  /// Called by the admin after choosing destination + threshold.
  ///
  /// If the group already has an active session, that session's ID is
  /// returned and nothing is written, so a double tap cannot orphan it.
  Future<String> startSwipeSession({
    required String groupId,
    required String destination,
    required List<String> participantUids,
    required int swipeLimit,
    required List<String> placePool,
    DateTime? endTime,
  }) async {
    final groupRef = _db.collection('groups').doc(groupId);
    final sessionRef = groupRef.collection('sessions').doc();

    return _db.runTransaction((transaction) async {
      final snap = await transaction.get(groupRef);
      if (!snap.exists || snap.data() == null) {
        throw Exception('Group not found');
      }
      final group = GroupModel.fromJson(snap.data()!);
      if (group.activeSessionId != null) {
        return group.activeSessionId!;
      }
      if (participantUids.isEmpty) {
        throw Exception('Session must include at least one participant');
      }
      final invalidUids = participantUids
          .where((uid) => !group.members.contains(uid))
          .toList();
      if (invalidUids.isNotEmpty) {
        throw Exception('Participants must be group members');
      }
      if (swipeLimit <= 0) {
        throw Exception('Session must include at least one place');
      }

      final session = GroupSessionModel(
        sessionId: sessionRef.id,
        destination: destination,
        status: 'in_progress',
        totalPlacesToSwipe: swipeLimit,
        swipeLimit: swipeLimit,
        placePool: placePool,
        participants: participantUids,
        swipeProgress: {for (final uid in participantUids) uid: 0},
        progressByUser: {for (final uid in participantUids) uid: 0},
        createdAt: DateTime.now(),
        endTime: endTime,
      );

      transaction.set(sessionRef, session.toJson());
      transaction.update(groupRef, {
        'activeSessionId': sessionRef.id,
        // Joining pauses while the session runs; every path that ends the
        // session sets it back. Joinability itself is `activeSessionId ==
        // null` (see GroupModel.isJoinable); the flag is kept for older
        // app versions that still check it.
        'joinEnabled': false,
      });
      return sessionRef.id;
    });
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
    final userSwipeRef = sessionRef.collection('userSwipes').doc(userId);

    await _db.runTransaction((transaction) async {
      final sessionSnap = await transaction.get(sessionRef);
      if (!sessionSnap.exists || sessionSnap.data() == null) {
        throw Exception('Session not found');
      }

      // The group document is updated when the session completes, so its
      // absence must fail the transaction up front rather than part-way
      // through the writes below.
      final groupSnap = await transaction.get(groupRef);
      if (!groupSnap.exists) {
        throw Exception('Group not found');
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

      transaction.set(
        userSwipeRef,
        {
          'swipedPlaceIds': FieldValue.arrayUnion([placeId]),
          'likedPlaceIds': liked
              ? FieldValue.arrayUnion([placeId])
              : FieldValue.arrayRemove([placeId]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

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
          'joinEnabled': true,
        });
      } else if (!alreadyVoted) {
        transaction.update(sessionRef, updatedSession.toJson());
      }
    });
  }

  Future<Set<String>> getUserSwipedPlaceIds({
    required String groupId,
    required String sessionId,
    required String userId,
  }) async {
    final snap = await _db
        .collection('groups')
        .doc(groupId)
        .collection('sessions')
        .doc(sessionId)
        .collection('userSwipes')
        .doc(userId)
        .get();

    if (!snap.exists || snap.data() == null) {
      return <String>{};
    }

    final data = snap.data()!;
    final swiped = List<String>.from(data['swipedPlaceIds'] ?? const []);
    return swiped.toSet();
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

    // A document that exists but fails to parse is an error, not a missing
    // session. Returning null here made callers clear the active session for
    // every member.
    return GroupSessionModel.fromJson(snap.data()!);
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
          'joinEnabled': true,
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
      'joinEnabled': true,
    });

    await batch.commit();
  }

  /// Returns only places that reached at least 1 like.
  /// Vote documents of the places that count as group matches (see
  /// [GroupSessionModel.matchThreshold]), most liked first.
  Future<List<Map<String, dynamic>>> getQualifiedPlaces({
    required String groupId,
    required String sessionId,
    required int participantCount,
  }) async {
    final snap = await _db
        .collection('groups')
        .doc(groupId)
        .collection('sessions')
        .doc(sessionId)
        .collection('votes')
        .get();

    final votes = snap.docs.map((doc) => doc.data()).toList();
    final threshold = GroupSessionModel.matchThreshold(participantCount);
    final qualified =
        votes.where((v) => (v['likes'] as num? ?? 0) >= threshold).toList();
    qualified.sort((a, b) => (b['likes'] as num? ?? 0).compareTo(a['likes'] as num? ?? 0));
    return qualified;
  }

  Future<List<GroupSessionModel>> getCompletedSessions(String groupId) async {
    final snap = await _db
        .collection('groups')
        .doc(groupId)
        .collection('sessions')
        .where('status', isEqualTo: 'completed')
        .get();

    final sessions = snap.docs
        .map((doc) => GroupSessionModel.fromJson(doc.data()))
        .toList();

    // Sort locally to avoid needing a Firestore composite index
    sessions.sort((a, b) {
      final aTime = a.endedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.endedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    return sessions;
  }

  Future<void> updateSessionOrder(
      String groupId, String sessionId, List<String> orderedPlaceIds) async {
    await _db
        .collection('groups')
        .doc(groupId)
        .collection('sessions')
        .doc(sessionId)
        .update({
      'orderedPlaceIds': orderedPlaceIds,
    });
  }

  /// Stores the admin's day plan on the session (rules: owner only).
  Future<void> saveDayPlan(
      String groupId, String sessionId, DayPlan plan) async {
    await _db
        .collection('groups')
        .doc(groupId)
        .collection('sessions')
        .doc(sessionId)
        .update({'dayPlan': plan.toJson()});
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
