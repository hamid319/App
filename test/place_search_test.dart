import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/common/models/place_search_entry.dart';
import 'package:swipetrip/features/home/logic/place_search_controller.dart';

void main() {
  const entries = [
    PlaceSearchEntry(id: 'a', name: 'Museum of Hamburg History'),
    PlaceSearchEntry(
        id: 'b', name: 'Hamburg Town Hall', nameDe: 'Hamburger Rathaus'),
    PlaceSearchEntry(id: 'c', name: 'Café Paris', isVenue: true),
    PlaceSearchEntry(id: 'd', name: 'Elbphilharmonie'),
  ];

  List<String> ids(String q) =>
      searchPlaces(entries, q).map((e) => e.id).toList();

  test('prefix first, then word start, keeping index order', () {
    expect(ids('hamburg'), ['b', 'a']);
  });

  test('matches German names, accents and all words in any order', () {
    expect(ids('rathaus'), ['b']);
    expect(ids('cafe'), ['c']);
    expect(ids('paris CAFÉ'), ['c']);
  });

  test('empty or unmatched query gives nothing', () {
    expect(ids('  '), isEmpty);
    expect(ids('louvre'), isEmpty);
  });
}
