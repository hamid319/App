// Firestore mocks implement its sealed query classes, as test doubles do.
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipetrip/features/swipe/data/places_repository.dart';

class _MockDb extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class _MockSnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class _MockDoc extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

class _MockMetadata extends Mock implements SnapshotMetadata {}

_MockSnapshot _snapshot(int count, {bool fromCache = false}) {
  final meta = _MockMetadata();
  when(() => meta.isFromCache).thenReturn(fromCache);
  final docs = <_MockDoc>[];
  for (var i = 0; i < count; i++) {
    final doc = _MockDoc();
    when(() => doc.data())
        .thenReturn({'id': 'p$i', 'name': 'p$i', 'lat': 0.0, 'lng': 0.0});
    docs.add(doc);
  }
  final snap = _MockSnapshot();
  when(() => snap.metadata).thenReturn(meta);
  when(() => snap.docs).thenReturn(docs);
  return snap;
}

void main() {
  late _MockQuery query;
  late PlacesRepository repo;

  setUpAll(() => registerFallbackValue(const GetOptions()));

  setUp(() {
    final db = _MockDb();
    final places = _MockCollection();
    query = _MockQuery();
    when(() => db.collection('places')).thenReturn(places);
    when(() => places.where(any(), isEqualTo: any(named: 'isEqualTo')))
        .thenReturn(query);
    when(() => query.where(any(), isEqualTo: any(named: 'isEqualTo')))
        .thenReturn(query);
    when(() => query.orderBy(any(), descending: any(named: 'descending')))
        .thenReturn(query);
    when(() => query.limit(any())).thenReturn(query);
    repo = PlacesRepository(firestore: db);
  });

  String stamp(Duration age, int count) =>
      '${DateTime.now().subtract(age).millisecondsSinceEpoch}|$count';

  void prefs(String? value) => SharedPreferences.setMockInitialValues({
        if (value != null) 'places.de_berlin.150': value.split('|'),
      });

  bool server(Invocation i) =>
      i.positionalArguments.isEmpty ||
      (i.positionalArguments.first as GetOptions?)?.source != Source.cache;

  void answer({required int cache, required int fromServer}) {
    final onDevice = _snapshot(cache, fromCache: true);
    final online = _snapshot(fromServer);
    when(() => query.get(any()))
        .thenAnswer((i) async => server(i) ? online : onDevice);
  }

  int serverCalls() => verify(() => query.get(captureAny()))
      .captured
      .where((o) => (o as GetOptions?)?.source != Source.cache)
      .length;

  test('a fresh device copy answers without the server', () async {
    prefs(stamp(const Duration(hours: 2), 3));
    answer(cache: 3, fromServer: 5);
    expect(await repo.loadCityPlaces('de_berlin'), hasLength(3));
    expect(serverCalls(), 0);
  });

  test('an old device copy is refreshed from the server', () async {
    prefs(stamp(const Duration(hours: 30), 3));
    answer(cache: 3, fromServer: 5);
    expect(await repo.loadCityPlaces('de_berlin'), hasLength(5));
    final saved = (await SharedPreferences.getInstance())
        .getStringList('places.de_berlin.150');
    expect(saved?.last, '5');
  });

  test('a device copy with places missing is not used', () async {
    prefs(stamp(const Duration(hours: 2), 5));
    answer(cache: 3, fromServer: 5);
    expect(await repo.loadCityPlaces('de_berlin'), hasLength(5));
  });

  test('pull to refresh asks the server', () async {
    prefs(stamp(const Duration(hours: 2), 3));
    answer(cache: 3, fromServer: 5);
    repo.clearCityCache();
    expect(await repo.loadCityPlaces('de_berlin'), hasLength(5));
  });

  test('the first load asks the server', () async {
    prefs(null);
    answer(cache: 0, fromServer: 5);
    expect(await repo.loadCityPlaces('de_berlin'), hasLength(5));
    expect(serverCalls(), 1);
  });

  test('a loaded city answers a shorter list without a query', () async {
    prefs(null);
    answer(cache: 0, fromServer: 5);
    await repo.loadCityPlaces('de_berlin');
    expect(await repo.loadCityPlaces('de_berlin', limit: 3), hasLength(3));
    expect(serverCalls(), 1);
  });
}
