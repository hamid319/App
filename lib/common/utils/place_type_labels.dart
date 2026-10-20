import '../../l10n/app_localizations.dart';

/// Place types that say nothing to a traveller and are never shown.
const _hiddenPlaceTypes = {'point_of_interest', 'establishment'};

/// Turns raw place types (Google Places values like `tourist_attraction` and
/// the tags of the test data) into short translated labels for chips.
/// Unknown types are shown as readable words instead of snake_case.
List<String> placeTypeLabels(AppLocalizations l10n, List<String> types) {
  final labels = <String>[];
  for (final type in types) {
    if (_hiddenPlaceTypes.contains(type)) continue;
    final label = placeTypeLabel(l10n, type);
    if (!labels.contains(label)) labels.add(label);
  }
  return labels;
}

String placeTypeLabel(AppLocalizations l10n, String type) => switch (type) {
    'tourist_attraction' => l10n.tagTouristAttraction,
    'museum' => l10n.tagMuseum,
    'art_gallery' => l10n.tagArtGallery,
    'art' => l10n.tagArt,
    'culture' => l10n.tagCulture,
    'historical_landmark' => l10n.tagHistoricalLandmark,
    'cultural_landmark' => l10n.tagCulturalLandmark,
    'landmark' => l10n.tagLandmark,
    'history' => l10n.tagHistory,
    'church' => l10n.tagChurch,
    'park' => l10n.tagPark,
    'nature' => l10n.tagNature,
    'natural_feature' => l10n.tagNaturalFeature,
    'outdoors' => l10n.tagOutdoors,
    'beach' => l10n.tagBeach,
    'viewpoint' => l10n.tagViewpoint,
    'hiking' => l10n.tagHiking,
    'family' => l10n.tagFamily,
    'science' => l10n.tagScience,
    'zoo' => l10n.tagZoo,
    'aquarium' => l10n.tagAquarium,
    'amusement_park' => l10n.tagAmusementPark,
    'shopping' => l10n.tagShopping,
    'market' => l10n.tagMarket,
    'nightlife' => l10n.tagNightlife,
    'music' => l10n.tagMusic,
    'architecture' => l10n.tagArchitecture,
    'photo_spot' => l10n.tagPhotoSpot,
    _ => _humanize(type),
  };

String _humanize(String type) {
  final words = type.replaceAll('_', ' ').trim();
  if (words.isEmpty) return words;
  return words[0].toUpperCase() + words.substring(1);
}
