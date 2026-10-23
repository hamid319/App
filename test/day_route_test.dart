import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/common/models/group_session_model.dart';
import 'package:swipetrip/common/utils/day_route.dart';

void main() {
  // Places on a line west to east through Berlin, ~1.4 km apart.
  const west = RouteStop(id: 'west', lat: 52.5163, lng: 13.3500);
  const midWest = RouteStop(id: 'midWest', lat: 52.5163, lng: 13.3700);
  const midEast = RouteStop(id: 'midEast', lat: 52.5163, lng: 13.3900);
  const east = RouteStop(id: 'east', lat: 52.5163, lng: 13.4100);
  final shuffled = [midEast, west, east, midWest];
  // The hotel is just east of the eastern place.
  const hotel = (lat: 52.5163, lng: 13.4200);

  List<String> ids(List<RouteStop> route) => route.map((s) => s.id).toList();

  test('ends next to the accommodation, starting at the farthest place', () {
    final route = orderDayRoute(shuffled, origin: hotel, endNearOrigin: true);
    expect(ids(route), ['west', 'midWest', 'midEast', 'east']);
  });

  test('starts next to the accommodation when asked to', () {
    final route = orderDayRoute(shuffled, origin: hotel, endNearOrigin: false);
    expect(ids(route), ['east', 'midEast', 'midWest', 'west']);
  });

  test('a far-away origin is ignored: the favourite place comes first', () {
    const losAngeles = (lat: 34.0522, lng: -118.2437);
    final route = orderDayRoute([midEast, west, east, midWest],
        origin: losAngeles, endNearOrigin: true);
    expect(route.first.id, 'midEast');
    expect(route.toSet(), shuffled.toSet());
    expect(isOriginNear(losAngeles, shuffled), isFalse);
    expect(isOriginNear(hotel, shuffled), isTrue);
  });

  test('2-opt removes crossings', () {
    // A square visited as a zig-zag by nearest neighbour is untangled.
    const a = RouteStop(id: 'a', lat: 52.50, lng: 13.40);
    const b = RouteStop(id: 'b', lat: 52.50, lng: 13.43);
    const c = RouteStop(id: 'c', lat: 52.52, lng: 13.40);
    const d = RouteStop(id: 'd', lat: 52.52, lng: 13.43);
    final route = orderDayRoute([a, d, b, c]);
    var length = 0.0;
    for (var i = 1; i < route.length; i++) {
      length += legKm(route[i - 1], route[i]);
    }
    // a-b-d-c or a-c-d-b: two short sides and one long side, no diagonal.
    expect(length, lessThan(2 * 2.04 + 2.23 + 0.01));
    expect(route.first.id, 'a');
  });

  test('a group match needs a majority and at least two likes', () {
    expect(GroupSessionModel.matchThreshold(1), 2);
    expect(GroupSessionModel.matchThreshold(2), 2);
    expect(GroupSessionModel.matchThreshold(3), 2);
    expect(GroupSessionModel.matchThreshold(4), 3);
    expect(GroupSessionModel.matchThreshold(5), 3);
    expect(GroupSessionModel.matchThreshold(6), 4);
  });
}
