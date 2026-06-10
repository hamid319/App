import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/models/group_model.dart';
import '../../../common/models/group_session_model.dart';
import '../../../features/auth/logic/auth_controller.dart';
import '../../../features/profile/data/profile_repository.dart';
import '../../../features/swipe/data/places_repository.dart';
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

final userGroupsProvider = StreamProvider<List<GroupModel>>((ref) {
  final user = ref.watch(authControllerProvider).value;
  if (user == null) return Stream.value([]);
  return ref.watch(groupRepositoryProvider).streamUserGroups(user.uid);
});

final groupControllerProvider =
    AsyncNotifierProvider<GroupController, GroupModel?>(GroupController.new);

class GroupController extends AsyncNotifier<GroupModel?> {
  String? _lastMembersSignature;
  List<String>? _lastSharedFavorites;

  GroupRepository get _repo => ref.read(groupRepositoryProvider);
  ProfileRepository get _profileRepo =>
      ProfileRepository(ref.read(firestoreServiceProvider));
  PlacesRepository get _placesRepo => PlacesRepository();

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

    try {
      final group = userGroups.firstWhere((g) => g.groupId == selectedId);

      var resolvedGroup = group;
      final sessionId = group.activeSessionId;
      if (sessionId != null) {
        final session = await _repo.getSession(
          groupId: group.groupId,
          sessionId: sessionId,
        );
        if (session == null) {
          await _repo.clearActiveSessionIfMatch(
            groupId: group.groupId,
            sessionId: sessionId,
          );
          resolvedGroup = group.copyWith(activeSessionId: null);
        }
      }

      final membersSignature = _buildMembersSignature(
        resolvedGroup.groupId,
        resolvedGroup.members,
      );
      if (_lastMembersSignature != membersSignature ||
          _lastSharedFavorites == null) {
        _lastSharedFavorites = await calculateGroupMatches(resolvedGroup);
        _lastMembersSignature = membersSignature;
      }
      return resolvedGroup.copyWith(
          sharedFavorites: _lastSharedFavorites ?? const []);
    } catch (_) {
      return null;
    }
  }

  String _buildMembersSignature(String groupId, List<String> members) {
    final sortedMembers = List<String>.from(members)..sort();
    return '$groupId:${sortedMembers.join('|')}';
  }

  bool get isAdmin {
    final currentUser = ref.read(authControllerProvider).value;
    final group = state.value;
    if (currentUser == null || group == null) return false;
    return group.ownerUid == currentUser.uid;
  }

  bool get canJoin {
    return state.value?.joinEnabled ?? false;
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = math.Random();
    return String.fromCharCodes(Iterable.generate(
        6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  Future<void> createGroupWithSettings({
    required String groupName,
    required GroupLocation location,
  }) async {
    final currentUser = ref.read(authControllerProvider).value;
    if (currentUser == null) throw StateError('Not authenticated');

    state = const AsyncLoading();
    try {
      final groupId = FirebaseFirestore.instance.collection('groups').doc().id;
      final group = GroupModel(
        groupId: groupId,
        groupName: groupName,
        members: [currentUser.uid],
        ownerUid: currentUser.uid,
        location: location,
        joinEnabled: true,
        invite:
            GroupInvite(code: _generateInviteCode(), createdAt: DateTime.now()),
        createdAt: DateTime.now(),
      );
      await _repo.createGroup(group);
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

  Future<List<String>> calculateGroupMatches(GroupModel group) async {
    if (group.members.isEmpty) return [];

    final List<Future<List<String>>> futures = group.members.map((uid) async {
      try {
        return await _profileRepo.getUserFavorites(uid);
      } catch (_) {
        return const <String>[];
      }
    }).toList();

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

    try {
      final updatedMatches = await calculateGroupMatches(currentGroup);
      await _repo.syncFavorites(currentGroup.groupId, updatedMatches);
      // We don't need to manually update state, the snapshot will trigger a rebuild!
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> syncFavorites(
      String groupId, List<String> sharedFavorites) async {
    try {
      await _repo.syncFavorites(groupId, sharedFavorites);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

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

  Future<void> startSessionWithLimit({required int swipeLimit}) async {
    final group = state.value;
    if (group == null) return;

    if (!isAdmin) {
      throw StateError('Only the admin can start the session');
    }

    state = const AsyncLoading();
    try {
      final location = group.location;
      if (location == null) {
        throw StateError('Group location is required to start a session');
      }
      final destination = location.cityName.isNotEmpty
          ? location.cityName
          : location.countryName;
      final places = await _placesRepo.fetchExamplePlacesForLocation(
        location,
        limit: swipeLimit,
      );

      if (places.isEmpty) {
        throw StateError('No places found for this destination');
      }

      final placePool = places.map((p) => p.id).toList();

      await _repo.startSwipeSession(
        groupId: group.groupId,
        destination: destination,
        participantUids: group.members,
        swipeLimit: swipeLimit,
        placePool: placePool,
      );
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> startSession({
    required String destination,
  }) async {
    final group = state.value;
    if (group == null) return;

    if (!isAdmin) {
      throw StateError('Only the admin can start the session');
    }

    state = const AsyncLoading();
    try {
      final location = group.location;
      if (location == null) {
        throw StateError('Group location is required to start a session');
      }
      final resolvedDestination = location.cityName.isNotEmpty
          ? location.cityName
          : location.countryName;
      final places = await _placesRepo.fetchExamplePlacesForLocation(
        location,
        limit: 20,
      );

      if (places.isEmpty) {
        throw StateError('No places found for this destination');
      }

      await _repo.startSwipeSession(
        groupId: group.groupId,
        destination:
            resolvedDestination.isNotEmpty ? resolvedDestination : destination,
        participantUids: group.members,
        swipeLimit: places.length,
        placePool: places.map((p) => p.id).toList(),
      );
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> castVote({
    required String placeId,
    required bool liked,
  }) async {
    final group = state.value;
    final sessionId = group?.activeSessionId;
    if (group == null || sessionId == null) {
      throw StateError('No active group session');
    }

    final currentUser = ref.read(authControllerProvider).value;
    if (currentUser == null) {
      throw StateError('User not authenticated');
    }

    await _repo.recordSwipeInSession(
      groupId: group.groupId,
      sessionId: sessionId,
      userId: currentUser.uid,
      placeId: placeId,
      liked: liked,
    );
  }

  Future<void> endSession() async {
    final group = state.value;
    final sessionId = group?.activeSessionId;
    final currentUser = ref.read(authControllerProvider).value;
    if (group == null || sessionId == null || currentUser == null) return;

    if (!isAdmin) {
      throw StateError('Only the admin can end the session');
    }

    await _repo.endSessionManually(
      groupId: group.groupId,
      sessionId: sessionId,
      adminUid: currentUser.uid,
    );
  }

  Future<void> updateSessionOrder(
      String sessionId, List<String> orderedPlaceIds) async {
    final group = state.value;
    if (group == null) return;
    if (!isAdmin) {
      throw StateError('Only the admin can reorder the session list');
    }
    await _repo.updateSessionOrder(group.groupId, sessionId, orderedPlaceIds);
  }
}

final activeSessionProvider =
    StreamNotifierProvider<ActiveSessionNotifier, GroupSessionModel?>(
  ActiveSessionNotifier.new,
);

class ActiveSessionNotifier extends StreamNotifier<GroupSessionModel?> {
  @override
  Stream<GroupSessionModel?> build() {
    final group = ref.watch(groupControllerProvider).value;
    final sessionId = group?.activeSessionId;
    if (group == null || sessionId == null) return Stream.value(null);

    return ref.read(groupRepositoryProvider).streamSession(
          groupId: group.groupId,
          sessionId: sessionId,
        );
  }
}
