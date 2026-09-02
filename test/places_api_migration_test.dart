import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
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

  group('Places API (New) Migration Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockHttpClient mockHttpClient;
    late PlacesRepository repository;

    setUp(() {
      dotenv.loadFromString(envString: 'GOOGLE_PLACES_API_KEY=mock_key');
      fakeFirestore = FakeFirebaseFirestore();
      mockHttpClient = MockHttpClient();
      repository = PlacesRepository(
        firestore: fakeFirestore,
        httpClient: mockHttpClient,
      );
    });

    group('Tier 1: Feature Coverage', () {
      test(
          'TestCase 1.1: Verify PlaceModel parses and serializes cityId field correctly',
          () {
        final json = {
          'id': 'ChIJN1t_tDeuEmsRUsoyG83frY4',
          'name': 'Eiffel Tower',
          'description': 'A historic tower',
          'lat': 48.8584,
          'lng': 2.2945,
          'address': 'Paris, France',
          'imageUrls': ['https://places.googleapis.com/v1/places/123/media'],
          'averageRating': 4.7,
          'types': ['tourist_attraction'],
          'cityId': 'fr_paris',
        };

        final place = PlaceModel.fromJson(json);
        // Expect cityId to be parsed correctly
        expect(place.cityId, equals('fr_paris'));

        final serialized = place.toJson();
        expect(serialized['cityId'], equals('fr_paris'));
      });

      test(
          'TestCase 1.2: Verify PlacesRepository stores stable photo resource names',
          () async {
        final location = GroupLocation(
          countryCode: 'fr',
          countryName: 'France',
          cityId: 'paris',
          cityName: 'Paris',
          lat: 48.8566,
          lng: 2.3522,
        );

        final mockResponse = {
          'places': [
            {
              'id': 'ChIJN1t_tDeuEmsRUsoyG83frY4',
              'displayName': {'text': 'Eiffel Tower'},
              'location': {'latitude': 48.8584, 'longitude': 2.2945},
              'formattedAddress': 'Paris, France',
              'photos': [
                {'name': 'places/ChIJN1t_tDeuEmsRUsoyG83frY4/photos/photo123'}
              ],
              'types': ['tourist_attraction'],
            }
          ]
        };

        when(() => mockHttpClient.post(
                  any(),
                  headers: any(named: 'headers'),
                  body: any(named: 'body'),
                ))
            .thenAnswer(
                (_) async => http.Response(json.encode(mockResponse), 200));

        final places =
            await repository.fetchAndCachePlacesForCity(location, limit: 1);
        expect(places.length, equals(1));
        expect(
          places[0].photoResourceNames.single,
          equals('places/ChIJN1t_tDeuEmsRUsoyG83frY4/photos/photo123'),
        );
        final cached = await fakeFirestore
            .collection('places')
            .doc('ChIJN1t_tDeuEmsRUsoyG83frY4')
            .get();
        expect(cached.data().toString(), isNot(contains('key=')));
      });

      test(
          'TestCase 1.3: Verify PlacesRepository.getPlaceById and loadNearbyPlaces do not use useMock flags',
          () async {
        // Calling getPlaceById and loadNearbyPlaces without useMock parameter.
        // Once useMock parameter is removed, this compile-time test ensures we do not pass it.
        final place =
            await repository.getPlaceById('ChIJN1t_tDeuEmsRUsoyG83frY4');
        final nearbyPlaces = await repository.loadNearbyPlaces(48.8566, 2.3522);

        expect(place, isNull);
        expect(nearbyPlaces, isEmpty);
      });

      test(
          'TestCase 1.4: Verify HTTP request payload of fetchAndCachePlacesForCity matches Nearby Search (New) requirements',
          () async {
        final location = GroupLocation(
          countryCode: 'fr',
          countryName: 'France',
          cityId: 'paris',
          cityName: 'Paris',
          lat: 48.8566,
          lng: 2.3522,
        );

        when(() => mockHttpClient.post(
                  any(),
                  headers: any(named: 'headers'),
                  body: any(named: 'body'),
                ))
            .thenAnswer(
                (_) async => http.Response(json.encode({'places': []}), 200));

        await repository.fetchAndCachePlacesForCity(location, limit: 5);

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

        expect(uri.toString(),
            equals('https://places.googleapis.com/v1/places:searchNearby'));
        expect(
            headers['X-Goog-FieldMask'],
            equals(
                'places.id,places.displayName,places.location,places.photos,places.types,places.formattedAddress'));
        expect(body['maxResultCount'], equals(5));
        expect(body['locationRestriction']['circle']['center']['latitude'],
            equals(48.8566));
        expect(body['locationRestriction']['circle']['center']['longitude'],
            equals(2.3522));
        expect(body['includedTypes'], contains('tourist_attraction'));
        expect(body['excludedTypes'], contains('restaurant'));
      });
    });

    group('Gemini summary behavior', () {
      final location = GroupLocation(
        countryCode: 'fr',
        countryName: 'France',
        cityId: 'paris',
        cityName: 'Paris',
        lat: 48.8566,
        lng: 2.3522,
      );

      String placesResponse(String id, String name) => json.encode({
            'places': [
              {
                'id': id,
                'displayName': {'text': name},
                'location': {'latitude': 48.8584, 'longitude': 2.2945},
                'formattedAddress': 'Paris, France',
                'types': ['tourist_attraction'],
              }
            ]
          });

      setUp(() {
        dotenv.loadFromString(
          envString:
              'GOOGLE_PLACES_API_KEY=mock_key\nGEMINI_API_KEY=mock_gemini_key',
        );
      });

      test(
          'stores a successful Gemini description in the returned place and cache',
          () async {
        final client = http_testing.MockClient((request) async {
          if (request.url.host == 'places.googleapis.com') {
            return http.Response(
                placesResponse('eiffel_tower', 'Eiffel Tower'), 200);
          }
          return http.Response(
            json.encode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'An iconic iron landmark overlooking Paris.'}
                    ]
                  }
                }
              ]
            }),
            200,
          );
        });
        repository = PlacesRepository(
          firestore: fakeFirestore,
          httpClient: client,
        );

        final places =
            await repository.fetchAndCachePlacesForCity(location, limit: 1);

        expect(places.single.description,
            'An iconic iron landmark overlooking Paris.');
        final cached =
            await fakeFirestore.collection('places').doc('eiffel_tower').get();
        expect(cached.data()?['description'],
            'An iconic iron landmark overlooking Paris.');
      });

      test('keeps the place usable when Gemini returns a non-200 response',
          () async {
        final client = http_testing.MockClient((request) async {
          if (request.url.host == 'places.googleapis.com') {
            return http.Response(
                placesResponse('louvre', 'Louvre Museum'), 200);
          }
          return http.Response('quota exceeded', 429);
        });
        repository = PlacesRepository(
          firestore: fakeFirestore,
          httpClient: client,
        );

        final places =
            await repository.fetchAndCachePlacesForCity(location, limit: 1);

        expect(places.single.id, 'louvre');
        expect(places.single.description, isNull);
      });

      test('keeps the place usable when Gemini returns malformed JSON',
          () async {
        final client = http_testing.MockClient((request) async {
          if (request.url.host == 'places.googleapis.com') {
            return http.Response(
                placesResponse('arc_de_triomphe', 'Arc de Triomphe'), 200);
          }
          return http.Response('{not-json', 200);
        });
        repository = PlacesRepository(
          firestore: fakeFirestore,
          httpClient: client,
        );

        final places =
            await repository.fetchAndCachePlacesForCity(location, limit: 1);

        expect(places.single.id, 'arc_de_triomphe');
        expect(places.single.description, isNull);
      });

      test('keeps the place usable when the Gemini request throws', () async {
        final client = http_testing.MockClient((request) async {
          if (request.url.host == 'places.googleapis.com') {
            return http.Response(
                placesResponse('notre_dame', 'Notre-Dame'), 200);
          }
          throw http.ClientException('offline');
        });
        repository = PlacesRepository(
          firestore: fakeFirestore,
          httpClient: client,
        );

        final places =
            await repository.fetchAndCachePlacesForCity(location, limit: 1);

        expect(places.single.id, 'notre_dame');
        expect(places.single.description, isNull);
      });

      test('uses the configured Gemini model without exposing the key',
          () async {
        dotenv.loadFromString(
          envString: '''
GOOGLE_PLACES_API_KEY=places-value
GEMINI_API_KEY=gemini-value
GEMINI_MODEL=configured-model
''',
        );
        Uri? geminiUri;
        final client = http_testing.MockClient((request) async {
          if (request.url.host == 'places.googleapis.com') {
            return http.Response(
              placesResponse('model_place', 'Model Place'),
              200,
            );
          }
          geminiUri = request.url;
          return http.Response('{}', 503);
        });
        repository = PlacesRepository(
          firestore: fakeFirestore,
          httpClient: client,
        );

        final places =
            await repository.fetchAndCachePlacesForCity(location, limit: 1);

        expect(places.single.id, 'model_place');
        expect(geminiUri?.path, contains('/models/configured-model:'));
        expect(geminiUri.toString(), isNot(contains('gemini-value')));
      });
    });

    group('Tier 2: Boundary & Corner Cases', () {
      test(
          'TestCase 2.1: Verify PlacesRepository.fetchAndCachePlacesForCity handles empty/null fields in API responses',
          () async {
        final location = GroupLocation(
          countryCode: 'fr',
          countryName: 'France',
          cityId: 'paris',
          cityName: 'Paris',
          lat: 48.8566,
          lng: 2.3522,
        );

        final mockResponse = {
          'places': [
            {
              'id': 'ChIJN1t_tDeuEmsRUsoyG83frY4',
              'displayName': {'text': null},
              'location': {'latitude': 48.8584, 'longitude': 2.2945},
            }
          ]
        };

        when(() => mockHttpClient.post(
                  any(),
                  headers: any(named: 'headers'),
                  body: any(named: 'body'),
                ))
            .thenAnswer(
                (_) async => http.Response(json.encode(mockResponse), 200));

        final places =
            await repository.fetchAndCachePlacesForCity(location, limit: 1);
        expect(places.length, equals(1));
        expect(places[0].name, equals('Unknown'));
        expect(places[0].address, isNull);
        expect(places[0].imageUrls, isEmpty);
        expect(places[0].types, isEmpty);
      });

      test(
          'TestCase 2.2: Verify PlacesRepository.fetchAndCachePlacesForCity handles API non-200 HTTP response codes',
          () async {
        final location = GroupLocation(
          countryCode: 'fr',
          countryName: 'France',
          cityId: 'paris',
          cityName: 'Paris',
          lat: 48.8566,
          lng: 2.3522,
        );

        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => http.Response('API Key Invalid', 400));

        await expectLater(
          repository.fetchAndCachePlacesForCity(location, limit: 10),
          throwsA(
            isA<Exception>()
                .having((error) => error.toString(), 'message',
                    isNot(contains('API Key Invalid')))
                .having((error) => error.toString(), 'message',
                    isNot(contains('mock_key'))),
          ),
        );
      });

      test(
          'TestCase 2.4: Verify PlacesRepository.fetchAndCachePlacesForCity handles empty or missing places key in the response',
          () async {
        final location = GroupLocation(
          countryCode: 'fr',
          countryName: 'France',
          cityId: 'paris',
          cityName: 'Paris',
          lat: 48.8566,
          lng: 2.3522,
        );

        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => http.Response(json.encode({}), 200));

        final places =
            await repository.fetchAndCachePlacesForCity(location, limit: 10);
        expect(places, isEmpty);
      });

      test(
          'TestCase 2.5: malformed Nearby JSON errors do not expose the response body',
          () async {
        final location = GroupLocation(
          countryCode: 'fr',
          countryName: 'France',
          cityId: 'paris',
          cityName: 'Paris',
          lat: 48.8566,
          lng: 2.3522,
        );

        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => http.Response('{invalid json}', 200));

        await expectLater(
          repository.fetchAndCachePlacesForCity(location, limit: 10),
          throwsA(
            isA<FormatException>().having(
              (error) => error.toString(),
              'message',
              isNot(contains('{invalid json}')),
            ),
          ),
        );
      });

      test(
          'TestCase 2.6: Verify cache check only calls API when cached document count is less than the requested limit',
          () async {
        final location = GroupLocation(
          countryCode: 'fr',
          countryName: 'France',
          cityId: 'paris',
          cityName: 'Paris',
          lat: 48.8566,
          lng: 2.3522,
        );

        for (int i = 0; i < 3; i++) {
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

        final placesA =
            await repository.fetchAndCachePlacesForCity(location, limit: 3);
        expect(placesA.length, equals(3));
        verifyNever(() => mockHttpClient.post(any(),
            headers: any(named: 'headers'), body: any(named: 'body')));

        final mockResponse = {
          'places': [
            {
              'id': 'api_place_1',
              'displayName': {'text': 'API Place 1'},
              'location': {'latitude': 48.8584, 'longitude': 2.2945},
            },
            {
              'id': 'api_place_2',
              'displayName': {'text': 'API Place 2'},
              'location': {'latitude': 48.8584, 'longitude': 2.2945},
            }
          ]
        };

        when(() => mockHttpClient.post(
                  any(),
                  headers: any(named: 'headers'),
                  body: any(named: 'body'),
                ))
            .thenAnswer(
                (_) async => http.Response(json.encode(mockResponse), 200));

        final placesB =
            await repository.fetchAndCachePlacesForCity(location, limit: 5);
        expect(placesB.length, equals(2));
        verify(() => mockHttpClient.post(any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'))).called(1);
      });
    });

    group('Tier 3: Cross-Feature Combinations', () {
      test('does not repeat an exhausted city cache miss', () async {
        final location = GroupLocation(
          countryCode: 'fr',
          countryName: 'France',
          cityId: 'paris',
          cityName: 'Paris',
          lat: 48.8566,
          lng: 2.3522,
        );
        final response = {
          'places': List.generate(
            7,
            (index) => {
              'id': 'short_place_$index',
              'displayName': {'text': 'Short Place $index'},
              'location': {'latitude': 48.8584, 'longitude': 2.2945},
            },
          ),
        };
        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer(
          (_) async => http.Response(json.encode(response), 200),
        );

        final first =
            await repository.fetchAndCachePlacesForCity(location, limit: 20);
        final second =
            await repository.fetchAndCachePlacesForCity(location, limit: 20);

        expect(first, hasLength(7));
        expect(second, hasLength(7));
        verify(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).called(1);
      });

      test('malformed metadata is ignored and remains isolated by city',
          () async {
        await fakeFirestore
            .collection('placeCacheMetadata')
            .doc('fr_paris')
            .set(<String, dynamic>{'isExhausted': 'yes'});
        await fakeFirestore
            .collection('placeCacheMetadata')
            .doc('gb_london')
            .set(<String, dynamic>{
          'cityId': 'gb_london',
          'fetchedCount': 0,
          'requestedLimit': 20,
          'isExhausted': true,
          'lastSyncedAt': DateTime(2026),
          'schemaVersion': 1,
        });
        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer(
          (_) async => http.Response(json.encode({'places': []}), 200),
        );
        final paris = GroupLocation(
          countryCode: 'fr',
          countryName: 'France',
          cityId: 'paris',
          cityName: 'Paris',
          lat: 48.8566,
          lng: 2.3522,
        );

        await repository.fetchAndCachePlacesForCity(paris, limit: 20);

        verify(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).called(1);
      });

      test('API errors do not mark a city cache exhausted', () async {
        final location = GroupLocation(
          countryCode: 'fr',
          countryName: 'France',
          cityId: 'paris',
          cityName: 'Paris',
          lat: 48.8566,
          lng: 2.3522,
        );
        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => http.Response('transient', 503));

        await expectLater(
          repository.fetchAndCachePlacesForCity(location, limit: 20),
          throwsException,
        );
        final metadata = await fakeFirestore
            .collection('placeCacheMetadata')
            .doc('fr_paris')
            .get();

        expect(metadata.exists, isFalse);
      });

      test('non-exhausted metadata does not suppress a cache miss', () async {
        final location = GroupLocation(
          countryCode: 'fr',
          countryName: 'France',
          cityId: 'paris',
          cityName: 'Paris',
          lat: 48.8566,
          lng: 2.3522,
        );
        await fakeFirestore
            .collection('placeCacheMetadata')
            .doc('fr_paris')
            .set(<String, dynamic>{
          'cityId': 'fr_paris',
          'fetchedCount': 0,
          'requestedLimit': 20,
          'isExhausted': false,
          'lastSyncedAt': DateTime(2026),
          'schemaVersion': 1,
        });
        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer(
          (_) async => http.Response(json.encode({'places': []}), 200),
        );

        await repository.fetchAndCachePlacesForCity(location, limit: 20);

        verify(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).called(1);
      });

      test(
          'TestCase 3.1: Verify Cache Hit / Miss Flow - first call calls API and caches; subsequent call reads from cache without API call',
          () async {
        final location = GroupLocation(
          countryCode: 'fr',
          countryName: 'France',
          cityId: 'paris',
          cityName: 'Paris',
          lat: 48.8566,
          lng: 2.3522,
        );

        final mockResponse = {
          'places': [
            {
              'id': 'api_place_1',
              'displayName': {'text': 'API Place 1'},
              'location': {'latitude': 48.8584, 'longitude': 2.2945},
            }
          ]
        };

        when(() => mockHttpClient.post(
                  any(),
                  headers: any(named: 'headers'),
                  body: any(named: 'body'),
                ))
            .thenAnswer(
                (_) async => http.Response(json.encode(mockResponse), 200));

        final placesFirst =
            await repository.fetchAndCachePlacesForCity(location, limit: 1);
        expect(placesFirst.length, equals(1));
        expect(placesFirst[0].id, equals('api_place_1'));

        final doc =
            await fakeFirestore.collection('places').doc('api_place_1').get();
        expect(doc.exists, isTrue);
        expect(doc.data()?['cityId'], equals('fr_paris'));

        clearInteractions(mockHttpClient);

        final placesSecond =
            await repository.fetchAndCachePlacesForCity(location, limit: 1);
        expect(placesSecond.length, equals(1));
        expect(placesSecond[0].id, equals('api_place_1'));

        verifyNever(() => mockHttpClient.post(any(),
            headers: any(named: 'headers'), body: any(named: 'body')));
      });

      test(
          'TestCase 3.2: Verify City Isolation - places cached for one city do not populate queries for another city',
          () async {
        final london = GroupLocation(
          countryCode: 'gb',
          countryName: 'United Kingdom',
          cityId: 'london',
          cityName: 'London',
          lat: 51.5074,
          lng: -0.1278,
        );

        final parisPlace = PlaceModel(
          id: 'paris_place',
          name: 'Paris Place',
          lat: 48.8584,
          lng: 2.2945,
          cityId: 'fr_paris',
        );
        await fakeFirestore
            .collection('places')
            .doc(parisPlace.id)
            .set(parisPlace.toJson());

        final mockResponse = {
          'places': [
            {
              'id': 'london_place',
              'displayName': {'text': 'London Place'},
              'location': {'latitude': 51.5074, 'longitude': -0.1278},
            }
          ]
        };

        when(() => mockHttpClient.post(
                  any(),
                  headers: any(named: 'headers'),
                  body: any(named: 'body'),
                ))
            .thenAnswer(
                (_) async => http.Response(json.encode(mockResponse), 200));

        final londonPlaces =
            await repository.fetchAndCachePlacesForCity(london, limit: 1);
        expect(londonPlaces.length, equals(1));
        expect(londonPlaces[0].id, equals('london_place'));

        verify(() => mockHttpClient.post(any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'))).called(1);
      });
    });
  });
}
