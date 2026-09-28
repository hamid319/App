# Handoff Report — Explorer 1

## 1. Observation
We observed the following files and code structures in `/Users/ozanermis/Desktop/ProjectP/App/App`:

1. **`lib/common/models/place_model.dart`**:
   Contains `PlaceModel` with the following attributes (lines 4-13):
   ```dart
   class PlaceModel {
     final String id;
     final String name;
     final String? description;
     final double lat;
     final double lng;
     final String? address;
     final List<String> imageUrls;
     final double? averageRating;
     final List<String> types;
   ```
   Includes standard `fromJson`, `toJson`, and `copyWith` methods.

2. **`lib/features/swipe/data/places_repository.dart`**:
   - Contains a static const list of 51 mock places: `static const List<PlaceModel> mockPlaces = [ ... ]` (lines 215–744).
   - Hardcoded Google API key: `final String _googleApiKey = "YOUR_GOOGLE_PLACES_API_KEY";` (line 12–13).
   - Mock synthesis logic in `fetchExamplePlacesForLocation`:
     ```dart
     final placeId = '${location.countryCode}_${location.cityId}_${basePlace.id}';
     ```
     which merges synthesized mock places into the Firestore `'places'` collection.
   - Mock retrieval fallback in `loadNearbyPlaces` and `getPlaceById` controlled via a `useMock` boolean parameter.

3. **`lib/features/swipe/logic/swipe_controller.dart`**:
   Uses the mock fallback:
   - Line 84: `await _placesRepo.loadNearbyPlaces(..., useMock: true)`
   - Line 106: `await _placesRepo.loadNearbyPlaces(..., useMock: true)`
   - Line 94: Fallback catch block returning `PlacesRepository.mockPlaces`.

4. **`lib/features/group/logic/group_controller.dart`**:
   - Line 257 & 306: Calls `_placesRepo.fetchExamplePlacesForLocation(location, limit: ...)` to generate mock places for the session.

5. **`AGENTS.md` and `PLACES_API_MIGRATION.md`**:
   - `AGENTS.md` contains strict guidelines: "Never mix mock place IDs with real Google Places API IDs" and "Never hardcode API keys".
   - `PLACES_API_MIGRATION.md` outlines the transition strategy to **Nearby Search (New)** + **Place Details (New)** using the Essentials field mask.

---

## 2. Logic Chain
- **Point 1**: In `swipe_controller.dart`, the controller requests places using `loadNearbyPlaces(..., useMock: true)`. Thus, solo swiping is fully powered by `mockPlaces`.
- **Point 2**: In `group_controller.dart`, group sessions are populated via `fetchExamplePlacesForLocation`. This method synthesizes places based on a hash seed, assigns IDs like `US_NYC_1`, and saves them to the Firestore `places` collection.
- **Point 3**: Real Google API fetches (from `fetchPlacesFromGoogleAPI`) write directly to the same Firestore `'places'` collection with Google Place IDs (e.g. `ChIJN1t...`).
- **Point 4**: In `loadNearbyPlaces(..., useMock: false)`, the query scans the entire `'places'` collection. This mixes real Google Place IDs with synthesized mock place IDs (e.g. `${countryCode}_${cityId}_${id}`).
- **Conclusion**: This violates the rule "Never mix mock place IDs with real Google Places API IDs" inside the database and session lookups. It also poses a Firestore performance risk because `loadNearbyPlaces` performs a full table scan.

---

## 3. Caveats
- **Live testing**: We did not execute live API queries or authenticate with a real Google Places API key, as our objective is a read-only investigation.
- **Dynamic environment variables**: We assumed `Env.googlePlacesApiKey` and the dotenv setup is correctly loaded when running the application.

---

## 4. Conclusion
- **Model Map**: `PlaceModel` is an immutable data class containing basic metadata, ratings, addresses, image lists, and types.
- **Repository Map**: `PlacesRepository` manages standard Firestore CRUD, holds 51 static mock places, and includes legacy methods referencing outdated Google Places Text Search endpoints.
- **Mock Generation**: Synthesized via deterministic offsets and prefixes, written directly to Firestore under standard `'places'`.
- **Key Violations/Risks**:
  1. The Google Places API key is currently hardcoded in `places_repository.dart`.
  2. Mock IDs and real Google API IDs are stored together in the Firestore `'places'` collection.
  3. `loadNearbyPlaces` performs a full table scan of `'places'` in Dart.

---

## 5. Verification Method
- **Source Inspection**: Open and view `lib/common/models/place_model.dart` and `lib/features/swipe/data/places_repository.dart`.
- **Reference Document Check**: Inspect `PLACES_API_MIGRATION.md` and `AGENTS.md` to confirm the guidelines.
- **Logic Validation**: Check `swipe_controller.dart` lines 72-81 (`getPlaceById(pid, useMock: false)`) vs lines 84-88 (`loadNearbyPlaces(..., useMock: true)`).
