import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/models/place_model.dart';
import '../../../core/services/location_service.dart';
import '../data/places_repository.dart';
import '../../auth/logic/auth_controller.dart';
import '../../profile/data/profile_repository.dart';
import '../../group/logic/group_controller.dart';
import '../../../main_providers.dart';

final swipeControllerProvider = AsyncNotifierProvider<SwipeController, List<PlaceModel>>(SwipeController.new);

class SwipeController extends AsyncNotifier<List<PlaceModel>> {
  late final PlacesRepository _placesRepo;
  late final ProfileRepository _profileRepo;
  late final LocationService _locationService;
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
    _currentIndex = 0;
    _favorites.clear();
    _swipedPlaceIds = {};
    
    try {
      final position = await _locationService.getCurrentLocation();
      _userLat = position.latitude;
      _userLng = position.longitude;
    } catch (e) {
      // Use default location if location services fail
    }
    
    final authState = ref.read(authControllerProvider);
    if (authState.value != null) {
      final userId = authState.value!.uid;
      try {
        final userProfile = await _profileRepo.getUserProfile(userId);
        _favorites.addAll(userProfile.favorites);
        
        _swipedPlaceIds = await _placesRepo.getSwipedPlaceIds(userId);
      } catch (e) {
        _favorites.clear();
        _swipedPlaceIds = {};
      }
    }
    
    try {
      final allPlaces = await _placesRepo.loadNearbyPlaces(
        _userLat, 
        _userLng, 
        radiusKm: _defaultRadiusKm,
        useMock: true,
      );
      final unseenPlaces = allPlaces.where((p) => !_swipedPlaceIds.contains(p.id)).toList();
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
      final unseenPlaces = allPlaces.where((p) => !_swipedPlaceIds.contains(p.id)).toList();
      _currentIndex = 0;
      state = AsyncData(unseenPlaces);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  PlaceModel? get currentPlace {
    final data = state.value;
    if (data == null || data.isEmpty || _currentIndex >= data.length) return null;
    return data[_currentIndex];
  }

  Future<void> like() async {
    final place = currentPlace;
    if (place == null) return;
    
    final authState = ref.read(authControllerProvider);
    if (authState.value != null) {
      final userId = authState.value!.uid;
      
      try {
        await _placesRepo.recordSwipe(
          userId: userId,
          placeId: place.id,
          liked: true,
        );
        
        if (!_favorites.contains(place.id)) {
          _favorites.add(place.id);
        }
        
        await _profileRepo.updateUserProfile(userId, {'favorites': _favorites});
        await _syncFavoritesWithGroup(userId);
      } catch (e) {
        // Continue even on error
      }
    }
    
    nextPlace();
  }

  Future<void> skip() async {
    final place = currentPlace;
    if (place == null) return;
    
    final authState = ref.read(authControllerProvider);
    if (authState.value != null) {
      try {
        await _placesRepo.recordSwipe(
          userId: authState.value!.uid,
          placeId: place.id,
          liked: false,
        );
      } catch (e) {
        // Continue even on error
      }
    }
    
    nextPlace();
  }

  void nextPlace() {
    final data = state.value;
    if (data == null) return;
    if (_currentIndex < data.length - 1) {
      _currentIndex++;
    } else {
      _currentIndex = data.length;
    }
    state = AsyncData(data);
  }

  List<String> get favoritesList => List.unmodifiable(_favorites);

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
