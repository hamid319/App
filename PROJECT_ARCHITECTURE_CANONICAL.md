# SwipeTrip Canonical Architecture

## Purpose

This document is the current architectural source of truth for SwipeTrip, also called Traveller App in older files. It explains what the app is trying to build, how the current codebase is organized, how the main data flows work, and which technical risks can block the project.

This is a documentation-only snapshot based on local project docs, codebase-memory-mcp graph inspection, and direct source inspection. It does not claim that `flutter analyze` passes, because the local shell used for this review did not have `flutter` on `PATH`.

## Current Stack

- Flutter and Dart.
- Riverpod 3 for state management.
- GoRouter 17 for routing and redirects.
- Firebase Auth for authentication.
- Cloud Firestore for users, places, groups, sessions, votes, and swipe results.
- Firebase Storage for profile images.
- Google Places API New Nearby Search for real place discovery.
- `flutter_dotenv` for local development secrets.
- `cached_network_image` for remote place images.
- `http` for Places API calls.
- `fake_cloud_firestore` and `mocktail` for Places API migration tests.

## Architectural Style

The app follows feature-first clean architecture:

```text
UI widgets/screens
  -> Riverpod controllers/notifiers
    -> repositories/services
      -> Firebase, Google Places API, local preferences, device services
```

The intended folder responsibilities are:

```text
lib/app/
  App shell, GoRouter setup, shell navigation, theme.

lib/common/models/
  Shared immutable-ish data models such as PlaceModel, GroupModel,
  GroupSessionModel, SessionVoteModel, SwipeResultModel, UserModel.

lib/common/widgets/
  Shared UI widgets used across multiple features.

lib/common/utils/
  Shared formatting, validation, and geospatial helpers.

lib/core/config/
  AppConfig and Env.

lib/core/constants/
  Shared app colors, sizes, and typography constants.

lib/core/errors/
  Failure and exception types.

lib/core/services/
  App-wide services for auth, Firestore, location, maps, and preferences.

lib/features/{feature}/ui/
  Screens and UI composition only.

lib/features/{feature}/logic/
  Riverpod controllers and feature state.

lib/features/{feature}/data/
  Repository classes and data access.

lib/features/swipe/widgets/
  Swipe-specific reusable card/button widgets.
```

## Main Features

### Authentication

Authentication uses Firebase Auth through `AuthService`, `AuthRepository`, and `AuthController`. The router reacts to auth state and sends unauthenticated users to login/register.

### Onboarding

Onboarding state is stored locally through `PreferencesService`. First-time users should see onboarding before entering the authenticated app flow.

### Places

Places are represented by `PlaceModel` and stored in Firestore under `/places/{placeId}`. Real API-backed places should use Google Places IDs as document IDs. The current model supports:

- `id`
- `name`
- `description`
- `lat`
- `lng`
- `address`
- `imageUrls`
- `averageRating`
- `types`
- `cityId`

### Swipe Discovery

Swipe discovery is handled by `SwipeController` and `PlacesRepository`. The user swipes cards, records swipe results, and manages favorites. In solo mode, swipe history is stored globally in `/swipeResults/{userId_placeId}`.

### Groups

Groups are represented by `GroupModel` and stored under `/groups/{groupId}`. A group can have:

- `ownerUid`
- `members`
- `location`
- `invite.code`
- `joinEnabled`
- `activeSessionId`
- `hasCompletedSession`

The group owner/admin can start or end a session. Members can join while `joinEnabled` is true.

### Group Sessions

Group sessions live under `/groups/{groupId}/sessions/{sessionId}` and are represented by `GroupSessionModel`. A session freezes:

- destination
- participant UIDs
- swipe limit
- place pool
- progress maps
- status
- optional end time

Votes live under `/groups/{groupId}/sessions/{sessionId}/votes/{placeId}`. Per-user session swipe state lives under `/groups/{groupId}/sessions/{sessionId}/userSwipes/{userId}`.

### Profile

Profiles use Firestore user documents and Firebase Storage for uploaded images. Favorites are stored as place ID arrays on user documents.

## Places API and Cache Flow

The intended real place discovery flow is:

1. Admin starts a group session for a selected `GroupLocation`.
2. `GroupController.startSessionWithLimit` calls `PlacesRepository.fetchAndCachePlacesForCity`.
3. The repository computes `cityId` as `${countryCode}_${cityId}`.
4. Firestore is queried first:

```text
/places where cityId == targetCityId limit requestedLimit
```

5. If enough cached places exist, return them with no API call.
6. If cache is short and real API calls are enabled, call:

```text
POST https://places.googleapis.com/v1/places:searchNearby
```

7. Request Essentials fields only:

```text
places.id
places.displayName
places.location
places.photos
places.types
places.formattedAddress
```

8. Convert photo resource names to media URLs:

```text
https://places.googleapis.com/v1/{photo_name}/media?maxWidthPx=800&key={apiKey}
```

9. Write each place to Firestore using the Google Places ID as the document ID.
10. Return the places to the session creation flow.

This cache-first design is the correct cost-control strategy. It avoids repeated API calls for the same city and makes later sessions faster.

## Group Session Voting Flow

The intended group voting flow is:

1. Admin starts a session.
2. Repository creates a session document with `status: in_progress`.
3. Group document gets `activeSessionId` and `joinEnabled: false`.
4. Router detects active sessions and redirects members to `/swipe/{groupId}` unless they are already in swipe or matches routes.
5. Each swipe calls session voting logic.
6. `GroupRepository.recordSwipeInSession` runs a Firestore transaction.
7. The transaction:
   - verifies the session exists
   - verifies the user is a participant
   - prevents duplicate progress increments for an already-voted place
   - updates `likedBy` and `dislikedBy`
   - updates `likes` and `dislikes`
   - writes `userSwipes/{userId}`
   - increments `progressByUser` and `swipeProgress`
   - completes the session when all participants reach the limit
8. Completion sets session `status: completed`, clears group `activeSessionId`, and sets `hasCompletedSession: true`.
9. The matches screen loads completed sessions and shows threshold-qualified places sorted by likes.

This transaction is one of the highest-risk parts of the app because it protects shared state under concurrent member activity.

## Routing and State Coordination

Routing is built in `lib/app/routes.dart`.

The router listens to:

- `authControllerProvider`
- `userGroupsProvider`

The redirect flow should handle:

- first-run onboarding
- unauthenticated login/register guard
- logged-in users redirected away from auth pages
- active group session redirect into swipe
- matches pages excluded from forced swipe redirects

This is correct architecturally, but it is sensitive to async timing because onboarding, auth state, and group streams all influence redirects.

## Firestore Data Model

Current intended shape:

```text
/users/{uid}
  uid: string
  email: string
  displayName: string?
  photoUrl: string?
  favorites: string[]
  groups: string[]
  createdAt: timestamp

/places/{placeId}
  id: string
  name: string
  description: string?
  lat: number
  lng: number
  address: string?
  imageUrls: string[]
  averageRating: number?
  types: string[]
  cityId: string?

/groups/{groupId}
  groupId: string
  groupName: string?
  ownerUid: string?
  members: string[]
  sharedFavorites: string[]
  location: map?
  joinEnabled: boolean?
  invite: map?
  activeSessionId: string?
  hasCompletedSession: boolean
  createdAt: timestamp

/groups/{groupId}/sessions/{sessionId}
  sessionId: string
  destination: string
  status: "in_progress" | "completed"
  totalPlacesToSwipe: number
  swipeLimit: number
  participants: string[]
  placePool: string[]
  swipeProgress: map<uid, number>
  progressByUser: map<uid, number>
  orderedPlaceIds: string[]?
  createdAt: timestamp
  endedAt: timestamp?
  endedByUid: string?
  endTime: timestamp?

/groups/{groupId}/sessions/{sessionId}/votes/{placeId}
  placeId: string
  likes: number
  dislikes: number
  likedBy: string[]
  dislikedBy: string[]

/groups/{groupId}/sessions/{sessionId}/userSwipes/{uid}
  swipedPlaceIds: string[]
  likedPlaceIds: string[]
  updatedAt: timestamp

/swipeResults/{userId_placeId}
  id: string
  userId: string
  placeId: string
  liked: boolean
  timestamp: timestamp
```

## Testing Strategy

Existing tests focus on the Places API migration:

- `test/places_api_migration_test.dart`
- `test/places_api_stress_test.dart`

These tests cover:

- `PlaceModel.cityId` parsing and serialization.
- Nearby Search endpoint, headers, field mask, and payload.
- Photo URL formatting.
- Cache hit and cache miss behavior.
- City isolation.
- Empty and malformed API responses.
- Large and zero limits.

Recommended next test coverage:

- `GroupRepository.recordSwipeInSession` transaction behavior.
- Duplicate vote behavior.
- Session auto-completion with multiple participants.
- Firestore rules alignment with actual session/vote fields.
- Router redirect behavior for login, onboarding, active session, and matches pages.
- `Env.init()` startup behavior and disabled/enabled Places API config.

## Current Risks and Bottlenecks

### 1. Places API Config Appears Broken

`lib/core/config/app_config.dart` currently appears to contain:

```dart
static bool enableRealPlacesAPI = faIse;
```

The value looks like `faIse` with a capital `I`, not `false`. Unless another symbol named `faIse` exists, this will fail Dart analysis.

### 2. Env Is Not Initialized in Main

`Env.init()` exists in `lib/core/config/env.dart`, but `lib/main.dart` initializes Firebase and then runs the app without calling `Env.init()`. That means `Env.googlePlacesApiKey` may be empty at runtime even if `.env` exists.

### 3. Real Places API Is Disabled by Config

`PlacesRepository.fetchAndCachePlacesForCity` throws if `AppConfig.enableRealPlacesAPI` is false. This is a useful cost guard, but it means the real API path will not work until config and environment initialization are intentionally fixed.

### 4. Firestore Rules Appear Stale

`firestore.rules` appears to allow session updates involving `progressByUser` and `isCompleted`, but the model uses `status`, `swipeProgress`, `progressByUser`, `endedAt`, `endedByUid`, and other fields. Vote rules mention `upvotes`, `downvotes`, and `votedUsers`, while current vote documents use `likes`, `dislikes`, `likedBy`, and `dislikedBy`.

This mismatch can cause production writes to fail even when local tests pass.

### 5. Nearby Places Full Collection Scan

`PlacesRepository.loadNearbyPlaces` reads the entire `places` collection and filters locally by distance. This is acceptable only for small dev datasets. It becomes slow and expensive as cached cities grow.

### 6. Cache Miss Loop

The cache hit condition requires cached docs to be greater than or equal to the requested limit. If Google returns fewer places than requested for a small city, future calls can repeatedly miss the cache and call the API again.

### 7. Mobile API Key Security

Using `.env` in a Flutter mobile app is a development convenience, not a production secret strategy. A release binary can expose the key. Before public release, the key should be restricted in Google Cloud Console at minimum. A backend or Firebase Cloud Function proxy is the stronger solution.

### 8. Transaction Complexity

`recordSwipeInSession` handles votes, progress, user swipe state, and completion in one transaction. This is the correct place for atomicity, but it needs careful tests because race conditions here can corrupt group results or leave sessions stuck.

### 9. Router Timing

GoRouter redirects depend on onboarding preferences, auth state, and group stream state. Async redirects can create loops or stale navigation if not tested with realistic loading states.

### 10. Inconsistent Historical Docs

Several historical Markdown files describe older mock-based approaches, completed migration claims, or planned behavior. These canonical docs should be treated as the current summary, while older files remain useful as audit/history.

## Recommended Next Fixes

1. Fix `AppConfig.enableRealPlacesAPI = false`.
2. Call `await Env.init()` in `main.dart` before `runApp`.
3. Run `flutter analyze` in an environment where Flutter is on PATH.
4. Update Firestore rules to match actual session and vote fields.
5. Add tests for `recordSwipeInSession` using `fake_cloud_firestore`.
6. Replace `loadNearbyPlaces` full scan with city-scoped or geohash-based querying.
7. Add city sync metadata to prevent repeated API calls for cities with fewer than the requested limit.
8. Keep real Google Places IDs isolated from old mock IDs in all active sessions.
9. Add a backend proxy or Cloud Function before shipping real Places API calls publicly.
10. Add route redirect tests for auth, onboarding, active sessions, and completed matches.

## Build and Verification Notes

During this documentation pass, `flutter analyze` could not be run because the shell returned:

```text
zsh:1: command not found: flutter
```

Before claiming the app is build-clean, verify locally with Flutter installed and on PATH:

```bash
flutter pub get
flutter analyze
flutter test test/places_api_migration_test.dart
flutter test test/places_api_stress_test.dart
```

