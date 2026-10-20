/// A destination the user can pick on Discover without GPS. City names are
/// given per language because several differ (Munich / München).
class PopularCity {
  const PopularCity({
    required this.id,
    required this.nameEn,
    required this.nameDe,
    required this.countryCode,
    required this.lat,
    required this.lng,
  });

  final String id;
  final String nameEn;
  final String nameDe;
  final String countryCode;
  final double lat;
  final double lng;

  String nameFor(String languageCode) => languageCode == 'de' ? nameDe : nameEn;

  /// English country name, as stored on a group's location.
  String get countryNameEn => _countryNames[countryCode] ?? countryCode;

  /// Finds a city named (in English or German) in free text such as a
  /// calendar event's location or title, e.g. "Wochenende Lissabon".
  /// Texts are checked in order; whole words only, so "Rom" does not match
  /// "Romantik".
  static PopularCity? findIn(Iterable<String?> texts) {
    String words(String text) =>
        ' ${text.toLowerCase().split(RegExp(r'[^\p{L}]+', unicode: true)).where((w) => w.isNotEmpty).join(' ')} ';
    final byLength = [...popularCities]
      ..sort((a, b) => b.nameEn.length.compareTo(a.nameEn.length));
    for (final text in texts) {
      if (text == null || text.trim().isEmpty) continue;
      final haystack = words(text);
      for (final city in byLength) {
        if (haystack.contains(words(city.nameEn)) ||
            haystack.contains(words(city.nameDe))) {
          return city;
        }
      }
    }
    return null;
  }

  static PopularCity? byId(String? id) {
    if (id == null) return null;
    for (final c in popularCities) {
      if (c.id == id) return c;
    }
    return null;
  }
}

/// Curated list until a real place search is wired to the backend.
/// Los Angeles first: the current Firestore test places are there.
const popularCities = [
  PopularCity(id: 'us_los_angeles', nameEn: 'Los Angeles', nameDe: 'Los Angeles', countryCode: 'US', lat: 34.0522, lng: -118.2437),
  PopularCity(id: 'de_hamburg', nameEn: 'Hamburg', nameDe: 'Hamburg', countryCode: 'DE', lat: 53.5511, lng: 9.9937),
  PopularCity(id: 'de_berlin', nameEn: 'Berlin', nameDe: 'Berlin', countryCode: 'DE', lat: 52.5200, lng: 13.4050),
  PopularCity(id: 'de_munich', nameEn: 'Munich', nameDe: 'München', countryCode: 'DE', lat: 48.1351, lng: 11.5820),
  PopularCity(id: 'de_cologne', nameEn: 'Cologne', nameDe: 'Köln', countryCode: 'DE', lat: 50.9375, lng: 6.9603),
  PopularCity(id: 'at_vienna', nameEn: 'Vienna', nameDe: 'Wien', countryCode: 'AT', lat: 48.2082, lng: 16.3738),
  PopularCity(id: 'ch_zurich', nameEn: 'Zurich', nameDe: 'Zürich', countryCode: 'CH', lat: 47.3769, lng: 8.5417),
  PopularCity(id: 'fr_paris', nameEn: 'Paris', nameDe: 'Paris', countryCode: 'FR', lat: 48.8566, lng: 2.3522),
  PopularCity(id: 'gb_london', nameEn: 'London', nameDe: 'London', countryCode: 'GB', lat: 51.5074, lng: -0.1278),
  PopularCity(id: 'nl_amsterdam', nameEn: 'Amsterdam', nameDe: 'Amsterdam', countryCode: 'NL', lat: 52.3676, lng: 4.9041),
  PopularCity(id: 'es_barcelona', nameEn: 'Barcelona', nameDe: 'Barcelona', countryCode: 'ES', lat: 41.3874, lng: 2.1686),
  PopularCity(id: 'es_madrid', nameEn: 'Madrid', nameDe: 'Madrid', countryCode: 'ES', lat: 40.4168, lng: -3.7038),
  PopularCity(id: 'pt_lisbon', nameEn: 'Lisbon', nameDe: 'Lissabon', countryCode: 'PT', lat: 38.7223, lng: -9.1393),
  PopularCity(id: 'it_rome', nameEn: 'Rome', nameDe: 'Rom', countryCode: 'IT', lat: 41.9028, lng: 12.4964),
  PopularCity(id: 'it_milan', nameEn: 'Milan', nameDe: 'Mailand', countryCode: 'IT', lat: 45.4642, lng: 9.1900),
  PopularCity(id: 'cz_prague', nameEn: 'Prague', nameDe: 'Prag', countryCode: 'CZ', lat: 50.0755, lng: 14.4378),
  PopularCity(id: 'dk_copenhagen', nameEn: 'Copenhagen', nameDe: 'Kopenhagen', countryCode: 'DK', lat: 55.6761, lng: 12.5683),
  PopularCity(id: 'tr_istanbul', nameEn: 'Istanbul', nameDe: 'Istanbul', countryCode: 'TR', lat: 41.0082, lng: 28.9784),
  PopularCity(id: 'gr_athens', nameEn: 'Athens', nameDe: 'Athen', countryCode: 'GR', lat: 37.9838, lng: 23.7275),
  PopularCity(id: 'us_new_york', nameEn: 'New York', nameDe: 'New York', countryCode: 'US', lat: 40.7128, lng: -74.0060),
  PopularCity(id: 'us_san_francisco', nameEn: 'San Francisco', nameDe: 'San Francisco', countryCode: 'US', lat: 37.7749, lng: -122.4194),
  PopularCity(id: 'jp_tokyo', nameEn: 'Tokyo', nameDe: 'Tokio', countryCode: 'JP', lat: 35.6762, lng: 139.6503),
  PopularCity(id: 'th_bangkok', nameEn: 'Bangkok', nameDe: 'Bangkok', countryCode: 'TH', lat: 13.7563, lng: 100.5018),
  PopularCity(id: 'ae_dubai', nameEn: 'Dubai', nameDe: 'Dubai', countryCode: 'AE', lat: 25.2048, lng: 55.2708),
  PopularCity(id: 'sg_singapore', nameEn: 'Singapore', nameDe: 'Singapur', countryCode: 'SG', lat: 1.3521, lng: 103.8198),
];

const _countryNames = {
  'AE': 'United Arab Emirates',
  'AT': 'Austria',
  'CH': 'Switzerland',
  'CZ': 'Czechia',
  'DE': 'Germany',
  'DK': 'Denmark',
  'ES': 'Spain',
  'FR': 'France',
  'GB': 'United Kingdom',
  'GR': 'Greece',
  'IT': 'Italy',
  'JP': 'Japan',
  'NL': 'Netherlands',
  'PT': 'Portugal',
  'SG': 'Singapore',
  'TH': 'Thailand',
  'TR': 'Turkey',
  'US': 'United States',
};
