# E2E Test Infra: Traveller App Places API Migration

## Test Philosophy
- Opaque-box, requirement-driven. No dependency on implementation design.
- Methodology: Category-Partition + BVA + Pairwise + Workload Testing.

## Feature Inventory
| # | Feature | Source (requirement) | Tier 1 | Tier 2 | Tier 3 | Tier 4 |
|---|---------|---------------------|:------:|:------:|:------:|:------:|
| 1 | Nearby Search API | ORIGINAL_REQUEST §R1 | 3      | 3      | ✓      | ✓      |
| 2 | Firestore Caching | ORIGINAL_REQUEST §R2 | 2      | 2      | ✓      | ✓      |

## Test Cases Design

### Tier 1 - Feature Coverage
- **TestCase 1.1**: Verify `PlaceModel` parses and serializes `cityId` field correctly.
- **TestCase 1.2**: Verify `PlacesRepository.fetchAndCachePlacesForCity` formats photo media URLs using the new `/v1/{photo_name}/media` format.
- **TestCase 1.3**: Verify `PlacesRepository.getPlaceById` and `loadNearbyPlaces` do not use `useMock` flags.
- **TestCase 1.4**: Verify HTTP request payload of `fetchAndCachePlacesForCity` matches Nearby Search (New) requirements.

### Tier 2 - Boundary & Corner Cases
- **TestCase 2.1**: Verify `PlacesRepository.fetchAndCachePlacesForCity` handles empty/null fields in API responses.
- **TestCase 2.2**: Verify `PlacesRepository.fetchAndCachePlacesForCity` handles API non-200 HTTP response codes.
- **TestCase 2.3**: Verify cache check only calls API when cached document count is less than the requested limit.

### Tier 3 - Cross-Feature Combinations
- **TestCase 3.1**: Verify Cache Hit / Miss Flow - first call calls API and caches; subsequent call reads from cache without API call.
- **TestCase 3.2**: Verify City Isolation - places cached for one city do not populate queries for another city.

### Tier 4 - Real-World Application Scenarios
- **TestCase 4.1**: Simulated full session flow from destination select to group swiping.
