import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/models/group_model.dart';
import '../../../features/profile/data/profile_repository.dart';
import '../data/group_repository.dart';
import '../../../main_providers.dart';

final groupControllerProvider = AsyncNotifierProvider<GroupController, GroupModel?>(GroupController.new);

class GroupController extends AsyncNotifier<GroupModel?> {
  late final GroupRepository _repo;
  late final ProfileRepository _profileRepo;

  @override
  Future<GroupModel?> build() async {
    _repo = GroupRepository(ref.read(firestoreServiceProvider));
    _profileRepo = ProfileRepository(ref.read(firestoreServiceProvider));
    return null;
  }

  Future<void> loadGroup(String groupId) async {
    state = const AsyncLoading();
    try {
      final group = await _repo.getGroup(groupId);
      if (group != null) {
        final updatedMatches = await calculateGroupMatches(group);
        final updatedGroup = group.copyWith(sharedFavorites: updatedMatches);
        state = AsyncData(updatedGroup);
      } else {
        state = const AsyncData(null);
      }
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> createGroup(GroupModel group) async {
    state = const AsyncLoading();
    try {
      await _repo.createGroup(group);
      state = AsyncData(group);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> joinGroup(String groupId, String userId) async {
    state = const AsyncLoading();
    try {
      await _repo.joinGroup(groupId, userId);
      final group = await _repo.getGroup(groupId);
      if (group != null) {
        final updatedMatches = await calculateGroupMatches(group);
        await _repo.syncFavorites(groupId, updatedMatches);
        final updatedGroup = group.copyWith(sharedFavorites: updatedMatches);
        state = AsyncData(updatedGroup);
      } else {
        state = AsyncError(Exception('Group not found'), StackTrace.current);
      }
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<List<String>> calculateGroupMatches(GroupModel group) async {
    if (group.members.isEmpty) return [];
    
    final List<Future<List<String>>> futures = group.members
        .map((uid) => _profileRepo.getUserFavorites(uid))
        .toList();
    
    final List<List<String>> memberFavorites = await Future.wait(futures);
    
    if (memberFavorites.isEmpty) return [];
    
    Set<String> intersection = memberFavorites.first.toSet();
    for (final favorites in memberFavorites.skip(1)) {
      intersection = intersection.intersection(favorites.toSet());
    }
    
    return intersection.toList();
  }

  Future<void> refreshGroupMatches() async {
    final currentGroup = state.value;
    if (currentGroup == null) return;
    
    state = const AsyncLoading();
    try {
      final updatedMatches = await calculateGroupMatches(currentGroup);
      await _repo.syncFavorites(currentGroup.groupId, updatedMatches);
      final updatedGroup = currentGroup.copyWith(sharedFavorites: updatedMatches);
      state = AsyncData(updatedGroup);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> syncFavorites(String groupId, List<String> sharedFavorites) async {
    if (state.value == null) return;
    try {
      await _repo.syncFavorites(groupId, sharedFavorites);
      final gm = state.value!;
      final updated = gm.copyWith(sharedFavorites: sharedFavorites);
      state = AsyncData(updated);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> leaveGroup(String groupId, String userId) async {
    state = const AsyncLoading();
    try {
      await _repo.leaveGroup(groupId, userId);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
