import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/models/place_model.dart';
import '../data/places_repository.dart';

final swipeControllerProvider = AsyncNotifierProvider<SwipeController, List<PlaceModel>>(SwipeController.new);

class SwipeController extends AsyncNotifier<List<PlaceModel>> {
  late final PlacesRepository _repo;
  int _currentIndex = 0;
  final List<String> _favorites = [];

  @override
  Future<List<PlaceModel>> build() async {
    _repo = PlacesRepository();
    final places = await _repo.loadNearbyPlaces(0, 0, useMock: true);
    return places;
  }

  PlaceModel? get currentPlace {
    final data = state.value;
    if (data == null || data.isEmpty || _currentIndex >= data.length) return null;
    return data[_currentIndex];
  }

  void like() {
    final place = currentPlace;
    if (place == null) return;
    _favorites.add(place.id);
    nextPlace();
  }

  void skip() => nextPlace();

  void nextPlace() {
    final data = state.value;
    if (data == null) return;
    if (_currentIndex < data.length - 1) {
      _currentIndex++;
    } else {
      // End of deck
      _currentIndex = data.length;
    }
    state = AsyncData(data);
  }

  List<String> get favoritesList => List.unmodifiable(_favorites);
}
