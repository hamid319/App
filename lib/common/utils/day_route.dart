import 'geo_utils.dart';

/// A stop on a day route with its coordinates.
class RouteStop {
  final String id;
  final double lat;
  final double lng;

  const RouteStop({required this.id, required this.lat, required this.lng});
}

/// Farther than this from the places, the user's position is ignored (they
/// are planning from home, not standing in the city).
const double routeOriginMaxKm = 30;

/// Orders [stops] into a short walking route.
///
/// With an [origin] near the places, the route starts next to it, or ends
/// next to it when [endNearOrigin] is set (start at the far end, finish
/// close to the accommodation). Without a usable origin the route starts at
/// the first stop (the group's favourite) and [endNearOrigin] is ignored.
///
/// Nearest neighbour followed by 2-opt: exact enough for the handful of
/// stops of a day and instant on the device.
List<RouteStop> orderDayRoute(
  List<RouteStop> stops, {
  ({double lat, double lng})? origin,
  bool endNearOrigin = true,
}) {
  if (stops.length < 2) return List.of(stops);
  final usable = origin != null && _isNear(origin, stops);

  if (!usable) {
    return _improve(_nearestNeighbour(stops.first, stops.skip(1).toList()),
        fixFirst: true);
  }

  // Build outwards from the origin; reversed, the route ends there.
  final anchor = RouteStop(id: '', lat: origin.lat, lng: origin.lng);
  final route = _improve(_nearestNeighbour(anchor, stops), fixFirst: true)
      .skip(1)
      .toList();
  return endNearOrigin ? route.reversed.toList() : route;
}

/// Whether [origin] is close enough to the stops to plan around it.
bool isOriginNear(({double lat, double lng}) origin, List<RouteStop> stops) =>
    stops.isNotEmpty && _isNear(origin, stops);

/// Straight-line distance in km between two stops.
double legKm(RouteStop a, RouteStop b) =>
    GeoUtils.calculateDistance(a.lat, a.lng, b.lat, b.lng);

bool _isNear(({double lat, double lng}) origin, List<RouteStop> stops) =>
    stops.any((s) =>
        GeoUtils.calculateDistance(origin.lat, origin.lng, s.lat, s.lng) <=
        routeOriginMaxKm);

List<RouteStop> _nearestNeighbour(RouteStop start, List<RouteStop> rest) {
  final route = [start];
  final left = List.of(rest);
  while (left.isNotEmpty) {
    final last = route.last;
    left.sort((a, b) => legKm(last, a).compareTo(legKm(last, b)));
    route.add(left.removeAt(0));
  }
  return route;
}

double _length(List<RouteStop> route) {
  var total = 0.0;
  for (var i = 1; i < route.length; i++) {
    total += legKm(route[i - 1], route[i]);
  }
  return total;
}

/// 2-opt on an open path: reverses segments while that shortens it.
List<RouteStop> _improve(List<RouteStop> route, {required bool fixFirst}) {
  var best = List.of(route);
  var bestLength = _length(best);
  var improved = true;
  final from = fixFirst ? 1 : 0;
  while (improved) {
    improved = false;
    for (var i = from; i < best.length - 1; i++) {
      for (var k = i + 1; k < best.length; k++) {
        final candidate = [
          ...best.sublist(0, i),
          ...best.sublist(i, k + 1).reversed,
          ...best.sublist(k + 1),
        ];
        final length = _length(candidate);
        if (length < bestLength - 1e-9) {
          best = candidate;
          bestLength = length;
          improved = true;
        }
      }
    }
  }
  return best;
}
