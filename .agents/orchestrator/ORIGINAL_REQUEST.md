# Original User Request

## 2026-06-28T01:39:46Z

Implement the Google Places API (New) migration plan to replace the mock places system in places_repository.dart with Nearby Search (New) API calls and Firestore caching as outlined in PLACES_API_MIGRATION.md.

Working directory: /Users/ozanermis/Desktop/ProjectP/App/App
Integrity mode: demo

## Requirements

### R1. Implement Places API (New) Nearby Search Integration
- Update PlaceModel to add a nullable cityId field.
- Replace fetchExamplePlacesForLocation and fetchPlacesFromGoogleAPI in PlacesRepository with fetchAndCachePlacesForCity using the https://places.googleapis.com/v1/places:searchNearby endpoint.
- Retrieve the Essentials tier fields (places.id, places.displayName, places.location, places.photos, places.types, places.formattedAddress) and build the photo URLs using the new media endpoint format: https://places.googleapis.com/v1/{photo_name}/media.

### R2. Cost-Optimized Firestore Caching & Radius Searches
- Cache all fetched places in the Firestore places collection using the Google Place ID as the document key. Include cityId (formatted as ${countryCode}_${cityId}) on each document.
- Prioritize reading from this local Firestore cache. Only perform external Places API calls when the number of cached documents for that city is less than the requested limit.
- Update getPlaceById and loadNearbyPlaces in PlacesRepository to remove useMock parameters and read directly from Firestore.

### R3. Update Controllers, Screens, and Assets
- Update the session-start logic in group_controller.dart to use the new fetchAndCachePlacesForCity repository method.
- Update swipe_controller.dart and place_detail_screen.dart to remove mock flags and safely handle null ratings and descriptions.
- Add cached_network_image to pubspec.yaml and run flutter pub get. Replace raw network images in the UI with CachedNetworkImage.

## Acceptance Criteria

### API Correctness
- [ ] No occurrences of `fetchExamplePlacesForLocation` remaining in the codebase.
- [ ] Raw Places API calls are made only when the Firestore cache misses.
- [ ] All `useMock` parameter uses are removed from repository calls in controller/UI files.
- [ ] `flutter analyze` runs without errors in the project.
