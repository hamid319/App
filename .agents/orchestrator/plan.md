# Migration Plan: Google Places API (New)

## Phase 1: Codebase Discovery and Status Verification (Milestone 1)
- Dispatch Explorer to check current project state.
- Inspect `lib/features/swipe/data/places_repository.dart`.
- Inspect `lib/common/models/place_model.dart`.
- Inspect controllers and UI files: `group_controller.dart`, `swipe_controller.dart`, `place_detail_screen.dart`.
- Check if empty files (`swipe_card.dart`, `swipe_buttons.dart`, `app_config.dart`, `env.dart`) are actually empty or populated.
- Run `flutter analyze` via the worker/explorer to check current state.

## Phase 2: E2E and Unit Test Preparation (Milestone 2)
- Design opaque-box test cases for places discovery and caching.
- Create dummy group location inputs for testing.
- Set up unit or widget test cases verifying local Firestore querying and mock endpoints.
- Establish `TEST_INFRA.md`.

## Phase 3: Places Model and Repository Implementation (Milestone 3)
- Modify `PlaceModel` to add `cityId` field.
- Remove old mock-based methods and static mock data lists from `PlacesRepository`.
- Implement `fetchAndCachePlacesForCity` using HTTP POST to Places API (New) searchNearby.
- Implement Essentials tier field mask: id, displayName, location, photos, types, formattedAddress.
- Implement photo URL builder with the new media format: `https://places.googleapis.com/v1/{photo_name}/media`.
- Cache response in Firestore `/places` using Place ID as document key. Include `cityId`.
- Prioritize cached reading: read local Firestore cache first, fall back to Places API.
- Remove `useMock` parameters from `getPlaceById` and `loadNearbyPlaces`.

## Phase 4: Controllers and UI Integration (Milestone 4)
- Update `group_controller.dart` to call `fetchAndCachePlacesForCity` instead of `fetchExamplePlacesForLocation`.
- Update `swipe_controller.dart` to remove mock flags and remove mock places fallback.
- Update `place_detail_screen.dart` to remove `useMock` parameter and handle null description/ratings safely.
- Add `cached_network_image` to `pubspec.yaml`, run `flutter pub get`.
- Replace raw network images with `CachedNetworkImage` in the UI.

## Phase 5: Verification & Adversarial Hardening (Milestone 5)
- Verify `flutter analyze` runs clean.
- Run unit/integration tests and verify caching behavior.
- Perform adversarial coverage testing using Challenger.
- Run Forensic Auditor to verify integrity and cleanliness.
