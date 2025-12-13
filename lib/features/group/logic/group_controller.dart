import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/models/group_model.dart';
import '../data/group_repository.dart';
import '../../../main_providers.dart';

final groupControllerProvider = AsyncNotifierProvider<GroupController, GroupModel?>(GroupController.new);

class GroupController extends AsyncNotifier<GroupModel?> {
  late final GroupRepository _repo;

  @override
  Future<GroupModel?> build() async {
    _repo = GroupRepository(ref.read(firestoreServiceProvider));
    return null; // Not loaded yet
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
    if (state.value == null) return;
    state = const AsyncLoading();
    try {
      await _repo.joinGroup(groupId, userId);
      final gm = state.value!;
      final updated = gm.copyWith(members: [...gm.members,userId]);
      state = AsyncData(updated);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> syncFavorites(String groupId, List<String> sharedFavorites) async {
    if (state.value == null) return;
    state = const AsyncLoading();
    try {
      await _repo.syncFavorites(groupId, sharedFavorites);
      final gm = state.value!;
      final updated = gm.copyWith(sharedFavorites: sharedFavorites);
      state = AsyncData(updated);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
