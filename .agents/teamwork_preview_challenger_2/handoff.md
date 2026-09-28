# Handoff Report — Caching & Isolation Logic Verification

## 1. Observation

- **Places Repository File**: `lib/features/swipe/data/places_repository.dart`
  - Line 24: `final cityId = '${location.countryCode}_${location.cityId}';`
  - Lines 27-31:
    ```dart
    final cached = await _db
        .collection('places')
        .where('cityId', isEqualTo: cityId)
        .limit(limit)
        .get();
    ```
  - Line 104: `cityId: cityId,` (inside the mapping of places returned from Google Places API).
  - Lines 108-111:
    ```dart
    await _db
        .collection('places')
        .doc(place.id)
        .set(place.toJson(), SetOptions(merge: true));
    ```

- **Group Controller File**: `lib/features/group/logic/group_controller.dart`
  - Lines 257-260:
    ```dart
    final places = await _placesRepo.fetchAndCachePlacesForCity(
      location,
      limit: swipeLimit,
    );
    ```
  - Lines 280-283:
    ```dart
    } catch (e) {
      state = savedState;
      rethrow;
    }
    ```

- **Simplified Group Screen File**: `lib/features/group/ui/simplified_group_screen.dart`
  - Lines 751-769:
    ```dart
    try {
      await ref
          .read(groupControllerProvider.notifier)
          .startSessionWithLimit(swipeLimit: swipeLimit, durationMinutes: timeLimit);
      ...
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error starting session: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
    ```

- **Test Suite Modifications**: `test/places_api_migration_test.dart`
  - Added `TestCase 2.4` and `TestCase 2.5` to verify empty/missing keys in the API response and invalid/corrupt JSON body handling in `fetchAndCachePlacesForCity`.

---

## 2. Logic Chain

1. **City Caching Isolation**:
   - The repository uses a strict key format: `cityId = '${location.countryCode}_${location.cityId}'`.
   - The Firestore cache query filters strictly by `cityId` using `.where('cityId', isEqualTo: cityId)`.
   - The Google Places API call uses location restriction coordinates of the requested city:
     ```json
     "locationRestriction": {
       "circle": {
         "center": {
           "latitude": location.lat,
           "longitude": location.lng
         },
         "radius": 15000.0
       }
     }
     ```
   - Therefore, places cached for city A cannot be returned in cache checks or API results for city B.

2. **Shared Place Edge Case (Cache Eviction)**:
   - When a place with ID `X` is cached, it is written to Firestore at path `places/X` with `cityId`.
   - If City A and City B are close and both encompass place `X`, querying City A will save place `X` with `cityId = 'A'`.
   - Querying City B subsequently will overwrite place `X` with `cityId = 'B'`.
   - This evicts place `X` from City A's cache (as it no longer matches `.where('cityId', isEqualTo: 'A')`), causing a cache miss/re-fetch on future City A queries, but does not result in incorrect or polluted data.

3. **Empty/Error Response Handling**:
   - If the API returns 200 with an empty place list or missing `places` key, the repository parses it safely as `[]` (empty list) due to `(data['places'] as List?) ?? []`.
   - If the API returns a non-200 status code, the repository throws an `Exception`.
   - If the API returns malformed JSON, `json.decode` throws a `FormatException`.
   - In all exception paths, the `GroupController` propagates the exception while reverting to its previous state.
   - The UI layer (`simplified_group_screen.dart`) wraps the call in a `try-catch` block, intercepts all thrown exceptions, and displays a red `SnackBar` message to the user, preventing any application crash.

---

## 3. Caveats

- We assumed that the Google Places API is the only external service caching places in the app.
- We did not evaluate the behavior of real Firestore offline persistence, though the unit tests mock Firestore behavior using `fake_cloud_firestore`.
- Running the tests via terminal timed out due to user permission confirmation timeout (meaning no user interactive input was present). We verified the test logic statically and syntactically.

---

## 4. Conclusion

- **City Isolation**: robustly isolated by `cityId` in Firestore queries and coordinates in Nearby Search API requests.
- **Empty/Error Handling**: robustly handled without crashing. Empty responses return an empty list of places (and notify the user via UI), and API/JSON decode errors are caught and shown via `SnackBar` alerts.

---

## 5. Verification Method

To verify the test suite (including the new tests 2.4 and 2.5):
```bash
flutter test test/places_api_migration_test.dart
```
Expected output: all tests under `Places API (New) Migration Tests` passing.
