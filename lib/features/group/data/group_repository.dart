import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/firestore_service.dart';
import '../../../common/models/group_model.dart';
import '../../../common/models/group_session_model.dart';
import '../../../common/models/session_vote_model.dart';

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
    await _firestoreService.setDocument('groups', group.groupId, group.toJson());
  }

  Future<void> joinGroup(String groupId, String userId) async {
    final doc = await _firestoreService.getDocument('groups', groupId);
    if (!doc.exists || doc.data() == null) {
      throw Exception('Group not found');
    }
    final group = GroupModel.fromJson(doc.data()!);
    if (group.members.contains(userId)) {
      return;
    }
    await _db.collection('groups').doc(groupId).update({
      'members': FieldValue.arrayUnion([userId])
    });
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
      await _db.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayRemove([userId])
      });
    }
  }

  Future<void> syncFavorites(String groupId, List<String> sharedFavorites) async {
    await _firestoreService.updateDocument('groups', groupId, {
      'sharedFavorites': sharedFavorites,
    });
  }

  // --- Session & Swiping Logic ---

  Future<GroupSessionModel> startSwipeSession(String groupId, String destination, int totalPlaces) async {
    final sessionRef = _db.collection('groups').doc(groupId).collection('sessions').doc();
    
    final newSession = GroupSessionModel(
      sessionId: sessionRef.id,
      destination: destination,
      status: 'in_progress',
      totalPlacesToSwipe: totalPlaces,
      participants: [],
      createdAt: DateTime.now(),
    );

    // Run in batch: create session and update group's activeSessionId
    final batch = _db.batch();
    batch.set(sessionRef, newSession.toJson());
    batch.update(_db.collection('groups').doc(groupId), {
      'activeSessionId': sessionRef.id,
    });

    await batch.commit();
    return newSession;
  }

  Future<void> endSwipeSession(String groupId, String sessionId) async {
    final batch = _db.batch();
    batch.update(_db.collection('groups').doc(groupId).collection('sessions').doc(sessionId), {
      'status': 'completed',
    });
    batch.update(_db.collection('groups').doc(groupId), {
      'activeSessionId': null,
    });
    await batch.commit();
  }

  Future<void> joinSession(String groupId, String sessionId, String userId) async {
    await _db.collection('groups').doc(groupId).collection('sessions').doc(sessionId).update({
      'participants': FieldValue.arrayUnion([userId])
    });
  }

  Future<void> castVote(String groupId, String sessionId, String placeId, String userId, bool liked) async {
    final voteRef = _db.collection('groups').doc(groupId)
                       .collection('sessions').doc(sessionId)
                       .collection('votes').doc(placeId);

    // We can't transactionally check if the user already voted easily without a transaction or just allowing an overwrite.
    // For simplicity, we add the user to likedBy/dislikedBy and increment counters.
    // If they already voted, ideally the UI prevents a second vote, or we handle it.
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(voteRef);
      
      if (!snapshot.exists) {
        // Initial setup for the vote
        final model = SessionVoteModel(
          placeId: placeId,
          likes: liked ? 1 : 0,
          dislikes: liked ? 0 : 1,
          likedBy: liked ? [userId] : [],
          dislikedBy: liked ? [] : [userId],
        );
        transaction.set(voteRef, model.toJson());
      } else {
        // Increment
        transaction.update(voteRef, {
          liked ? 'likes' : 'dislikes': FieldValue.increment(1),
          liked ? 'likedBy' : 'dislikedBy': FieldValue.arrayUnion([userId])
        });
      }
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamSessionVotes(String groupId, String sessionId) {
    return _db.collection('groups').doc(groupId)
              .collection('sessions').doc(sessionId)
              .collection('votes').orderBy('likes', descending: true)
              .snapshots();
  }
}
