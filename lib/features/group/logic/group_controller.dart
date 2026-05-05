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

final groupControllerProvider =
    AsyncNotifierProvider<GroupController, GroupModel?>(GroupController.new);

class GroupController extends AsyncNotifier<GroupModel?> {
  late final GroupRepository _repo;
  late final ProfileRepository _profileRepo;
  late final PlacesRepository _placesRepo;

  @override
  Future<GroupModel?> build() async {
    _repo = GroupRepository(ref.read(firestoreServiceProvider));
    _profileRepo = ProfileRepository(ref.read(firestoreServiceProvider));
    _placesRepo = PlacesRepository();
    return null;
  }

  Future<void> loadGroup(String groupId) async {
    state = const AsyncLoading();
    try {
      final group = await _repo.getGroup(groupId);
      if (group != null) {
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

        try {
          final updatedMatches = await calculateGroupMatches(resolvedGroup);
          final updatedGroup =
              resolvedGroup.copyWith(sharedFavorites: updatedMatches);
          state = AsyncData(updatedGroup);
        } catch (_) {
          state = AsyncData(resolvedGroup);
        }
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

    state = const AsyncLoading();
    try {
      final updatedMatches = await calculateGroupMatches(currentGroup);
      await _repo.syncFavorites(currentGroup.groupId, updatedMatches);
      final updatedGroup =
          currentGroup.copyWith(sharedFavorites: updatedMatches);
      state = AsyncData(updatedGroup);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> syncFavorites(
      String groupId, List<String> sharedFavorites) async {
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

  /// Admin starts a new session. Fetches places for [destination] first,
  /// then writes the session to Firestore.
  Future<void> startSession({
    required String destination,
    required int threshold,
  }) async {
    final group = state.value;
    if (group == null) return;

    state = const AsyncLoading();
    try {
      final places = await _placesRepo.fetchPlacesFromGoogleAPI(destination);

      if (places.isEmpty) {
        throw StateError('No places found for this destination');
      }

      await _repo.startSwipeSession(
        groupId: group.groupId,
        destination: destination,
        threshold: threshold,
        participantUids: group.members,
        totalPlaces: places.length,
      );

      final updated = await _repo.getGroup(group.groupId);
      state = AsyncData(updated);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Called after every swipe during a session.
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

    final refreshedGroup = await _repo.getGroup(group.groupId);
    if (refreshedGroup != null) {
      state = AsyncData(refreshedGroup);
    }
  }

  /// Admin manually ends the session.
  Future<void> endSession() async {
    final group = state.value;
    final sessionId = group?.activeSessionId;
    final currentUser = ref.read(authControllerProvider).value;
    if (group == null || sessionId == null || currentUser == null) return;

    await _repo.endSessionManually(
      groupId: group.groupId,
      sessionId: sessionId,
      adminUid: currentUser.uid,
    );

    final refreshedGroup = await _repo.getGroup(group.groupId);
    if (refreshedGroup != null) {
      state = AsyncData(refreshedGroup);
    }
  }
}

/// Separate StreamNotifier -- watches the active session doc in real-time.
/// The swipe UI and results screen both watch this.
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
