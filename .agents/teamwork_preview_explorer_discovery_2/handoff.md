# Handoff Report: Places Flow & Controller Investigation

## 1. Observation
- `lib/features/places/ui/place_detail_screen.dart` (lines 9–12):
  ```dart
  final placeDetailProvider = FutureProvider.family<PlaceModel?, String>((ref, placeId) async {
    final repo = PlacesRepository();
    return await repo.getPlaceById(placeId, useMock: true);
  });
  ```
- `lib/features/swipe/data/places_repository.dart` (lines 17–33):
  ```dart
  Future<List<PlaceModel>> fetchExamplePlacesForLocation(
    GroupLocation location, {
    required int limit,
  }) async {
    if (limit <= 0) return [];

    final seedKey = '${location.countryCode}:${location.cityId}';
    final seed = _stableHash(seedKey);
    final random = math.Random(seed);
    final startIndex = seed % mockPlaces.length;

    final List<PlaceModel> generated = [];
    for (var i = 0; i < limit; i++) {
      final basePlace = mockPlaces[(startIndex + i) % mockPlaces.length];
      final placeId =
          '${location.countryCode}_${location.cityId}_${basePlace.id}';
  ```
- `lib/features/swipe/data/places_repository.dart` (lines 128–135):
  ```dart
  Future<PlaceModel?> getPlaceById(String id, {bool useMock = false}) async {
    if (useMock) {
      try {
        return mockPlaces.firstWhere((place) => place.id == id);
      } catch (e) {
        return null;
      }
    }
  ```
- Raw `Image.network` is used in 7 files including `place_detail_screen.dart` (line 96), `swipe_card.dart` (line 345), and `place_card.dart` (line 50).
- `PlaceModel.description` is a nullable string (`String?`) and is accessed via `place.description ?? ''` (e.g. `place_detail_screen.dart` line 112).
- `PlaceModel.averageRating` is a nullable double (`double?`) and is never referenced in any of the UI files.

---

## 2. Logic Chain
- **Step 1**: In group sessions, `fetchExamplePlacesForLocation` is called, which creates place IDs with location prefixes (e.g., `US_NYC_1`) and saves them to Firestore. These prefixed IDs are not present in the hardcoded list `mockPlaces`.
- **Step 2**: The `placeDetailProvider` in `place_detail_screen.dart` retrieves the selected place by calling `repo.getPlaceById(placeId, useMock: true)`.
- **Step 3**: Because `useMock: true` is hardcoded in `placeDetailProvider`, the `getPlaceById` method attempts to resolve the ID purely from the local `mockPlaces` array.
- **Step 4**: Since prefixed IDs like `US_NYC_1` do not exist in `mockPlaces`, the lookup fails and returns `null`.
- **Step 5**: This results in the user interface showing the "Place not found" error when attempting to open a place details page from a group session.
- **Step 6**: The 7 occurrences of raw `Image.network` are directly observed in layout files and lack image caching.
- **Step 7**: Null description and rating safety checks are verified: description coalescing prevents crashes; rating is safe because it is unused in the UI.

---

## 3. Caveats
- Checked for occurrences of `fetchPlacesFromGoogleAPI` to ensure it is not used; it was confirmed to be unused in the current codebase.
- Did not perform live database operations or manual UI navigation since this is a read-only investigation.

---

## 4. Conclusion
- **Mapping**: `group_controller.dart` controls group settings and session lifecycles; `swipe_controller.dart` handles swiping and favorite caching.
- **Bugs/Issues**: `placeDetailProvider` in `place_detail_screen.dart` has a critical bug (`useMock: true` is hardcoded) which prevents showing details for session places. It should be changed to use `useMock: false` or have the parameter removed.
- **Raw Image Usage**: 7 UI files use raw `Image.network` and need to be refactored to use `CachedNetworkImage` once the package is added.
- **Null Safety**: Description is nullable but handled correctly. Rating is currently unused in the UI but must be treated as nullable if implemented later.

---

## 5. Verification Method
- **Static Inspection**: Read `lib/features/places/ui/place_detail_screen.dart` around line 11 to confirm that `useMock: true` is hardcoded.
- **Post-Fix Testing**: Change `useMock: true` to `useMock: false` (or remove it once the parameter is removed from `getPlaceById`), compile the app, and verify that navigating to place details works for both solo places and group session places.
