# Project: Traveller App Places API Migration

## Architecture
- Feature-first clean architecture: UI -> Logic (Controller) -> Data (Repository).
- Google Places API (New) Nearby Search Integration with Firestore caching.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Discovery & Exploration | Scan codebase, identify files, inspect empty files | None | DONE |
| 2 | Test Infra Setup | Setup test cases and runner, define requirements | M1 | DONE |
| 3 | Repository & Model Migration | Migrate PlaceModel & PlacesRepository, Firestore caching | M2 | DONE |
| 4 | Controller & UI Migration | Migrate group, swipe controllers, UI screens, CachedNetworkImage | M3 | DONE |
| 5 | E2E Verification & Audit | Run E2E tests, adversarial coverage, integrity audit | M4 | DONE |

## Interface Contracts
### PlacesRepository ↔ Firestore
- Real Place ID as document key in `/places` collection.
- `cityId` stored on document in format `${countryCode}_${cityId}`.

### PlacesRepository ↔ Controllers
- `fetchAndCachePlacesForCity(GroupLocation, {int limit})` returns `Future<List<PlaceModel>>`.
- `getPlaceById(String)` returns `Future<PlaceModel?>` (no `useMock`).
- `loadNearbyPlaces(double, double, {double radiusKm, List<String>? tags})` (no `useMock`).
