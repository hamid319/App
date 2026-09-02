import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:swipetrip/core/config/app_config.dart';
import 'package:swipetrip/common/models/place_model.dart';
import 'package:swipetrip/common/models/group_model.dart';
import 'package:swipetrip/features/swipe/data/places_repository.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late bool previousRealPlacesApiSetting;

  setUpAll(() {
    registerFallbackValue(Uri());
    dotenv.loadFromString(envString: 'GOOGLE_PLACES_API_KEY=mock_key');
    previousRealPlacesApiSetting = AppConfig.enableRealPlacesAPI;
    AppConfig.enableRealPlacesAPI = true;
  });

  tearDownAll(() {
    AppConfig.enableRealPlacesAPI = previousRealPlacesApiSetting;
  });

  group('Places API Nearby Search & Caching Stress Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockHttpClient mockHttpClient;
    late PlacesRepository repository;

    final location = GroupLocation(
      countryCode: 'fr',
      countryName: 'France',
      cityId: 'paris',
      cityName: 'Paris',
      lat: 48.8566,
      lng: 2.3522,
    );

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockHttpClient = MockHttpClient();
      repository = PlacesRepository(
        firestore: fakeFirestore,
        httpClient: mockHttpClient,
      );
    });

    group('1. Nearby Search Payload & Headers Verification', () {
      test(
          'Verify that Nearby Search endpoint payload correctly filters by includedTypes and excludedTypes, and uses correct headers',
          () async {
        // Mock responses from client
        when(() => mockHttpClient.post(
                  any(),
                  headers: any(named: 'headers'),
                  body: any(named: 'body'),
                ))
            .thenAnswer(
                (_) async => http.Response(json.encode({'places': []}), 200));

        // Call repo with limit
        await repository.fetchAndCachePlacesForCity(location, limit: 10);

        // Verify POST call
        final capturedCall = verify(() => mockHttpClient.post(
              captureAny(),
              headers: captureAny(named: 'headers'),
              body: captureAny(named: 'body'),
            )).captured;

        final Uri uri = capturedCall[0] as Uri;
        final Map<String, String> headers =
            capturedCall[1] as Map<String, String>;
        final String bodyString = capturedCall[2] as String;
        final Map<String, dynamic> body = json.decode(bodyString);

        // Assert URL
        expect(uri.toString(),
            equals('https://places.googleapis.com/v1/places:searchNearby'));

        // Assert Headers
        expect(headers['Content-Type'], equals('application/json'));
        expect(headers['X-Goog-Api-Key'], isNotEmpty);
        expect(
          headers['X-Goog-FieldMask'],
          equals(
              'places.id,places.displayName,places.location,places.photos,places.types,places.formattedAddress'),
        );

        // Assert Payload Types Filters
        final List<dynamic> includedTypes = body['includedTypes'];
        final List<dynamic> excludedTypes = body['excludedTypes'];

        expect(
            includedTypes,
            containsAll([
              'tourist_attraction',
              'museum',
              'church',
              'art_gallery',
              'historical_landmark',
              'cultural_landmark',
              'monument',
              'national_park',
              'sculpture',
            ]));

        // Table B types would make Nearby Search (New) reject the request.
        expect(includedTypes, isNot(contains('landmark')));
        expect(excludedTypes, isNot(contains('food')));

        expect(
            excludedTypes,
            containsAll([
              'restaurant',
              'cafe',
              'bar',
            ]));

        // Assert Location Restriction
        expect(body['locationRestriction']['circle']['center']['latitude'],
            equals(48.8566));
        expect(body['locationRestriction']['circle']['center']['longitude'],
            equals(2.3522));
        expect(
            body['locationRestriction']['circle']['radius'], equals(15000.0));
      });
    });

    group('2. Firestore Caching Limits & Performance Verification', () {
      test(
          'Verify that Firestore caching correctly limits the documents read from Firestore based on the requested limit',
          () async {
        // Pre-populate Firestore with more documents than the requested limit
        final totalCachedDocs = 50;
        final requestedLimit = 15;

        for (int i = 0; i < totalCachedDocs; i++) {
          final place = PlaceModel(
            id: 'place_$i',
            name: 'Place $i',
            lat: 48.8584,
            lng: 2.2945,
            cityId: 'fr_paris',
          );
          await fakeFirestore
              .collection('places')
              .doc(place.id)
              .set(place.toJson());
        }

        // Under fake_cloud_firestore, we don't have a direct query reads counter, but we can verify
        // that fetchAndCachePlacesForCity returns exactly the requestedLimit of places from the cache,
        // and mockHttpClient is never called (proving it was a cache hit and did not trigger extra API calls).
        final places = await repository.fetchAndCachePlacesForCity(location,
            limit: requestedLimit);

        expect(places.length, equals(requestedLimit));
        verifyNever(() => mockHttpClient.post(any(),
            headers: any(named: 'headers'), body: any(named: 'body')));
      });

      test('Verify that cache hits do not trigger extra API calls', () async {
        // First populate cache with exactly the limit
        final limit = 5;
        for (int i = 0; i < limit; i++) {
          final place = PlaceModel(
            id: 'cached_place_$i',
            name: 'Cached Place $i',
            lat: 48.8584,
            lng: 2.2945,
            cityId: 'fr_paris',
          );
          await fakeFirestore
              .collection('places')
              .doc(place.id)
              .set(place.toJson());
        }

        // Call the repository with limit 5 (Cache Hit)
        final places =
            await repository.fetchAndCachePlacesForCity(location, limit: limit);
        expect(places.length, equals(limit));

        // Verify that the HTTP client was NEVER called
        verifyNever(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ));
      });

      test(
          'Verify that cache misses (insufficient docs) correctly trigger API call and update Firestore',
          () async {
        // Pre-populate with fewer documents (2) than the requested limit (5)
        final initialCached = 2;
        final requestedLimit = 5;

        for (int i = 0; i < initialCached; i++) {
          final place = PlaceModel(
            id: 'place_$i',
            name: 'Place $i',
            lat: 48.8584,
            lng: 2.2945,
            cityId: 'fr_paris',
          );
          await fakeFirestore
              .collection('places')
              .doc(place.id)
              .set(place.toJson());
        }

        // Mock API response returning new places
        final mockApiResponse = {
          'places': List.generate(
              requestedLimit,
              (index) => {
                    'id': 'api_place_$index',
                    'displayName': {'text': 'API Place $index'},
                    'location': {'latitude': 48.8584, 'longitude': 2.2945},
                  })
        };

        when(() => mockHttpClient.post(
                  any(),
                  headers: any(named: 'headers'),
                  body: any(named: 'body'),
                ))
            .thenAnswer(
                (_) async => http.Response(json.encode(mockApiResponse), 200));

        // Call repo with limit 5
        final result = await repository.fetchAndCachePlacesForCity(location,
            limit: requestedLimit);

        // Verify HTTP API call was made exactly once
        verify(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).called(1);

        // Verify result has the elements fetched from API
        expect(result.length, equals(requestedLimit));
        expect(result[0].id, equals('api_place_0'));

        // Verify they were written to Firestore
        for (int index = 0; index < requestedLimit; index++) {
          final cachedDoc = await fakeFirestore
              .collection('places')
              .doc('api_place_$index')
              .get();
          expect(cachedDoc.exists, isTrue);
          expect(cachedDoc.data()?['cityId'], equals('fr_paris'));
        }
      });
    });

    group('3. Stress/Robustness Cases', () {
      test(
          'Verify that fetchAndCachePlacesForCity handles very large requested limits (e.g. 1000)',
          () async {
        final mockApiResponse = {
          'places': List.generate(
              100,
              (index) => {
                    'id': 'api_place_$index',
                    'displayName': {'text': 'API Place $index'},
                    'location': {'latitude': 48.8584, 'longitude': 2.2945},
                  })
        };

        when(() => mockHttpClient.post(
                  any(),
                  headers: any(named: 'headers'),
                  body: any(named: 'body'),
                ))
            .thenAnswer(
                (_) async => http.Response(json.encode(mockApiResponse), 200));

        // Call repository with high limit
        final result =
            await repository.fetchAndCachePlacesForCity(location, limit: 1000);

        // Verify request payload limits
        final capturedCall = verify(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: captureAny(named: 'body'),
            )).captured;

        final Map<String, dynamic> body =
            json.decode(capturedCall[0] as String);
        expect(body['maxResultCount'], equals(AppConfig.maxPlacesLimit));
        expect(body['maxResultCount'], equals(20));
        expect(result.length, lessThanOrEqualTo(20));
      });

      for (final requestedLimit in <int>[1, 20, 21, 1000]) {
        test('clamps request and response for limit $requestedLimit', () async {
          final mockApiResponse = {
            'places': List.generate(
              30,
              (index) => {
                'id': 'bounded_place_$index',
                'displayName': {'text': 'Bounded Place $index'},
                'location': {'latitude': 48.8584, 'longitude': 2.2945},
              },
            ),
          };
          when(() => mockHttpClient.post(
                any(),
                headers: any(named: 'headers'),
                body: any(named: 'body'),
              )).thenAnswer(
            (_) async => http.Response(json.encode(mockApiResponse), 200),
          );

          final result = await repository.fetchAndCachePlacesForCity(
            location,
            limit: requestedLimit,
          );
          final captured = verify(() => mockHttpClient.post(
                any(),
                headers: any(named: 'headers'),
                body: captureAny(named: 'body'),
              )).captured;
          final body = json.decode(captured.single as String);
          final expectedLimit = requestedLimit.clamp(1, 20);

          expect(body['maxResultCount'], expectedLimit);
          expect(result.length, lessThanOrEqualTo(expectedLimit));
        });
      }

      test('Verify behavior with negative or zero limit', () async {
        // Set mock API response
        when(() => mockHttpClient.post(
                  any(),
                  headers: any(named: 'headers'),
                  body: any(named: 'body'),
                ))
            .thenAnswer(
                (_) async => http.Response(json.encode({'places': []}), 200));

        // Zero limit: should query firestore with limit 0, and if it's 0 (which is >= 0), return empty
        final resultZero =
            await repository.fetchAndCachePlacesForCity(location, limit: 0);
        expect(resultZero, isEmpty);
        verifyNever(() => mockHttpClient.post(any(),
            headers: any(named: 'headers'), body: any(named: 'body')));
      });
    });
  });
}
