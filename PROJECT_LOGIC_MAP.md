# SwipeTrip Critical Logic Map

## Bootstrap, Environment, And Firebase

`lib/main.dart` owns app startup. The expected startup sequence is:

1. initialize environment variables with `Env.init()`
2. initialize Firebase using `DefaultFirebaseOptions`
3. run `MobileApp` with the root Riverpod provider scope

`Env` reads `.env` through `flutter_dotenv`. `AppConfig` controls limits and feature flags such as real Places API usage. When touching startup, verify that tests and app runtime agree on whether environment and Firebase initialization are injected, skipped, or executed.

Risk: if `Env.init()` is not called before a Places API call, `Env.googlePlacesApiKey` can be empty even when `.env` exists.

## Onboarding, Auth, And Routing

Authentication flows through:

```text
AuthService -> AuthRepository -> AuthController -> GoRouter/UI
```

`AuthService` wraps Firebase Auth. `AuthRepository` is a thin feature data layer. `AuthController` loads the signed-in user profile, handles login/signup/logout, and exposes Riverpod async state.

Onboarding state is local and uses `PreferencesService`. GoRouter coordinates onboarding, unauthenticated auth pages, authenticated shell routes, and active group-session redirects. Routing changes should preserve these cases:

- first-run users see onboarding before the main app
- unauthenticated users can reach login/register but not protected screens
- authenticated users are redirected away from auth pages
- active group sessions can force members into the swipe flow
- matches/history routes are not trapped by the active-session redirect

Risk: redirects combine async auth, local preferences, and group stream state. Test loading and stale-state paths, not only happy paths.

## Places API And Cache Flow

`PlacesRepository` owns place discovery, Google Places API calls, Firestore caching, swipe result writes, and place lookup helpers.

The intended cache-first flow is:

1. Receive a `GroupLocation` and requested limit.
2. Compute a stable city key such as country/city code.
3. Query cached `/places` documents by `cityId`.
4. If enough cached places exist, return them without an API call.
5. If cache is short and real API calls are enabled, call Google Places New Nearby Search.
6. Request only needed Essentials fields.
7. Convert photo resource names into media URLs.
8. Store each place with the real Google Places ID as the Firestore document ID.
9. Return cached plus newly fetched places to the caller.

Do not mix old mock IDs with real Google Places IDs. Group sessions and swipe results should refer to the same ID scheme from start to finish.

Risks:

- Real API calls are gated by config and environment.
- A city that returns fewer results than requested can repeatedly miss the cache unless sync metadata or a lower available count is recorded.
- API keys in Flutter mobile builds are not true secrets.

## Solo Swipe And Favorites

Solo swipe behavior flows through:

```text
Swipe UI -> SwipeController -> PlacesRepository -> Firestore/user profile
```

The user swipes place cards. Right swipes create liked state and favorite behavior; left swipes record a pass. Favorites are user-level place IDs and must stay consistent across swipe screens, place detail, profile, and favorites views.

Important behavior:

- Adding a favorite from a detail page must not advance the swipe deck.
- Resetting swipe state should invalidate or reload the owning provider state.
- Swipe history and favorites should not leak between users.

## Group Creation, Session Start, Voting, And Matches

Group flow spans models, repository, controller, router, and UI:

```text
Group UI -> GroupController -> GroupRepository -> Firestore
                      |
                      v
              PlacesRepository for session place pool
```

Groups are stored under `/groups/{groupId}`. A group tracks owner/admin, members, location, invite code, join state, active session, completed-session state, and shared favorites.

Session start should:

1. freeze the destination and participants
2. build a shared place pool for the selected city
3. create `/groups/{groupId}/sessions/{sessionId}`
4. set session status to in progress
5. update the group with `activeSessionId`
6. disable joining while the session is active

Session votes live under `/groups/{groupId}/sessions/{sessionId}/votes/{placeId}`. Per-user session swipe progress lives under `/groups/{groupId}/sessions/{sessionId}/userSwipes/{uid}`.

`GroupRepository.recordSwipeInSession` is the highest-risk function. It must keep these invariants:

- the session exists
- the voter is a participant
- duplicate votes do not double-count progress
- `likedBy`/`dislikedBy` match `likes`/`dislikes`
- per-user swiped and liked place lists are updated consistently
- progress maps move forward exactly once per place per user
- the session completes when all participants reach the limit
- completion clears the group active session and enables results/history views

Matches are calculated from completed session votes. The MVP outcome is threshold-qualified places sorted by like count.

## Profile And Images

Profile data uses Firestore user documents. Profile images use Firebase Storage through the profile image service. Keep profile updates consistent with current auth UID, and preserve favorites arrays unless a change intentionally modifies favorites.

Risk: profile updates often combine UI optimistic state, Firestore persistence, and Storage URLs. Preserve previous state on failure where controller logic already does so.

## Data Model Invariants

- `/users/{uid}.favorites` stores place IDs, not embedded place objects.
- `/places/{placeId}.id` should match the Firestore document ID.
- Real Places API documents should use Google Places IDs.
- A group can have at most one active session through `activeSessionId`.
- A session place pool is frozen at start time.
- Vote documents aggregate per-place state; user swipe documents track per-user progress.
- Session completion should be represented consistently between session status and group state.

## Testing Priorities

Highest-value tests are:

- `GroupRepository.recordSwipeInSession` duplicate vote and concurrent progress behavior.
- Auto-completion when all participants finish.
- Group matches threshold and ordering.
- Router redirects for onboarding, auth, active session, and matches exclusions.
- Places API cache hit, cache miss, malformed response, city isolation, and field-mask behavior.
- Env/AppConfig behavior when real Places API is enabled or disabled.
