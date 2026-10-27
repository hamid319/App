import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/models/place_model.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/preferences_service.dart';
import '../data/places_repository.dart';
import '../../auth/logic/auth_controller.dart';
import '../../profile/data/profile_repository.dart';
import '../../group/logic/group_controller.dart';
import '../../../main_providers.dart';
import '../../../core/config/app_config.dart';
import '../../../common/models/interest.dart';
import 'discover_preferences_controller.dart';

/// Why the deck has no card to show, so the UI can offer the right way out.
enum DeckEmptyReason {
  /// There are cards.
  none,

  /// No places at all around the chosen location.
  noPlacesInArea,

  /// Places exist, but none match the selected interests.
  filteredOut,

  /// Everything matching has been swiped already.
  allSeen,
}

/// Places the solo deck may show: sights only for now, venues
/// (restaurants, bars ...) live on the home feed.
List<PlaceModel> soloDeckCandidates(Iterable<PlaceModel> places) =>
    places.where((p) => !p.isVenue).toList();

final swipeControllerProvider =
    AsyncNotifierProvider<SwipeController, List<PlaceModel>>(
        SwipeController.new);

/// One solo swipe that can still be taken back. [write] completes when the
/// swipe has been saved, so undo never races the save it is reverting.
class _SwipeStep {
  _SwipeStep({required this.index, required this.place, required this.liked});
  final int index;
  final PlaceModel place;
  final bool liked;
  Future<void> write = Future.value();
}

class SwipeController extends AsyncNotifier<List<PlaceModel>> {
  late PlacesRepository _placesRepo;
  late ProfileRepository _profileRepo;
  late LocationService _locationService;
  int _currentIndex = 0;
  final List<String> _favorites = [];
  Set<String> _swipedPlaceIds = {};
  final List<_SwipeStep> _undoStack = [];
  static const int _maxUndo = 10;
  double _userLat = AppConfig.defaultLat;
  double _userLng = AppConfig.defaultLng;
  DeckEmptyReason _emptyReason = DeckEmptyReason.none;

  /// Meaningful once the deck has run out (see [currentPlace]).
  DeckEmptyReason get emptyReason =>
      currentPlace == null && _emptyReason == DeckEmptyReason.none
          ? DeckEmptyReason.allSeen
          : _emptyReason;

  @override
  Future<List<PlaceModel>> build() async {
    // Shared instance: its city cache spares the home feed's query.
    _placesRepo = ref.read(placesRepositoryProvider);
    _profileRepo = ProfileRepository(ref.read(firestoreServiceProvider));
    _locationService = ref.read(locationServiceProvider);
    _favorites.clear();
    _swipedPlaceIds = {};
    _undoStack.clear();
    _emptyReason = DeckEmptyReason.none;

    // Rebuilds the deck whenever place, radius or interests change.
    final prefs = await ref.watch(discoverPreferencesProvider.future);

    final city = prefs.city;
    if (city != null) {
      _userLat = city.lat;
      _userLng = city.lng;
    } else {
      try {
        final position = await _locationService.getCurrentLocation();
        _userLat = position.latitude;
        _userLng = position.longitude;
      } catch (e) {
        _userLat = AppConfig.defaultLat;
        _userLng = AppConfig.defaultLng;
      }
    }

    final groupState = ref.watch(groupControllerProvider).value;
    final sessionId = groupState?.activeSessionId;

    // Reload when the account changes (guest -> login). A guest upgrade keeps
    // the UID, so it does not reset the stack.
    ref.watch(authControllerProvider.select((s) => s.value?.uid));
    if (ref.read(authControllerProvider).isLoading) {
      // /places needs a signed-in session, so wait for the guest sign-in.
      try {
        await ref.read(authControllerProvider.future);
      } catch (_) {}
    }

    final authState = ref.read(authControllerProvider);
    if (authState.value != null) {
      final userId = authState.value!.uid;
      // Loaded separately: a failing history query (e.g. a missing index)
      // used to clear the favorites that had already loaded fine.
      try {
        final userProfile = await _profileRepo.getUserProfile(userId);
        // Replace rather than append: build() can run again while an
        // earlier run is still awaiting (city, group and auth all trigger
        // it), and appending then counted every favorite several times.
        _favorites
          ..clear()
          ..addAll(userProfile.favorites.toSet());
      } catch (e) {
        debugPrint('Loading favorites failed: $e');
      }
      try {
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
        debugPrint('Loading swipe history failed: $e');
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
          final p = await _placesRepo.getPlaceById(pid);
          if (p != null) sessionPlaces.add(p);
        }
        final filtered = sessionPlaces
            .where((p) => !_swipedPlaceIds.contains(p.id))
            .toList();
        filtered.shuffle();
        if (filtered.isEmpty) _emptyReason = DeckEmptyReason.allSeen;
        return filtered;
      }
    }

    final allPlaces = await _loadSoloPlaces(prefs);
    final matching = allPlaces
        .where((p) => placeMatchesInterests(p, prefs.interests))
        .toList();
    final unseen =
        matching.where((p) => !_swipedPlaceIds.contains(p.id)).toList();
    _emptyReason = allPlaces.isEmpty
        ? DeckEmptyReason.noPlacesInArea
        : matching.isEmpty
            ? DeckEmptyReason.filteredOut
            : unseen.isEmpty
                ? DeckEmptyReason.allSeen
                : DeckEmptyReason.none;
    return unseen;
  }

  /// Curated places of the chosen city, or of the nearest curated city when
  /// browsing near the user, within the chosen radius. Falls back to the
  /// legacy nearby query while a city has no curated places yet.
  Future<List<PlaceModel>> _loadSoloPlaces(DiscoverPreferences prefs) async {
    final places = await _placesRepo.loadPlacesAround(
      cityId: prefs.city?.id,
      lat: _userLat,
      lng: _userLng,
      radiusKm: prefs.radiusKm.toDouble(),
    );
    return soloDeckCandidates(places);
  }

  /// Cards still ahead in the deck, the current one included.
  int get remainingCount {
    final length = state.value?.length ?? 0;
    return length > _currentIndex ? length - _currentIndex : 0;
  }

  PlaceModel? get nextPlaceInDeck {
    final data = state.value;
    final next = _currentIndex + 1;
    if (data == null || next >= data.length) return null;
    return data[next];
  }

  /// Undo is solo-only: in a group session a vote is already counted for
  /// everyone and the session may complete on it.
  bool get canUndo => _undoStack.isNotEmpty && !_inGroupSession;

  bool get _inGroupSession =>
      ref.read(groupControllerProvider).value?.activeSessionId != null;

  PlaceModel? get currentPlace {
    final data = state.value;
    if (data == null || data.isEmpty || _currentIndex >= data.length) {
      return null;
    }
    return data[_currentIndex];
  }

  Future<void> like() async {
    final place = currentPlace;
    if (place == null) return;
    final step = _pushUndo(place, liked: true);

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

      // Favorite and swipe history are saved independently: a failing
      // history write must not cost the user the favorite (it did, while
      // /swipeResults had no deployed rule).
      Future<void> save() async {
        try {
          await _profileRepo.addFavorite(userId, place.id);
          await _syncFavoritesWithGroup(userId);
        } catch (e) {
          debugPrint('Saving favorite ${place.id} failed: $e');
        }
        try {
          await _placesRepo.recordSwipe(
            userId: userId,
            placeId: place.id,
            liked: true,
          );
        } catch (e) {
          debugPrint('Saving swipe ${place.id} failed: $e');
        }
      }

      step?.write = save();
      await step?.write;
    }
  }

  Future<void> skip() async {
    final place = currentPlace;
    if (place == null) return;
    final step = _pushUndo(place, liked: false);

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

      Future<void> save() async {
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

      step?.write = save();
      await step?.write;
    }
  }

  /// True exactly once for a guest, after their first like: tells the UI to
  /// suggest an account so the favorites are kept for good.
  Future<bool> takeGuestFavoriteHint() async {
    final user = ref.read(authControllerProvider).value;
    if (user == null || !user.isAnonymous) return false;
    if (await PreferencesService.hasSeenGuestFavoriteHint()) return false;
    await PreferencesService.setGuestFavoriteHintShown();
    return true;
  }

  _SwipeStep? _pushUndo(PlaceModel place, {required bool liked}) {
    if (_inGroupSession) {
      _undoStack.clear();
      return null;
    }
    final step = _SwipeStep(index: _currentIndex, place: place, liked: liked);
    _undoStack.add(step);
    if (_undoStack.length > _maxUndo) _undoStack.removeAt(0);
    return step;
  }

  /// Brings the last solo swipe back: the card returns to the top, and a
  /// like is removed from favorites again. Returns the restored place.
  Future<PlaceModel?> undo() async {
    if (!canUndo) return null;
    final step = _undoStack.removeLast();
    _currentIndex = step.index;
    if (step.liked) _favorites.remove(step.place.id);
    final data = state.value;
    if (data != null) state = AsyncData(List.of(data));

    final userId = ref.read(authControllerProvider).value?.uid;
    if (userId == null) return step.place;
    try {
      await step.write;
      await _placesRepo.deleteSwipe(userId: userId, placeId: step.place.id);
      if (step.liked) {
        await _profileRepo.removeFavorite(userId, step.place.id);
        await _syncFavoritesWithGroup(userId);
      }
    } catch (e) {
      // The card is back locally; a failed revert only means the server
      // still counts the old swipe.
    }
    return step.place;
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

  Future<void> addFavorite(String placeId) async {
    if (placeId.isEmpty) return;

    if (!_favorites.contains(placeId)) {
      _favorites.add(placeId);
    }

    final data = state.value;
    if (data != null) {
      state = AsyncData(List.of(data));
    }

    final authState = ref.read(authControllerProvider);
    if (authState.value != null) {
      final userId = authState.value!.uid;
      try {
        await _profileRepo.addFavorite(userId, placeId);
        await _syncFavoritesWithGroup(userId);
      } catch (e) {
        // Continue even on error
      }
    }
  }

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
        await _profileRepo.removeFavorite(userId, placeId);
        await _syncFavoritesWithGroup(userId);
      } catch (e) {
        // Continue even on error
      }
    }
  }

  Future<void> resetAll() async {
    _currentIndex = 0;
    _undoStack.clear();
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
