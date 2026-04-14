import '../../../core/services/firestore_service.dart';
import '../../../common/models/group_model.dart';

class GroupRepository {
  final FirestoreService _firestoreService;
  const GroupRepository(this._firestoreService);

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
    final members = List<String>.from(group.members)..add(userId);
    await _firestoreService.updateDocument('groups', groupId, {
      'members': members,
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
      await _firestoreService.updateDocument('groups', groupId, {
        'members': members,
      });
    }
  }

  Future<void> syncFavorites(String groupId, List<String> sharedFavorites) async {
    await _firestoreService.updateDocument('groups', groupId, {
      'sharedFavorites': sharedFavorites,
    });
  }
}
