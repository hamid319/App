# Testing Patterns

**Analysis Date:** 2026-07-04

## Test Framework

**Runner:**
- Flutter test runner from `flutter_test`.
- Config: Not detected. There is no `flutter_test_config.dart`, `dart_test.yaml`, or custom test runner config.
- Dependency source: `flutter_test` in `pubspec.yaml`.

**Assertion Library:**
- `flutter_test` matchers and expectations. Examples: `expect(..., equals(...))`, `expect(..., isEmpty)`, `expect(..., throwsException)`, `expect(..., throwsA(isA<FormatException>()))` in `test/places_api_migration_test.dart`.
- `mocktail` for mock HTTP calls, call verification, argument capture, and fallback values. Dependency: `mocktail: ^1.0.4` in `pubspec.yaml`.
- `fake_cloud_firestore` for in-memory Firestore behavior. Dependency: `fake_cloud_firestore: ^4.1.0+1` in `pubspec.yaml`.

**Run Commands:**
```bash
flutter pub get                              # Install dependencies after pubspec changes
flutter analyze                              # Required verification after source changes
flutter test                                 # Run all tests
flutter test test/places_api_migration_test.dart
flutter test test/places_api_stress_test.dart
flutter test --coverage                      # Generate coverage/lcov.info
```

## Test File Organization

**Location:**
- Tests are under root `test/`.
- No `integration_test/` directory detected.
- No `test_driver/` directory detected.
- No dedicated `mocks/`, `fixtures/`, or `helpers/` test support directory detected.

**Naming:**
- Use `_test.dart` suffix.
- Current test files:
  - `test/places_api_migration_test.dart`
  - `test/places_api_stress_test.dart`
  - `test/widget_test.dart`

**Structure:**
```text
test/
├── places_api_migration_test.dart  # Repository-level Google Places API migration and caching tests
├── places_api_stress_test.dart     # Repository-level payload, cache, limit, and robustness tests
└── widget_test.dart                # Minimal app smoke widget test
```

## Test Structure

**Suite Organization:**
```dart
class MockHttpClient extends Mock implements http.Client {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri());
    dotenv.loadFromString(envString: 'GOOGLE_PLACES_API_KEY=mock_key');
    AppConfig.enableRealPlacesAPI = true;
  });

  group('Places API (New) Migration Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockHttpClient mockHttpClient;
    late PlacesRepository repository;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockHttpClient = MockHttpClient();
      repository = PlacesRepository(
        firestore: fakeFirestore,
        httpClient: mockHttpClient,
      );
    });

    test('Verify HTTP request payload...', () async {
      when(() => mockHttpClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer((_) async => http.Response(json.encode({'places': []}), 200));

      await repository.fetchAndCachePlacesForCity(location, limit: 5);

      final capturedCall = verify(() => mockHttpClient.post(
        captureAny(),
        headers: captureAny(named: 'headers'),
        body: captureAny(named: 'body'),
      )).captured;

      expect(capturedCall, isNotEmpty);
    });
  });
}
```

**Patterns:**
- Put mock classes at the top of the test file. Example: `MockHttpClient` in `test/places_api_migration_test.dart` and `test/places_api_stress_test.dart`.
- Use `setUpAll` for one-time global setup such as `registerFallbackValue(Uri())`, fake dotenv loading, and enabling API behavior through `AppConfig.enableRealPlacesAPI`.
- Use `setUp` for per-test fresh fakes and repository instances.
- Group tests by behavior tier or concern. Examples: `Tier 1: Feature Coverage`, `Tier 2: Boundary & Corner Cases`, and `Tier 3: Cross-Feature Combinations` in `test/places_api_migration_test.dart`.
- Use explicit, behavior-focused test names. Current names are long and descriptive; preserve that clarity for new tests.
- Prefer repository constructor injection for testability. Existing target: `PlacesRepository({FirebaseFirestore? firestore, http.Client? httpClient})` in `lib/features/swipe/data/places_repository.dart`.
- Use real domain models as test data. Examples: `PlaceModel` and `GroupLocation` are constructed directly in `test/places_api_migration_test.dart`.

## Mocking

**Framework:** `mocktail`

**Patterns:**
```dart
class MockHttpClient extends Mock implements http.Client {}

setUpAll(() {
  registerFallbackValue(Uri());
});

when(() => mockHttpClient.post(
  any(),
  headers: any(named: 'headers'),
  body: any(named: 'body'),
)).thenAnswer((_) async => http.Response(json.encode(mockResponse), 200));

verify(() => mockHttpClient.post(
  captureAny(),
  headers: captureAny(named: 'headers'),
  body: captureAny(named: 'body'),
)).captured;

verifyNever(() => mockHttpClient.post(
  any(),
  headers: any(named: 'headers'),
  body: any(named: 'body'),
));
```

**What to Mock:**
- Mock external HTTP clients and network boundaries. Existing examples mock `http.Client.post` in `test/places_api_migration_test.dart` and `test/places_api_stress_test.dart`.
- Mock or fake external service responses when the production code would call Google Places API, Firebase, device location, image picker, storage, or shared preferences.
- Prefer fake implementations for Firestore data behavior when available. Existing tests use `FakeFirebaseFirestore`.
- Use `dotenv.loadFromString` for env-dependent tests. Existing tests load `GOOGLE_PLACES_API_KEY=mock_key` without reading `.env`.

**What NOT to Mock:**
- Do not mock app model serialization for repository tests; use real `PlaceModel.fromJson`, `PlaceModel.toJson`, and `GroupLocation` values to catch contract drift.
- Do not mock Firestore with ad hoc maps when `fake_cloud_firestore` can exercise the repository query/write behavior.
- Do not hit real Google Places API in unit tests. Keep `AppConfig.enableRealPlacesAPI` controlled in test setup and inject a mock HTTP client.
- Do not read real `.env` secrets from tests. Use `dotenv.loadFromString` with safe dummy values.

## Fixtures and Factories

**Test Data:**
```dart
final location = GroupLocation(
  countryCode: 'fr',
  countryName: 'France',
  cityId: 'paris',
  cityName: 'Paris',
  lat: 48.8566,
  lng: 2.3522,
);

final place = PlaceModel(
  id: 'cached_place_0',
  name: 'Cached Place 0',
  lat: 48.8584,
  lng: 2.2945,
  cityId: 'fr_paris',
);

await fakeFirestore.collection('places').doc(place.id).set(place.toJson());
```

**Location:**
- Fixtures are inline inside each test file.
- No shared fixture/factory directory detected.
- If repeated data grows, add helper functions near the test file first, then promote shared builders to a `test/helpers/` or `test/fixtures/` directory if multiple test files need them.

## Coverage

**Requirements:** No enforced project coverage threshold detected in config.
- sets a workflow expectation of 80%+ coverage for new development.
- `TEST_READY.md` documents Places API migration coverage with 9 listed checks.
- No CI coverage gate, `lcov.info`, or coverage thresholds were detected.

**View Coverage:**
```bash
flutter test --coverage
```

## Test Types

**Unit Tests:**
- Current unit-style tests cover model parsing/serialization, request payload formation, API response handling, cache hits/misses, city isolation, limit clamping, and invalid JSON behavior.
- Main files: `test/places_api_migration_test.dart`, `test/places_api_stress_test.dart`.
- Add new pure model tests next to the affected model behavior under `test/{feature_or_contract}_test.dart`.

**Integration Tests:**
- Current repository tests are lightweight integration tests against `FakeFirebaseFirestore` and a mocked HTTP client.
- These tests verify Firestore reads/writes and repository behavior without real Firebase or Google API calls.
- Add repository integration tests for Firestore transaction logic in `lib/features/group/data/group_repository.dart` using `fake_cloud_firestore` where supported.

**Widget Tests:**
- Current widget test: `test/widget_test.dart`.
- It wraps `MobileApp` in `ProviderScope` and asserts `MaterialApp` is present.
- For provider-dependent widgets, wrap the widget in `ProviderScope` and override providers as needed. No provider override examples are currently present in the repo.

**E2E Tests:**
- Framework: Not used.
- No `integration_test/` directory, Patrol config, Maestro config, Appium config, or Flutter driver setup detected.
- expects E2E coverage for critical workflows when implementing new features, but the current repo does not include E2E infrastructure.

## Common Patterns

**Async Testing:**
```dart
when(() => mockHttpClient.post(
  any(),
  headers: any(named: 'headers'),
  body: any(named: 'body'),
)).thenAnswer((_) async => http.Response(json.encode(mockResponse), 200));

final places = await repository.fetchAndCachePlacesForCity(location, limit: 1);

expect(places.length, equals(1));
```

**Error Testing:**
```dart
when(() => mockHttpClient.post(
  any(),
  headers: any(named: 'headers'),
  body: any(named: 'body'),
)).thenAnswer((_) async => http.Response('API Key Invalid', 400));

expect(
  () => repository.fetchAndCachePlacesForCity(location, limit: 10),
  throwsException,
);

when(() => mockHttpClient.post(
  any(),
  headers: any(named: 'headers'),
  body: any(named: 'body'),
)).thenAnswer((_) async => http.Response('{invalid json}', 200));

expect(
  () => repository.fetchAndCachePlacesForCity(location, limit: 10),
  throwsA(isA<FormatException>()),
);
```

**Cache Testing:**
```dart
await fakeFirestore.collection('places').doc(place.id).set(place.toJson());

final places = await repository.fetchAndCachePlacesForCity(location, limit: 1);

expect(places.length, equals(1));
verifyNever(() => mockHttpClient.post(
  any(),
  headers: any(named: 'headers'),
  body: any(named: 'body'),
));
```

**Widget Smoke Testing:**
```dart
testWidgets('App starts correctly', (WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(
      child: MobileApp(),
    ),
  );

  expect(find.byType(MaterialApp), findsOneWidget);
});
```

## Verification Workflow

**After code changes:**
- Run `flutter analyze` and fix all analyzer errors before continuing. This is required by `AGENTS.md`, `CLAUDE.md`, `.agents/skills/flutter-bug-fixer/SKILL.md`, `.agents/skills/flutter-feature-builder/SKILL.md`, and `.agents/skills/flutter-refactor/SKILL.md`.
- Run the relevant targeted test first, then `flutter test` for broad regression coverage.
- If dependencies change, run `flutter pub get` before analysis/tests.
- When UI changes are made, project skills expect hot reload via Dart MCP and visual verification with screenshots.

**Documentation-only changes:**
- No app verification command is required for `.planning/codebase/*.md` updates, but line counts should be checked after writing mapper documents.

## CI/CD Testing

**CI Config:** Not detected.
- No `.github/workflows/`, `.gitlab-ci.yml`, `.circleci/`, or `codemagic.yaml` was detected.
- Testing appears to be local-command driven.

**Recommended local gate for source changes:**
```bash
flutter pub get
flutter analyze
flutter test
flutter test --coverage
```

## Gaps to Preserve in Future Plans

**Provider/controller tests:**
- No tests currently cover `AuthController`, `GroupController`, `SwipeController`, or `ProfileController`.
- Add `ProviderContainer` or `ProviderScope(overrides: ...)` tests when controller behavior changes.

**Firestore transaction tests:**
- `lib/features/group/data/group_repository.dart` contains critical group/session transaction logic, but no direct test file targets it.
- Add focused tests for invite joins, duplicate votes, progress increments, session completion, and `userSwipes` writes.

**UI workflow tests:**
- `test/widget_test.dart` is only a smoke test.
- Add widget tests for login/register validation, group creation/join flows, swipe actions, favorites behavior, and settings/profile actions when those screens change.

**Env/config tests:**
- `lib/core/config/env.dart` and `lib/core/config/app_config.dart` influence Google Places behavior.
- Keep tests using safe env strings and avoid reading `.env`.

---

*Testing analysis: 2026-07-04*
