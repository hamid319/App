/// Geohash cells of the place tiles written by tools/city-import
/// (src/tiles.ts): one document per city and geohash-5 cell (~4.9 km).
/// Must match the import's encoding.
library;

const placeTilePrecision = 5;

const _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

/// Standard geohash of a position.
String geohash(double lat, double lng, [int precision = placeTilePrecision]) {
  var latMin = -90.0, latMax = 90.0, lngMin = -180.0, lngMax = 180.0;
  final hash = StringBuffer();
  var bits = 0, value = 0, evenBit = true;
  while (hash.length < precision) {
    if (evenBit) {
      final mid = (lngMin + lngMax) / 2;
      if (lng >= mid) {
        value = value * 2 + 1;
        lngMin = mid;
      } else {
        value *= 2;
        lngMax = mid;
      }
    } else {
      final mid = (latMin + latMax) / 2;
      if (lat >= mid) {
        value = value * 2 + 1;
        latMin = mid;
      } else {
        value *= 2;
        latMax = mid;
      }
    }
    evenBit = !evenBit;
    if (++bits == 5) {
      hash.write(_base32[value]);
      bits = 0;
      value = 0;
    }
  }
  return hash.toString();
}

/// The cell of a position and its 8 neighbours (about 15 x 15 km at
/// precision 5), so a user near a cell edge still gets both sides.
Set<String> geohashesAround(double lat, double lng,
    [int precision = placeTilePrecision]) {
  // Cell size in degrees: longitude gets the extra bit for odd lengths.
  final lngBits = (precision * 5 + 1) ~/ 2;
  final latBits = precision * 5 ~/ 2;
  final dLat = 180 / (1 << latBits);
  final dLng = 360 / (1 << lngBits);
  return {
    for (final i in const [-1, 0, 1])
      for (final j in const [-1, 0, 1])
        geohash(
            (lat + i * dLat).clamp(-89.999, 89.999), lng + j * dLng, precision),
  };
}
