## 2026-06-28T01:44:58Z
You are teamwork_preview_worker. Your working directory is /Users/ozanermis/Desktop/ProjectP/App/App/.agents/worker_milestone2.
Your task is to setup the E2E Test Suite and unit tests in `test/places_api_migration_test.dart` for the Google Places API (New) migration as outlined in `TEST_INFRA.md` and `PLACES_API_MIGRATION.md`.

Please perform the following steps:
1. Update `PlacesRepository` (constructor and fields only) to support dependency injection for `FirebaseFirestore` and `http.Client` so we can write unit/integration tests without using actual network or production Firestore.
2. If helpful, add testing dependencies (like `mocktail` or `fake_cloud_firestore` or `mockito`) to `pubspec.yaml` and run `flutter pub get`.
3. Implement test cases covering Tier 1 (PlaceModel json, new photo URLs, no useMock), Tier 2 (empty/error API response handling, cache limit checks), and Tier 3 (caching flow check, city isolation) from `TEST_INFRA.md`.
4. Compile and run the tests to confirm they fail (RED stage).
5. Document your setup, commands used, and failing test output in `handoff.md` in your working directory.

MANDATORY INTEGRITY WARNING: DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.
