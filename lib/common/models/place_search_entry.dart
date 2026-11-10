/// One place in a city's search index (placeSearch/{cityId}_{part}, written
/// by tools/city-import/src/search.ts): just enough to find and list it.
class PlaceSearchEntry {
  const PlaceSearchEntry({
    required this.id,
    required this.name,
    this.nameDe,
    this.isVenue = false,
    this.type,
  });

  final String id;
  final String name;
  final String? nameDe;
  final bool isVenue;

  /// Main place type (e.g. `museum`, `cafe`).
  final String? type;

  String nameFor(String languageCode) =>
      languageCode == 'de' ? nameDe ?? name : name;

  factory PlaceSearchEntry.fromJson(Map<String, dynamic> json) =>
      PlaceSearchEntry(
        id: json['i'] as String,
        name: json['n'] as String,
        nameDe: json['d'] as String?,
        isVenue: json['k'] == 'v',
        type: json['t'] as String?,
      );
}
