import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/models/place_model.dart';
import '../../../core/services/location_service.dart';
import '../data/places_repository.dart';
import '../../auth/logic/auth_controller.dart';
import '../../profile/data/profile_repository.dart';
import '../../group/logic/group_controller.dart';
import '../../../main_providers.dart';

final swipeControllerProvider =
    AsyncNotifierProvider<SwipeController, List<PlaceModel>>(
        SwipeController.new);

class SwipeController extends AsyncNotifier<List<PlaceModel>> {
  late PlacesRepository _placesRepo;
  late ProfileRepository _profileRepo;
  late LocationService _locationService;
  int _currentIndex = 0;
  final List<String> _favorites = [];
  Set<String> _swipedPlaceIds = {};
  double _userLat = 34.0522;
  double _userLng = -118.2437;
  static const double _defaultRadiusKm = 50.0;

  @override
  Future<List<PlaceModel>> build() async {
    _placesRepo = PlacesRepository();
    _profileRepo = ProfileRepository(ref.read(firestoreServiceProvider));
    _locationService = ref.read(locationServiceProvider);
    _favorites.clear();
    _swipedPlaceIds = {};

    try {
      final position = await _locationService.getCurrentLocation();
      _userLat = position.latitude;
      _userLng = position.longitude;
    } catch (e) {
      // Use default location if location services fail
    }

    final groupState = ref.watch(groupControllerProvider).value;
    final sessionId = groupState?.activeSessionId;

    final authState = ref.read(authControllerProvider);
    if (authState.value != null) {
      final userId = authState.value!.uid;
      try {
        final userProfile = await _profileRepo.getUserProfile(userId);
        _favorites.addAll(userProfile.favorites);

        if (groupState != null && sessionId != null) {
          final groupRepo = ref.read(groupRepositoryProvider);
          _swipedPlaceIds = await groupRepo.getUserSwipedPlaceIds(
            groupId: groupState.groupId,
            sessionId: sessionId,
            userId: userId,
          );
        } else {
          _swipedPlaceIds = await _placesRepo.getSwipedPlaceIds(userId);
        }
      } catch (e) {
        _favorites.clear();
        _swipedPlaceIds = {};
      }
    }

    if (groupState != null && sessionId != null) {
      final groupRepo = ref.read(groupRepositoryProvider);
      final session = await groupRepo.getSession(
          groupId: groupState.groupId, sessionId: sessionId);
      if (session != null) {
        List<PlaceModel> sessionPlaces = [];
        for (var pid in session.placePool) {
          final p = await _placesRepo.getPlaceById(pid, useMock: false);
          if (p != null) sessionPlaces.add(p);
        }
        final filtered = sessionPlaces.where((p) => !_swipedPlaceIds.contains(p.id)).toList();
        filtered.shuffle();
        return filtered;
      }
    }

    try {
      final allPlaces = await _placesRepo.loadNearbyPlaces(
        _userLat,
        _userLng,
        radiusKm: _defaultRadiusKm,
        useMock: true,
      );
      final unseenPlaces =
          allPlaces.where((p) => !_swipedPlaceIds.contains(p.id)).toList();
      return unseenPlaces;
    } catch (e) {
      final allPlaces = PlacesRepository.mockPlaces;
      return allPlaces.where((p) => !_swipedPlaceIds.contains(p.id)).toList();
    }
  }

  Future<void> refreshWithLocation() async {
    state = const AsyncLoading();
    try {
      final position = await _locationService.getCurrentLocation();
      _userLat = position.latitude;
      _userLng = position.longitude;

      final allPlaces = await _placesRepo.loadNearbyPlaces(
        _userLat,
        _userLng,
        radiusKm: _defaultRadiusKm,
        useMock: true,
      );
      final unseenPlaces =
          allPlaces.where((p) => !_swipedPlaceIds.contains(p.id)).toList();
      _currentIndex = 0;
      state = AsyncData(unseenPlaces);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  PlaceModel? get currentPlace {
    final data = state.value;
    if (data == null || data.isEmpty || _currentIndex >= data.length)
      return null;
    return data[_currentIndex];
  }

  Future<void> like() async {
    final place = currentPlace;
    if (place == null) return;

    // Advance immediately so the UI doesn't freeze waiting for network
    nextPlace();

    final authState = ref.read(authControllerProvider);
    if (authState.value != null) {
      final userId = authState.value!.uid;
      final groupState = ref.read(groupControllerProvider).value;
      final hasActiveSession = groupState?.activeSessionId != null;

      if (hasActiveSession) {
        _swipedPlaceIds.add(place.id);
        try {
          await ref
              .read(groupControllerProvider.notifier)
              .castVote(placeId: place.id, liked: true);
        } catch (_) {}
        return;
      }

      if (!_favorites.contains(place.id)) {
        _favorites.add(place.id);
      }

      try {
        await _placesRepo.recordSwipe(
          userId: userId,
          placeId: place.id,
          liked: true,
        );

        await _profileRepo.updateUserProfile(userId, {'favorites': _favorites});
        await _syncFavoritesWithGroup(userId);
      } catch (e) {
        // Continue even on error
      }
    }
  }

  Future<void> skip() async {
    final place = currentPlace;
    if (place == null) return;

    // Advance immediately so the UI doesn't freeze waiting for network
    nextPlace();

    final authState = ref.read(authControllerProvider);
    if (authState.value != null) {
      final userId = authState.value!.uid;
      final groupState = ref.read(groupControllerProvider).value;
      final hasActiveSession = groupState?.activeSessionId != null;

      if (hasActiveSession) {
        _swipedPlaceIds.add(place.id);
        try {
          await ref
              .read(groupControllerProvider.notifier)
              .castVote(placeId: place.id, liked: false);
        } catch (_) {}
        return;
      }

      try {
        await _placesRepo.recordSwipe(
          userId: userId,
          placeId: place.id,
          liked: false,
        );
      } catch (e) {
        // Continue even on error
      }
    }
  }

  void nextPlace() {
    final data = state.value;
    if (data == null) return;
    if (_currentIndex < data.length - 1) {
      _currentIndex++;
    } else {
      _currentIndex = data.length;
    }
    // Emit a new list so Riverpod detects the state change
    state = AsyncData(List.of(data));
  }

  List<String> get favoritesList => List.unmodifiable(_favorites);

  bool isFavorite(String placeId) => _favorites.contains(placeId);

  Future<void> removeFavorite(String placeId) async {
    _favorites.remove(placeId);
    // Emit a new list so Riverpod detects the state change
    final data = state.value;
    if (data != null) {
      state = AsyncData(List.of(data));
    }

    final authState = ref.read(authControllerProvider);
    if (authState.value != null) {
      final userId = authState.value!.uid;
      try {
        await _profileRepo.updateUserProfile(userId, {'favorites': _favorites});
        await _syncFavoritesWithGroup(userId);
      } catch (e) {
        // Continue even on error
      }
    }
  }

  Future<void> resetAll() async {
    _currentIndex = 0;
    _favorites.clear();
    _swipedPlaceIds = {};

    final authState = ref.read(authControllerProvider);
    if (authState.value != null) {
      final userId = authState.value!.uid;
      try {
        await _profileRepo.updateUserProfile(userId, {'favorites': []});
        await _placesRepo.clearSwipedPlaces(userId);
      } catch (_) {}
    }

    ref.invalidateSelf();
  }

  Future<void> _syncFavoritesWithGroup(String userId) async {
    try {
      final groupController = ref.read(groupControllerProvider.notifier);
      final groupState = ref.read(groupControllerProvider);

      if (groupState.value != null) {
        final group = groupState.value!;
        if (group.members.contains(userId)) {
          final mutualFavorites = await _findMutualFavorites(group.members);
          await groupController.syncFavorites(group.groupId, mutualFavorites);
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<List<String>> _findMutualFavorites(List<String> memberIds) async {
    if (memberIds.isEmpty) return [];

    final List<Set<String>> memberFavoriteSets = [];

    for (final memberId in memberIds) {
      try {
        final userProfile = await _profileRepo.getUserProfile(memberId);
        memberFavoriteSets.add(userProfile.favorites.toSet());
      } catch (e) {
        memberFavoriteSets.add({});
      }
    }

    if (memberFavoriteSets.isEmpty) return [];

    Set<String> intersection = memberFavoriteSets.first;
    for (final favorites in memberFavoriteSets.skip(1)) {
      intersection = intersection.intersection(favorites);
    }

    return intersection.toList();
  }
}
