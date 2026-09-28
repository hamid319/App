## 2026-06-28T01:48:56Z
You are teamwork_preview_worker. Your working directory is /Users/ozanermis/Desktop/ProjectP/App/App/.agents/worker_milestone3.
Your task is to implement the Repository & Model Migration (Milestone 3) for the Google Places API (New) migration as outlined in `PROJECT.md`, `PLACES_API_MIGRATION.md`, and the test file `test/places_api_migration_test.dart`.

Please perform the following steps:
1. Update `PlaceModel` in `lib/common/models/place_model.dart` to add the nullable `cityId` field (including copyWith, fromJson, and toJson).
2. Update `PlacesRepository` in `lib/features/swipe/data/places_repository.dart`:
   - Replace the old hardcoded `_googleApiKey` field with `Env.googlePlacesApiKey` (import `package:mobileapp/core/config/env.dart`).
   - Implement `fetchAndCachePlacesForCity` using `_client.post` targeting `https://places.googleapis.com/v1/places:searchNearby`. Include the Essentials tier fields mask, query by `cityId` in Firestore, and cache results. Format photo URLs using `https://places.googleapis.com/v1/{photo_name}/media`.
   - Update `getPlaceById` and `loadNearbyPlaces` to remove the `useMock` parameter and read directly from Firestore cache.
   - Clean up or remove `fetchExamplePlacesForLocation` and `fetchPlacesFromGoogleAPI` to satisfy the acceptance criteria.
3. Run `flutter pub get` and verify that the tests in `test/places_api_migration_test.dart` pass cleanly (GREEN stage).
4. Run `flutter analyze` to ensure there are no static analysis or compilation errors.
5. Document your implementation details, verify command outputs, and report any errors/warnings in `handoff.md` in your working directory.

MANDATORY INTEGRITY WARNING: DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.
