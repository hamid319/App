import 'place_model.dart';

/// What a traveller can filter the deck by. Each interest covers several raw
/// place types (Google Places values and the tags of the test data).
enum Interest {
  culture({
    'museum',
    'art_gallery',
    'art',
    'culture',
    'cultural_landmark',
    'music',
    'science',
    'performing_arts_theater',
  }),
  nature({
    'park',
    'nature',
    'natural_feature',
    'outdoors',
    'hiking',
    'garden',
    'national_park',
  }),
  history({
    'historical_landmark',
    'landmark',
    'history',
    'church',
    'monument',
    'architecture',
    'tourist_attraction',
  }),
  beach({'beach'}),
  views({'viewpoint', 'observation_deck', 'photo_spot'}),
  family({'family', 'zoo', 'aquarium', 'amusement_park', 'playground'}),
  nightlife({'nightlife', 'bar', 'night_club'}),
  shopping({'shopping', 'market', 'shopping_mall'});

  const Interest(this.placeTypes);

  final Set<String> placeTypes;

  static Interest? byName(String name) {
    for (final i in values) {
      if (i.name == name) return i;
    }
    return null;
  }
}

/// True when [place] fits at least one of [interests]. No interests selected
/// means no filter.
bool placeMatchesInterests(PlaceModel place, Set<Interest> interests) {
  if (interests.isEmpty) return true;
  return place.types.any(
    (type) => interests.any((i) => i.placeTypes.contains(type)),
  );
}
