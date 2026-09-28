# Places Repository & Model Analysis Report

## Summary of Findings
An exploration of the Traveller App codebase was performed to map the structure of `place_model.dart` and `places_repository.dart`. We identified that the app currently relies on 51 hardcoded mock places, is structured using feature-first clean architecture, and has clear constraints regarding API key management, language requirements, and place ID consistency.

---

## 1. Structure of `place_model.dart`

**File Location**: `lib/common/models/place_model.dart`

`PlaceModel` is an immutable class designed for representing travel sights/places.

### Class Definition & Annotations
- Marked with `@immutable` from `package:meta/meta.dart`.
- Uses a `const` constructor for performance and safety.

### Fields and Types
| Field | Type | Nullability | Purpose / Notes |
|---|---|---|---|
| `id` | `String` | Non-nullable | Unique identifier (Mock ID or Google Place ID) |
| `name` | `String` | Non-nullable | Name of the place |
| `description` | `String?` | Nullable | Description (absent in Essentials tier API responses) |
| `lat` | `double` | Non-nullable | Latitude coordinate |
| `lng` | `double` | Non-nullable | Longitude coordinate |
| `address` | `String?` | Nullable | Formatted address of the place |
| `imageUrls` | `List<String>` | Non-nullable | List of image URLs; defaults to `const []` |
| `averageRating` | `double?` | Nullable | Rating score out of 5.0 (requires Pro/Premium API tier) |
| `types` | `List<String>` | Non-nullable | Place category types (tags); defaults to `const []` |

### Key Methods
- **`copyWith`**: Returns a new `PlaceModel` instance copying values and overriding specified fields.
- **`fromJson`**: Factory constructor parsing API and Firestore JSON payloads. Maps `imageUrls` fallback to `images` key, and `types` fallback to `tags` key if the primary key is missing.
- **`toJson`**: Serialization method returning a `Map<String, dynamic>`.

---

## 2. Structure of `places_repository.dart`

**File Location**: `lib/features/swipe/data/places_repository.dart`

`PlacesRepository` manages place retrieval, storage in Cloud Firestore (`places` and `swipeResults` collections), and contains mock place data.

### Fields
- `_db`: `FirebaseFirestore` instance.
- `_googleApiKey`: Hardcoded string `"YOUR_GOOGLE_PLACES_API_KEY"`. (Violates key constraint of not hardcoding API keys; needs migration).

### API & Data Retrieval Methods
- **`fetchExamplePlacesForLocation(GroupLocation location, {required int limit})`**:
  - Generates location-based mock places using a stable seed, applies coordinate jitter, and writes them into the Firestore `places` collection.
- **`fetchPlacesFromGoogleAPI(String destination, {int limit = 20})`**:
  - Unused legacy method targeting the deprecated/old Google Places Text Search endpoint. Caches fetched results in Firestore.
- **`loadNearbyPlaces(double lat, double lng, {double radiusKm = 50.0, List<String>? tags, bool useMock = false})`**:
  - Loads places located within a given radius. Filters by tags. If `useMock` is true, skips Firestore entirely and returns the static `mockPlaces` list.
- **`getPlaceById(String id, {bool useMock = false})`**:
  - Retrieves a place from Firestore (or static `mockPlaces` if `useMock` is true) by its identifier.

### Swipe Recording & Retrieval Methods
- **`recordSwipe({required String userId, required String placeId, required bool liked})`**:
  - Records user swipe interaction in Firestore `swipeResults` collection under document `${userId}_${placeId}`.
- **`getUserSwipes(String userId)`**:
  - Returns a list of all swipes recorded by a user sorted by timestamp.
- **`getSwipedPlaceIds(String userId)`**:
  - Returns a set of place IDs a user has already swiped on.
- **`clearSwipedPlaces(String userId)`**:
  - Batched deletion of all swipe results associated with the user.
- **`getUserLikedPlaceIds(String userId)`**:
  - Returns a list of place IDs liked by a user.

### Internal Helper Methods
- `_stableHash(String input)`: Returns a stable hash value used for mock generation seeding.
- `_nextOffset(math.Random random)`: Generates a small coordinate offset to jitter mock place locations around a city center.

---

## 3. Mock Data Generation and Usage

Mock data is stored inside a static const list `PlacesRepository.mockPlaces` containing **51 hardcoded PlaceModel items** (lines 215–744 of `places_repository.dart`).

### How Mock Data is Used in the App:
1. **Solo Swipe Discovery**:
   - `SwipeController.build()` and `refreshWithLocation()` call `_placesRepo.loadNearbyPlaces(..., useMock: true)`.
   - Because `useMock: true` is hardcoded, solo swiping retrieves the 51 mock places directly.
   - If an exception occurs, `SwipeController.build()` falls back to `PlacesRepository.mockPlaces` as a default list.
2. **Group Session Place Generation**:
   - When an admin starts a session (`GroupController.startNewSession()` or `startSession()`), it calls `_placesRepo.fetchExamplePlacesForLocation(location, limit: limit)`.
   - This method creates a stable random generator seeded with the location's `countryCode` and `cityId`.
   - It iterates `limit` times, sequentially picking from `mockPlaces` starting at a deterministic offset.
   - It constructs unique mock IDs (`${countryCode}_${cityId}_${basePlace.id}`), applies coordinate jitter, modifies the address to match the group location, and caches them in the Firestore `places` collection.
3. **Place Details View**:
   - When viewing details of a place, `place_detail_screen.dart` calls `getPlaceById(placeId, useMock: true)`.

---

## 4. Identified File-Specific Constraints & Guidelines

Based on our inspection and project configuration (`AGENTS.md` and `PLACES_API_MIGRATION.md`), the following constraints exist:

### A. Architectural & Code Constraints (from `AGENTS.md`):
- **Mock vs. Real IDs**: Never mix mock place IDs (such as `'1'`, `'DE_berlin_2'`) with real Google Places API IDs in active session pools, as this will break retrieval logic.
- **Hardcoding Secrets**: Never hardcode API keys (such as `_googleApiKey` in `places_repository.dart`). Instead, use `flutter_dotenv` and `lib/core/config/env.dart`.
- **State Invalidation**: Always call `ref.invalidateSelf()` after resetting states (e.g. inside `SwipeController.resetAll()`).
- **Language**: All strings must be in English. No German text.
- **Protected Files**: Do NOT modify or refactor `auth_service.dart`, `firestore_service.dart`, or `group_repository.dart`. `routes.dart` should only be edited to resolve auth redirect bugs.

### B. Migration & Performance Constraints (from `PLACES_API_MIGRATION.md`):
- **Nearby Search vs. Text Search**: Migrating to Google Places API (New) requires moving away from the Text Search endpoint to **Nearby Search (New)** (`/v1/places:searchNearby`) centering on the group location's coordinates.
- **Cost Reduction**: Essentials field mask should be used (e.g. excluding `editorialSummary` and `rating` to avoid Pro/Enterprise pricing tiers).
- **Photo URL Structure**: The New Places API returns a photo resource name format (e.g., `places/{place_id}/photos/{photo_id}`) which must be fetched via `https://places.googleapis.com/v1/{photo_name}/media`. The old `photo_reference` query parameters will not work.
- **Firestore Collection Scan**: `loadNearbyPlaces` performs a full scan (`_db.collection('places').get()`) of the `places` collection which poses a significant performance and cost issue. Introducing a `cityId` field for filtering is required.
