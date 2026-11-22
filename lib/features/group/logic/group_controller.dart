import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/models/group_model.dart';
import '../../../features/auth/logic/auth_controller.dart';
import '../data/group_repository.dart';
import '../../../main_providers.dart';

final groupRepositoryProvider = Provider<GroupRepository>(
  (ref) => GroupRepository(ref.read(firestoreServiceProvider)),
);

class SelectedGroupIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void updateState(String? value) => state = value;
}

final selectedGroupIdProvider =
    NotifierProvider<SelectedGroupIdNotifier, String?>(
        SelectedGroupIdNotifier.new);

/// The signed-in user's trips. The same provider as [myTripsProvider]: it
/// keys on the Firebase uid, so the query starts without waiting for the
/// profile read in [authControllerProvider], and there is one listener.
final userGroupsProvider = myTripsProvider;

/// Display name for a group member, or null when the profile has none.
final groupMemberNameProvider =
    FutureProvider.family<String?, String>((ref, uid) async {
  // Your own name comes from your session: no read, and it is there even
  // before the first public profile write has landed.
  final me = ref.watch(authControllerProvider).value;
  final profile = me != null && me.uid == uid
      ? me
      : await ref.watch(profileRepositoryProvider).getPublicProfile(uid);
  final name = profile.displayName?.trim();
  return (name == null || name.isEmpty) ? null : name;
});

final groupControllerProvider =
    AsyncNotifierProvider<GroupController, GroupModel?>(GroupController.new);

class GroupController extends AsyncNotifier<GroupModel?> {
  GroupRepository get _repo => ref.read(groupRepositoryProvider);

  @override
  Future<GroupModel?> build() async {
    final selectedId = ref.watch(selectedGroupIdProvider);
    if (selectedId == null) return null;

    final userGroupsAsync = ref.watch(userGroupsProvider);
    final cached = state.value;
    if (userGroupsAsync.asData?.value == null &&
        cached != null &&
        cached.groupId == selectedId) {
      return cached;
    }

    final List<GroupModel> userGroups = userGroupsAsync.asData?.value ??
        await ref.watch(userGroupsProvider.future);

    return userGroups.where((g) => g.groupId == selectedId).firstOrNull;
  }

  /// Clears an error left by an earlier attempt. `AsyncLoading` keeps the
  /// previous error, and the dialogs read `hasError` right after the call.
  void _succeeded() => state = AsyncData(state.value);

  bool get isAdmin {
    final currentUser = ref.read(authControllerProvider).value;
    final group = state.value;
    if (currentUser == null || group == null) return false;
    return group.ownerUid == currentUser.uid;
  }

  Future<void> createGroupWithSettings({
    required String groupName,
    required GroupLocation location,
    DateTime? tripStart,
    DateTime? tripEnd,
  }) async {
    final currentUser = ref.read(authControllerProvider).value;
    if (currentUser == null) throw StateError('Not authenticated');

    state = const AsyncLoading();
    try {
      final suffix = FirebaseFirestore.instance.collection('groups').doc().id;
      final groupId = 'trip~$suffix';
      final group = GroupModel(
        groupId: groupId,
        groupName: groupName,
        members: [currentUser.uid],
        ownerUid: currentUser.uid,
        location: location,
        createdAt: DateTime.now(),
        tripStart: tripStart,
        tripEnd: tripEnd,
      );
      await _repo.createGroup(group);
      _succeeded();
      ref.read(selectedGroupIdProvider.notifier).updateState(group.groupId);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> joinByInviteCodeOnly(String code) async {
    final currentUser = ref.read(authControllerProvider).value;
    if (currentUser == null) throw StateError('Not authenticated');

    state = const AsyncLoading();
    try {
      final groupId = await _repo.joinGroupByCodeOnly(code, currentUser.uid);
      _succeeded();
      ref.read(selectedGroupIdProvider.notifier).updateState(groupId);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> joinByInviteLink(String groupId, String code) async {
    final currentUser = ref.read(authControllerProvider).value;
    if (currentUser == null) throw StateError('Not authenticated');

    state = const AsyncLoading();
    try {
      await _repo.joinGroupByInvite(groupId, code, currentUser.uid);
      _succeeded();
      ref.read(selectedGroupIdProvider.notifier).updateState(groupId);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> joinGroup(String groupId, String userId) async {
    state = const AsyncLoading();
    try {
      await _repo.joinGroup(groupId, userId);
      ref.read(selectedGroupIdProvider.notifier).updateState(groupId);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Throws on failure; the caller shows the error.
  Future<void> setTripDates(String groupId, DateTime start, DateTime end) =>
      _repo.updateTripDates(groupId, start, end);

  Future<void> leaveGroup(String groupId, String userId) async {
    state = const AsyncLoading();
    try {
      await _repo.leaveGroup(groupId, userId);
      if (ref.read(selectedGroupIdProvider) == groupId) {
        ref.read(selectedGroupIdProvider.notifier).updateState(null);
      }
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
