# Firebase, Firestore, and API Demo Readiness Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Make SwipeTrip reliably demo-ready in a local iOS simulator with real Firebase, Google Places, and Gemini credentials, with the Firestore/Storage schema, rules, indexes, API cache, and group-session transaction paths aligned and verified.

**Architecture:** Keep the current Flutter feature-first/Riverpod 3 architecture. The Flutter client remains responsible for Google Places/Gemini calls for this local-demo milestone, but API keys must not be persisted in Firestore documents. Firestore rules and indexes will be treated as versioned executable contracts and verified in the Firebase Emulator Suite before any optional deployment to the configured Firebase project.

**Tech Stack:** Flutter/Dart, Riverpod 3, Firebase Auth, Cloud Firestore, Firebase Storage, Firebase Emulator Suite, Google Places API New Nearby Search, Gemini generateContent API, `flutter_dotenv`, `fake_cloud_firestore`, `mocktail`, Node.js `@firebase/rules-unit-testing` for rules tests.

---

## Execution Contract

### Model routing

- **Orchestrator:** GPT Terra.
- **Implementation/coding workers:** GPT-5.6 Sol.
- **Independent spec/code/security reviewers:** GPT Terra, in a fresh context separate from the implementer.
- Before execution, verify the runtime supports role-specific model routing. If it cannot honor this split, stop and ask the user rather than silently substituting models.

### Required skills and workflows

Use these in this order:

1. `gsd-code-review --depth=deep` to establish a baseline over the current dirty Firebase/API-related files.
2. `dart-run-static-analysis` for every Dart implementation wave.
3. `flutter-add-widget-test` only where a widget-level contract is needed.
4. `flutter-add-integration-test` for the final simulator smoke path.
5. `gsd-secure-phase` to review Firestore/Storage rules and client-side API-key handling.
6. `requesting-code-review` after each implementation wave and before any commit/deployment.
7. Follow `PROJECT_REFRESH_PLAYBOOK.md` after meaningful code or architecture changes.

Repo-local `flutter-apply-architecture-best-practices` is supporting guidance only. Its generic `ChangeNotifier` examples must not replace this repository's established Riverpod 3 patterns.

### Scope boundaries

In scope:

- Firebase initialization and configuration sanity.
- Firestore collection/document schema.
- Firestore security rules and indexes.
- Firebase Storage profile-image path/rules alignment.
- Google Places request contract and cache behavior.
- Gemini request configuration and graceful fallback.
- Group/session/vote/userSwipes transaction correctness.
- API key presence validation and non-secret example configuration.
- Analyzer, unit, rules-emulator, and simulator verification.

Explicitly out of scope:

- German/English copy cleanup.
- Borda ranking and Phase 5 consensus work.
- Production backend proxy/Cloud Functions migration.
- App Store release hardening, legal copy, CI/CD, FCM, and account-security features.
- Broad UI redesign or unrelated refactoring.

### Dirty-worktree safety

The repository already has a broad dirty worktree. Do not stash, reset, discard, or rewrite unrelated user changes.

Before editing:

```bash
git status --short --branch
git diff -- firestore.rules storage.rules firebase.json lib/core/config lib/features/swipe/data/places_repository.dart lib/features/group/data/group_repository.dart
```

After each task, stage only the exact paths listed in that task. If a target file contains pre-existing user changes that cannot be separated safely, do not commit automatically; preserve the working tree and report the conflict.

---

## Confirmed Baseline Findings

These findings were confirmed by direct source inspection and must be treated as failing readiness gates until fixed:

1. `firestore.rules` has no rules for `/places/{placeId}`, `/swipeResults/{resultId}`, or session `/userSwipes/{uid}` documents.
2. Session rules allow old fields (`progressByUser`, `isCompleted`) while current code writes `swipeProgress`, `progressByUser`, `status`, `endedAt`, and `endedByUid`.
3. Vote rules expect old fields (`upvotes`, `downvotes`, `votedUsers`) while current code writes `placeId`, `likes`, `dislikes`, `likedBy`, and `dislikedBy`.
4. `firebase.json` references `firestore.indexes.json`, but that file is absent.
5. Storage code writes `profile_images/profile_<uid>.jpg`, while `storage.rules` compares the whole filename wildcard to the raw UID; authenticated uploads are therefore denied.
6. Google photo URLs containing `key=<GOOGLE_PLACES_API_KEY>` are written into `/places` documents.
7. `AppConfig.maxPlacesLimit` is 50, but Nearby Search New must be validated against the provider's current accepted request limit before live use; tests currently encode the same potentially invalid assumption.
8. The Gemini model is hardcoded as `gemini-1.5-flash`; model availability must not be assumed for the current API account.
9. There are no direct tests for `GroupRepository.recordSwipeInSession` or Firebase security rules.
10. Firebase rules deployment/project selection is not pinned through `.firebaserc`; any deployment must require explicit project confirmation.
11. The existing automated tests use mocked HTTP/Fake Firestore and do not prove that real Firebase rules or real credentials work.

---

### Task 1: Establish a Non-Mutating Firebase/API Review Baseline

**Objective:** Produce a scoped review artifact and identify all currently changed files that participate in Firebase, Firestore, Storage, Places, Gemini, and group-session data flow.

**Files:**
- Inspect: `AGENTS.md`
- Inspect: `PROJECT_CONTEXT_INDEX.md`
- Inspect: `PROJECT_ARCHITECTURE_CANONICAL.md`
- Inspect: `PROJECT_LOGIC_MAP.md`
- Inspect: `PROJECT_REFRESH_PLAYBOOK.md`
- Inspect: `firebase.json`
- Inspect: `firestore.rules`
- Inspect: `storage.rules`
- Inspect: `lib/firebase_options.dart`
- Inspect: `lib/core/config/env.dart`
- Inspect: `lib/core/config/app_config.dart`
- Inspect: `lib/features/swipe/data/places_repository.dart`
- Inspect: `lib/features/group/data/group_repository.dart`
- Inspect: `lib/common/models/place_model.dart`
- Inspect: `lib/common/models/group_model.dart`
- Inspect: `lib/common/models/group_session_model.dart`
- Inspect: `lib/common/models/session_vote_model.dart`
- Create through workflow: `docs/testing/firebase-api-baseline-review.md`

**Step 1: Run the deep scoped review**

Run GPT Terra with `gsd-code-review --depth=deep` and explicitly scope the files above. Do not use `--fix` during this baseline pass.

**Step 2: Map every persisted collection**

The review must account for:

```text
/users/{uid}
/places/{placeId}
/swipeResults/{uid_placeId}
/groups/{groupId}
/groups/{groupId}/sessions/{sessionId}
/groups/{groupId}/sessions/{sessionId}/votes/{placeId}
/groups/{groupId}/sessions/{sessionId}/userSwipes/{uid}
/profile_images/{filename}  (Storage)
```

**Step 3: Record rule-to-model mismatches**

For each path, list:

- allowed reader/writer;
- expected fields;
- code method that reads/writes it;
- required Firestore query indexes;
- emulator test that will prove access is allowed or denied.

**Step 4: Verify baseline without changing code**

Run:

```bash
/Users/ozanermis/flutter/bin/flutter analyze
/Users/ozanermis/flutter/bin/flutter test
```

Expected: record exact current results. Do not fix yet. If either command fails, preserve the first actionable error in the review artifact.

**Step 5: Independent review**

GPT Terra reviews the baseline report for omitted paths, incorrect field names, and ungrounded claims.

**Commit:** No commit for this inspection-only task unless the generated review artifact is intentionally tracked and the user approves it.

---

### Task 2: Make Environment Configuration Explicit and Testable

**Objective:** Define the local-demo environment contract without reading, logging, or committing real credentials.

**Files:**
- Create: `.env.example`
- Modify: `.gitignore`
- Modify: `lib/core/config/env.dart`
- Modify: `lib/core/config/app_config.dart`
- Create: `test/env_config_test.dart`

**Step 1: Write failing environment tests**

Add tests using `dotenv.loadFromString`, never the real `.env` file:

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileapp/core/config/env.dart';

void main() {
  test('demo config reports both required API keys', () {
    dotenv.loadFromString(envString: '''
GOOGLE_PLACES_API_KEY=places-test-key
GEMINI_API_KEY=gemini-test-key
GEMINI_MODEL=gemini-test-model
''');

    expect(Env.missingDemoVariables, isEmpty);
    expect(Env.geminiModel, 'gemini-test-model');
  });

  test('demo config reports missing variables without exposing values', () {
    dotenv.loadFromString(envString: 'GOOGLE_PLACES_API_KEY=');

    expect(
      Env.missingDemoVariables,
      containsAll(['GOOGLE_PLACES_API_KEY', 'GEMINI_API_KEY']),
    );
  });
}
```

**Step 2: Run the test and verify RED**

Run:

```bash
/Users/ozanermis/flutter/bin/flutter test test/env_config_test.dart
```

Expected: FAIL because `missingDemoVariables` and `geminiModel` do not exist.

**Step 3: Add the minimal environment contract**

Implement in `lib/core/config/env.dart`:

```dart
class Env {
  static Future<void> init() => dotenv.load(fileName: '.env');

  static String get googlePlacesApiKey =>
      dotenv.env['GOOGLE_PLACES_API_KEY']?.trim() ?? '';

  static String get geminiApiKey =>
      dotenv.env['GEMINI_API_KEY']?.trim() ?? '';

  static String get geminiModel {
    final configured = dotenv.env['GEMINI_MODEL']?.trim() ?? '';
    return configured.isEmpty ? 'gemini-2.5-flash' : configured;
  }

  static List<String> get missingDemoVariables => <String>[
        if (googlePlacesApiKey.isEmpty) 'GOOGLE_PLACES_API_KEY',
        if (geminiApiKey.isEmpty) 'GEMINI_API_KEY',
      ];
}
```

The default Gemini model is a configuration fallback, not proof of provider availability. The live preflight task must verify the configured model before the final readiness claim.

**Step 4: Create a non-secret example file**

`.env.example`:

```dotenv
GOOGLE_PLACES_API_KEY=
GEMINI_API_KEY=
GEMINI_MODEL=gemini-2.5-flash
```

Add this exception after the existing `.env*` ignore rule:

```gitignore
!.env.example
```

**Step 5: Keep real calls explicit**

Retain `AppConfig.enableRealPlacesAPI`, but make the demo intent clear. Do not let tests leak changes to this mutable static between cases; restore its previous value in `tearDown`.

**Step 6: Verify GREEN**

Run:

```bash
/Users/ozanermis/flutter/bin/flutter test test/env_config_test.dart
/Users/ozanermis/flutter/bin/flutter analyze
```

Expected: both commands exit 0.

**Step 7: Review**

Use `requesting-code-review`; GPT Terra verifies that no credential values, `.env` contents, or key-shaped test strings were committed.

**Commit:**

```bash
git add .env.example .gitignore lib/core/config/env.dart lib/core/config/app_config.dart test/env_config_test.dart
git commit -m "test: define local demo environment contract"
```

Only commit if these paths contain no inseparable pre-existing user changes.

---

### Task 3: Align the Places API Contract With Provider Limits

**Objective:** Prevent invalid Nearby Search requests and make provider assumptions executable tests.

**Files:**
- Modify: `lib/core/config/app_config.dart`
- Modify: `lib/features/swipe/data/places_repository.dart`
- Modify: `test/places_api_migration_test.dart`
- Modify: `test/places_api_stress_test.dart`

**Step 1: Confirm current provider documentation**

Before editing, check the current official Google Places API New Nearby Search documentation for:

- accepted `maxResultCount` range;
- allowed use of `includedTypes` and `excludedTypes` together;
- field-mask spelling;
- photo media resource URL format.

Record the checked documentation URL and access date in the implementation notes. Do not rely solely on historical project Markdown.

**Step 2: Write/update the failing limit test**

Replace the existing expectation that a request of 1000 produces `maxResultCount == 50` with the current provider maximum. If the official maximum remains 20, use:

```dart
expect(body['maxResultCount'], equals(20));
expect(result.length, lessThanOrEqualTo(20));
```

Also add cases for limits `0`, `1`, the provider maximum, and above the provider maximum.

**Step 3: Run targeted tests and verify RED**

Run:

```bash
/Users/ozanermis/flutter/bin/flutter test test/places_api_stress_test.dart
```

Expected: FAIL against the old `AppConfig.maxPlacesLimit` or response handling.

**Step 4: Implement the provider limit**

Set `AppConfig.maxPlacesLimit` to the documented provider maximum and clamp both request and returned results consistently.

Prefer:

```dart
final restrictedLimit = limit.clamp(1, AppConfig.maxPlacesLimit);
```

Keep the early return for `limit <= 0`.

**Step 5: Validate request shape**

Ensure tests assert:

- endpoint is `https://places.googleapis.com/v1/places:searchNearby`;
- key is in `X-Goog-Api-Key`, not request JSON;
- field mask contains only fields consumed by the app;
- no real network call occurs in automated tests;
- error responses do not print credential-bearing URLs.

**Step 6: Verify GREEN**

Run:

```bash
/Users/ozanermis/flutter/bin/flutter test test/places_api_migration_test.dart
/Users/ozanermis/flutter/bin/flutter test test/places_api_stress_test.dart
/Users/ozanermis/flutter/bin/flutter analyze
```

Expected: all exit 0.

**Step 7: Review**

GPT Terra reviews the contract against the official docs and checks test isolation for `AppConfig.enableRealPlacesAPI`.

**Commit:**

```bash
git add lib/core/config/app_config.dart lib/features/swipe/data/places_repository.dart test/places_api_migration_test.dart test/places_api_stress_test.dart
git commit -m "fix: align Places requests with provider contract"
```

---

### Task 4: Stop Persisting the Google Places Key in Firestore

**Objective:** Store stable Google photo resource names in `/places` instead of key-bearing media URLs, while preserving backward compatibility for existing cached documents.

**Files:**
- Modify: `lib/common/models/place_model.dart`
- Modify: `lib/features/swipe/data/places_repository.dart`
- Create: `lib/features/places/data/place_photo_url_builder.dart`
- Create: `test/place_photo_storage_test.dart`
- Modify affected image consumers only if required by the chosen clean boundary:
  - `lib/common/widgets/place_card.dart`
  - `lib/features/home/ui/favorites_screen.dart`
  - `lib/features/home/ui/simplified_home_screen.dart`
  - `lib/features/places/ui/place_detail_screen.dart`
  - `lib/features/group/ui/group_matches_screen.dart`

**Step 1: Write failing serialization tests**

Test that Firestore serialization does not contain `key=` or either API key:

```dart
test('PlaceModel cache serialization never stores credential-bearing URLs', () {
  const place = PlaceModel(
    id: 'google-place-id',
    name: 'Demo Place',
    lat: 1,
    lng: 2,
    photoResourceNames: [
      'places/google-place-id/photos/photo-1',
    ],
  );

  final json = place.toJson();
  expect(json['photoResourceNames'], isNotEmpty);
  expect(json.toString(), isNot(contains('key=')));
});
```

Add a backward-compatibility test for old `imageUrls` documents.

**Step 2: Run test and verify RED**

Run:

```bash
/Users/ozanermis/flutter/bin/flutter test test/place_photo_storage_test.dart
```

Expected: FAIL because `photoResourceNames` does not exist.

**Step 3: Extend the model minimally**

Add `photoResourceNames` to `PlaceModel`, parse it from Firestore, and include it in `copyWith`/`toJson`. Preserve old `imageUrls` reads during migration.

**Step 4: Add one URL-building boundary**

Create a focused helper:

```dart
class PlacePhotoUrlBuilder {
  const PlacePhotoUrlBuilder({required this.apiKey});

  final String apiKey;

  String build(String resourceName, {int maxWidthPx = 800}) {
    final encodedName = resourceName.split('/').map(Uri.encodeComponent).join('/');
    return Uri.https(
      'places.googleapis.com',
      '/v1/$encodedName/media',
      <String, String>{
        'maxWidthPx': '$maxWidthPx',
        'key': apiKey,
      },
    ).toString();
  }
}
```

Do not log or persist its output.

**Step 5: Cache resource names, not URLs**

In `PlacesRepository.fetchAndCachePlacesForCity`, write `photoResourceNames: [photoName]` and omit credential-bearing URLs from Firestore serialization.

**Step 6: Resolve image URLs only at display/runtime boundary**

Use one shared provider/helper to map resource names to display URLs. Avoid importing `Env` directly into `PlaceModel`.

**Step 7: Verify GREEN and scan persisted payloads**

Run:

```bash
/Users/ozanermis/flutter/bin/flutter test test/place_photo_storage_test.dart
/Users/ozanermis/flutter/bin/flutter test test/places_api_migration_test.dart
/Users/ozanermis/flutter/bin/flutter analyze
git diff | grep -n "key=" || true
```

Expected: tests/analyzer pass. Any `key=` match must be limited to runtime URL construction or explicit test assertions, never persisted model JSON.

**Step 8: Review**

Use `gsd-secure-phase` and `requesting-code-review`; GPT Terra checks that no Firestore write path receives credential-bearing image URLs.

**Commit:** Stage only the exact changed model/repository/helper/consumer/test files and commit:

```bash
git commit -m "security: keep Places keys out of cached documents"
```

---

### Task 5: Add City Cache Metadata to Prevent Repeated Billable Misses

**Objective:** Prevent the app from repeatedly calling Places for a city that legitimately returns fewer places than requested.

**Files:**
- Create: `lib/common/models/place_cache_metadata.dart`
- Modify: `lib/features/swipe/data/places_repository.dart`
- Modify: `test/places_api_migration_test.dart`
- Modify: `test/places_api_stress_test.dart`
- Update later in Task 7: `firestore.rules`

**Step 1: Write failing cache-exhaustion tests**

Test this sequence:

1. Request 20 places.
2. Provider returns 7.
3. Repository writes 7 places and metadata indicating the provider result is exhausted for that fetch window.
4. A second request for 20 returns the cached 7 without a second HTTP call.

Use a metadata path such as:

```text
/placeCacheMetadata/{countryCode_cityId}
```

Suggested shape:

```json
{
  "cityId": "fr_paris",
  "fetchedCount": 7,
  "requestedLimit": 20,
  "isExhausted": true,
  "lastSyncedAt": "timestamp",
  "schemaVersion": 1
}
```

**Step 2: Run targeted test and verify RED**

Run:

```bash
/Users/ozanermis/flutter/bin/flutter test test/places_api_migration_test.dart --plain-name "does not repeat an exhausted city cache miss"
```

Expected: FAIL because the second call currently calls the API again.

**Step 3: Implement minimal metadata logic**

- Check cached places first.
- Read metadata only when cached count is below the requested limit.
- Skip a new API call when metadata says the previous provider result was exhausted and the cache is still consistent.
- Update metadata in the same batch as place cache writes where practical.
- Do not mark transient HTTP failures as exhausted.

**Step 4: Add malformed/stale metadata tests**

Cover:

- missing metadata;
- malformed metadata;
- exhausted metadata;
- non-exhausted metadata;
- API failure does not poison metadata;
- city A metadata never affects city B.

**Step 5: Verify GREEN**

Run all Places tests and analyzer.

**Step 6: Review**

GPT Terra checks billing-loop prevention and city-isolation invariants.

**Commit:**

```bash
git add lib/common/models/place_cache_metadata.dart lib/features/swipe/data/places_repository.dart test/places_api_migration_test.dart test/places_api_stress_test.dart
git commit -m "fix: prevent repeated exhausted city fetches"
```

---

### Task 6: Make GroupRepository Testable and Lock Down Session Invariants

**Objective:** Add direct tests for group session creation, voting, duplicate prevention, progress, and completion before changing rules.

**Files:**
- Modify: `lib/features/group/data/group_repository.dart`
- Create: `test/group_repository_session_test.dart`
- Optional test helper: `test/helpers/group_fixtures.dart`

**Step 1: Inject Firestore without changing production behavior**

Change the repository constructor from a hardcoded `FirebaseFirestore.instance` field to:

```dart
class GroupRepository {
  GroupRepository(
    this._firestoreService, {
    FirebaseFirestore? firestore,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  final FirestoreService _firestoreService;
  final FirebaseFirestore _db;
}
```

If `FirestoreService` also needs injection consistency, add a constructor accepting the same Firestore instance rather than allowing repository/service instances to point at different databases.

**Step 2: Write failing transaction tests**

Using `FakeFirebaseFirestore`, cover:

- session creation freezes participants and `placePool`;
- nonparticipant vote throws;
- first vote creates `votes/{placeId}` and `userSwipes/{uid}`;
- duplicate vote does not increment progress twice;
- changing a duplicate vote from dislike to like updates arrays/counts without extra progress;
- all participants reaching the limit sets `status: completed`;
- completion clears group `activeSessionId` and sets `hasCompletedSession: true`;
- manual end writes `endedAt`/`endedByUid` and clears active session;
- transaction failure does not leave partial vote/progress state.

**Step 3: Run test and verify RED**

Run:

```bash
/Users/ozanermis/flutter/bin/flutter test test/group_repository_session_test.dart
```

Expected: initial compile/setup failure until Firestore injection and fixtures exist; any behavioral failures must be investigated rather than weakening assertions.

**Step 4: Apply only minimal correctness fixes**

Do not redesign the transaction. Preserve atomic writes. Fix only failures demonstrated by tests.

Important invariant:

```text
likes == likedBy.length
dislikes == dislikedBy.length
likedBy and dislikedBy are disjoint
progress increments once per user/place
completion occurs only when every frozen participant reaches the frozen limit
```

**Step 5: Verify GREEN**

Run:

```bash
/Users/ozanermis/flutter/bin/flutter test test/group_repository_session_test.dart
/Users/ozanermis/flutter/bin/flutter analyze
```

**Step 6: Independent review**

GPT Terra performs a focused concurrency/data-integrity review of `recordSwipeInSession` and the new tests.

**Commit:**

```bash
git add lib/features/group/data/group_repository.dart test/group_repository_session_test.dart test/helpers/group_fixtures.dart
git commit -m "test: protect group session transaction invariants"
```

Omit nonexistent optional paths from `git add`.

---

### Task 7: Rewrite Firestore Rules to Match the Actual Schema

**Objective:** Make every current app read/write path explicitly authorized, deny cross-user writes, and align rule field names with current models.

**Files:**
- Modify: `firestore.rules`
- Create: `firestore.indexes.json`
- Create: `package.json`
- Create: `test/firebase/firestore.rules.test.mjs`
- Modify if needed: `firebase.json`

**Step 1: Add Firebase rules-test tooling**

Use a minimal package file:

```json
{
  "private": true,
  "type": "module",
  "scripts": {
    "test:firestore-rules": "firebase emulators:exec --only firestore 'node --test test/firebase/firestore.rules.test.mjs'"
  },
  "devDependencies": {
    "@firebase/rules-unit-testing": "latest",
    "firebase": "latest"
  }
}
```

Pin exact resolved versions in the lockfile after installation; do not leave an unreviewed floating dependency in the final committed lock.

**Step 2: Write RED rules tests first**

Rules tests must prove at least:

- unauthenticated users cannot read/write app data;
- a user can read/write only their own `/users/{uid}` document, except any intentionally retained authenticated profile-read behavior needed for group member names;
- authenticated users can read `/places`;
- authenticated demo clients can write only valid place/cache metadata documents;
- a user can create/read/update/delete only their own `/swipeResults/{uid_placeId}` documents;
- group owner can create a group and start/end a session;
- invite join adds only the authenticated user's UID and cannot alter unrelated fields;
- a nonmember cannot read sessions/votes/userSwipes;
- a participant can create/update a valid vote document;
- vote counts match membership-array lengths and liked/disliked arrays do not both contain the same authenticated UID;
- a participant can write only `/userSwipes/{theirUid}`;
- member session progress updates use current fields;
- nonowners cannot arbitrarily change `ownerUid`, location, invite, or session participant pool;
- invalid old vote fields (`upvotes`, `downvotes`, `votedUsers`) are rejected.

**Step 3: Run tests and verify RED**

Run:

```bash
npm install
npm run test:firestore-rules
```

Expected: multiple failures against current rules, especially `/places`, `/swipeResults`, `/userSwipes`, and current vote fields.

**Step 4: Implement schema helpers**

Use focused helpers such as:

```javascript
function signedIn() {
  return request.auth != null;
}

function groupDoc(groupId) {
  return get(/databases/$(database)/documents/groups/$(groupId));
}

function isGroupMember(groupId) {
  return signedIn() && request.auth.uid in groupDoc(groupId).data.members;
}

function isGroupOwner(groupId) {
  return signedIn() && request.auth.uid == groupDoc(groupId).data.ownerUid;
}
```

Define explicit field allowlists for `places`, cache metadata, sessions, votes, and user swipes. Avoid a blanket `allow write: if isAuthenticated()`.

**Step 5: Cover all top-level collections**

The final rules must contain explicit matches for:

```text
/users/{uid}
/places/{placeId}
/placeCacheMetadata/{cityId}
/swipeResults/{resultId}
/groups/{groupId}
/groups/{groupId}/sessions/{sessionId}
/groups/{groupId}/sessions/{sessionId}/votes/{placeId}
/groups/{groupId}/sessions/{sessionId}/userSwipes/{uid}
```

**Step 6: Preserve transaction viability**

Rules must authorize every write in `recordSwipeInSession` as one atomic request:

- vote document create/update;
- user swipe document merge;
- session progress update;
- optional session completion update;
- optional group active-session cleanup.

Use `getAfter()` where needed to validate cross-document completion state. If strict cross-document validation makes the client transaction impossible, do not weaken rules silently; document the limitation and keep the narrowest rule that supports this local demo.

**Step 7: Create required indexes**

At minimum evaluate and encode indexes for current queries:

```json
{
  "indexes": [
    {
      "collectionGroup": "swipeResults",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "userId", "order": "ASCENDING"},
        {"fieldPath": "timestamp", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "swipeResults",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "userId", "order": "ASCENDING"},
        {"fieldPath": "liked", "order": "ASCENDING"}
      ]
    }
  ],
  "fieldOverrides": []
}
```

Only add indexes required by actual queries. Validate the final JSON with Firebase tooling.

**Step 8: Run rules tests and verify GREEN**

Run the one canonical package script:

```bash
npm run test:firestore-rules
```

The package script already invokes `firebase emulators:exec`; do not wrap it in a second emulator command.

Expected: all allow/deny tests pass.

**Step 9: Security review**

Run `gsd-secure-phase`. GPT Terra must specifically review:

- cache poisoning risk from authenticated client writes;
- invite-code/member-update constraints;
- vote tampering constraints;
- cross-user `userSwipes` access;
- session completion/group cleanup authorization;
- whether `/users` read visibility is broader than the demo requires.

**Commit:**

```bash
git add firestore.rules firestore.indexes.json firebase.json package.json package-lock.json test/firebase/firestore.rules.test.mjs
git commit -m "security: align Firestore rules with current data model"
```

---

### Task 8: Align Firebase Storage Paths and Rules

**Objective:** Make profile-image upload/delete work for the authenticated user and deny cross-user writes.

**Files:**
- Modify: `lib/features/profile/data/image_service.dart`
- Modify: `storage.rules`
- Create: `test/firebase/storage.rules.test.mjs`
- Modify: `package.json`

**Step 1: Write RED Storage rules tests**

Prove:

- unauthenticated upload is denied;
- user A can upload/delete user A's image;
- user A cannot upload/delete user B's image;
- invalid content type is denied;
- oversized files are denied;
- reads follow the chosen demo policy.

**Step 2: Choose one canonical object path**

Prefer a path whose UID occupies a complete Storage Rules segment:

```text
/profile_images/{uid}/profile.jpg
```

Update `ImageService`:

```dart
final ref =
    _storage.ref().child('profile_images/$userId/profile.jpg');
```

**Step 3: Tighten Storage rules**

Use:

```javascript
match /profile_images/{userId}/profile.jpg {
  allow read: if true;
  allow write: if request.auth != null
               && request.auth.uid == userId
               && request.resource.size < 5 * 1024 * 1024
               && request.resource.contentType.matches('image/.*');
  allow delete: if request.auth != null && request.auth.uid == userId;
}
```

**Step 4: Handle existing `profile_<uid>.jpg` URLs**

For local demo, document whether old objects should be deleted manually. Do not add a broad backward-compatible write rule. Existing stored download URLs can continue to render until the profile image is replaced.

**Step 5: Run Storage emulator tests**

Add a canonical script such as:

```json
"test:storage-rules": "firebase emulators:exec --only storage 'node --test test/firebase/storage.rules.test.mjs'"
```

Expected: all tests pass.

**Step 6: Run Dart verification**

```bash
/Users/ozanermis/flutter/bin/flutter analyze
/Users/ozanermis/flutter/bin/flutter test
```

**Step 7: Review**

GPT Terra checks object ownership, type/size validation, and delete behavior.

**Commit:**

```bash
git add lib/features/profile/data/image_service.dart storage.rules package.json package-lock.json test/firebase/storage.rules.test.mjs
git commit -m "fix: align profile image paths with Storage rules"
```

---

### Task 9: Add a Safe API Preflight Without Automatic Billing

**Objective:** Verify key validity, API enablement, and Gemini model availability only when the user explicitly opts into a live check.

**Files:**
- Create: `tool/api_preflight.dart`
- Create: `test/api_preflight_test.dart`
- Modify: `README.md` or create `docs/testing/local-demo-api-preflight.md`

**Step 1: Design the preflight interface**

The command must:

- load `.env` without printing values;
- fail early with missing variable names only;
- require an explicit flag such as `--allow-billable-request` before calling Places;
- make at most one Places request with the minimum accepted result count;
- verify the configured Gemini model with one minimal request or a nonbillable model-list endpoint if available;
- redact keys from all exceptions and logs;
- never write key-bearing URLs to Firestore.

**Step 2: Write mock-client tests first**

Test missing keys, denied billable mode, valid Places response, 403 API-disabled response, 429 quota response, invalid Gemini model, and redaction.

**Step 3: Run tests and verify RED**

```bash
/Users/ozanermis/flutter/bin/flutter test test/api_preflight_test.dart
```

**Step 4: Implement with injected HTTP client**

Keep network logic separate from CLI argument parsing so all automated tests remain offline.

**Step 5: Verify tests GREEN**

Run targeted test and analyzer.

**Step 6: Live check gate**

After the user has populated `.env`, ask for explicit confirmation immediately before running:

```bash
/Users/ozanermis/flutter/bin/dart run tool/api_preflight.dart --allow-billable-request
```

Expected success output must contain only statuses, for example:

```text
Environment: OK
Google Places API: OK (1 result)
Gemini model: OK
No credential values were printed.
```

Do not fabricate this output if the user declines or the network/API fails.

**Step 7: Review**

GPT Terra verifies billing cap and credential redaction.

**Commit:**

```bash
git add tool/api_preflight.dart test/api_preflight_test.dart docs/testing/local-demo-api-preflight.md
git commit -m "test: add opt-in live API preflight"
```

---

### Task 10: Verify the Complete Firebase Data Flow in Emulators

**Objective:** Prove that repository writes accepted by code are also accepted by the actual security rules.

**Files:**
- Create: `integration_test/firebase_demo_flow_test.dart`
- Create if needed: `lib/main_demo_test.dart`
- Modify: `pubspec.yaml` to add `integration_test` as an SDK dev dependency
- Modify: `firebase.json` for emulator ports only if absent and needed

**Step 1: Add integration-test dependency**

Use the Flutter SDK dependency:

```yaml
dev_dependencies:
  integration_test:
    sdk: flutter
```

**Step 2: Write the flow test**

Use test accounts and emulator endpoints. Cover:

1. register/login two users;
2. create user documents;
3. create a group as user A;
4. join as user B with invite code;
5. create/cache a fake place document under emulator rules;
6. start a session with both users;
7. cast votes from each user;
8. confirm vote counts and per-user progress;
9. confirm session completion and group cleanup;
10. confirm matches query can read completed votes;
11. confirm cross-user forbidden writes fail.

Do not call real Places or Gemini APIs in this test.

**Step 3: Run RED against current integration setup**

Expected: initial failure until Auth/Firestore emulator wiring and keys are complete.

**Step 4: Wire emulator-only initialization**

Use a dedicated test entry point; do not make production `main.dart` unconditionally connect to emulators.

**Step 5: Run GREEN**

Example command, adjusted to the available simulator/device:

```bash
firebase emulators:exec --only auth,firestore,storage \
  "/Users/ozanermis/flutter/bin/flutter test integration_test/firebase_demo_flow_test.dart"
```

Expected: all flow assertions pass and emulator logs show no permission-denied writes.

**Step 6: Review**

GPT Terra checks that the integration test exercises rules rather than bypassing them and that no real project data is touched.

**Commit:**

```bash
git add pubspec.yaml pubspec.lock firebase.json integration_test/firebase_demo_flow_test.dart lib/main_demo_test.dart
git commit -m "test: cover Firebase demo flow in emulators"
```

Omit optional nonexistent files from staging.

---

### Task 11: Deploy Rules and Indexes to the Intended Firebase Project

**Objective:** Apply the verified rules/indexes only after explicit project confirmation.

**Files:**
- Optional create: `.firebaserc`
- Use: `firebase.json`
- Use: `firestore.rules`
- Use: `firestore.indexes.json`
- Use: `storage.rules`

**Step 1: Confirm target project**

The inspected configuration references project ID:

```text
travelapp-31255
```

Before any deployment, show the active Firebase account and project and ask the user to confirm. This is a mandatory side-effect gate.

**Step 2: Validate locally**

Run all rules and emulator tests again. Do not deploy on failure.

**Step 3: Preview project selection**

Run read-only Firebase project/account commands. Do not expose tokens.

**Step 4: Deploy narrowly after confirmation**

```bash
firebase deploy \
  --project travelapp-31255 \
  --only firestore:rules,firestore:indexes,storage
```

If the installed CLI requires separate targets, run them separately and capture each exit status.

**Step 5: Verify deployed behavior**

Use the Firebase console or a minimal authenticated app smoke test to confirm:

- place cache read/write succeeds;
- swipe result write succeeds;
- group join succeeds;
- session vote/userSwipes/progress transaction succeeds;
- profile image upload succeeds.

**Step 6: Report exact deployment result**

Include project ID, commands, exit statuses, and any index build status. Do not claim readiness while required indexes are still building if the demo path depends on them.

**Commit:** If `.firebaserc` is intentionally created and approved:

```bash
git add .firebaserc
git commit -m "chore: pin Firebase demo project alias"
```

---

### Task 12: Run the Real-Key iOS Simulator Demo Gate

**Objective:** Prove the requested local simulator/demo experience with real keys and the verified Firebase project.

**Files:**
- Do not commit: `.env`
- Create/update evidence: `docs/testing/firebase-api-demo-readiness.md`

**Step 1: User populates `.env`**

Required names:

```dotenv
GOOGLE_PLACES_API_KEY=<user-provided>
GEMINI_API_KEY=<user-provided>
GEMINI_MODEL=<verified-supported-model>
```

Never request the values in chat and never print them.

**Step 2: Run complete static/unit/rules gates**

```bash
/Users/ozanermis/flutter/bin/flutter pub get
/Users/ozanermis/flutter/bin/flutter analyze
/Users/ozanermis/flutter/bin/flutter test
npm run test:firestore-rules
npm run test:storage-rules
```

Expected: every command exits 0.

**Step 3: Run opt-in API preflight**

After explicit billable-request confirmation, run the preflight from Task 9.

Expected: Places key/API and configured Gemini model both pass.

**Step 4: Launch the iOS simulator**

Run the app using the repository's known Flutter binary. Capture the selected simulator/device and launch result.

**Step 5: Manual/automated smoke checklist**

Verify in order:

- app initializes Env before Firebase;
- user can register/login;
- first city cache miss calls Places once;
- returned places use real Google Place IDs;
- descriptions are generated when Gemini succeeds and remain usable when Gemini fails;
- `/places` documents contain no API key query values;
- second request for the same city hits cache;
- favorites and solo swipe results persist;
- group A can be created;
- group B user can join by invite code;
- group session freezes both participants and a real place pool;
- both users can vote without permission errors;
- duplicate vote does not increment progress twice;
- session completes and group `activeSessionId` clears;
- completed matches can be read;
- profile image upload/delete succeeds if included in the demo.

**Step 6: Capture evidence without secrets**

Create `docs/testing/firebase-api-demo-readiness.md` containing:

- command names and exit codes;
- simulator/device used;
- Firebase project ID;
- collection paths observed;
- counts/statuses, not credential values;
- any skipped smoke step and reason;
- final PASS/FAIL per readiness gate.

**Step 7: Final independent review**

Run `requesting-code-review` with GPT Terra. The reviewer must compare the implementation and evidence against this plan and return:

- critical blockers;
- security findings;
- data-integrity findings;
- test gaps;
- final local-demo readiness verdict.

**Step 8: Final commit**

Only after all gates pass and the user approves the current diff:

```bash
git add docs/testing/firebase-api-demo-readiness.md
git commit -m "docs: record Firebase API demo readiness"
```

Do not use `git add -A` in this dirty repository.

---

## Final Verification Matrix

| Gate | Command/evidence | Required result |
|---|---|---|
| Dart analyzer | `/Users/ozanermis/flutter/bin/flutter analyze` | Exit 0, no issues |
| Flutter unit/widget tests | `/Users/ozanermis/flutter/bin/flutter test` | All pass |
| Places contract tests | targeted migration/stress tests | All pass, no real calls |
| Group transaction tests | `test/group_repository_session_test.dart` | All invariants pass |
| Firestore rules | Firebase Emulator Suite rules tests | All allow/deny cases pass |
| Storage rules | Firebase Emulator Suite rules tests | Ownership/type/size cases pass |
| Firebase integration | emulator demo-flow test | End-to-end session completes |
| Live Places | opt-in preflight | Valid key/API, one capped request |
| Live Gemini | opt-in preflight | Configured model accepted |
| Firestore cache | simulator evidence | No key-bearing stored URLs |
| Real Firebase rules | post-deploy smoke | No permission-denied core writes |
| iOS demo | simulator checklist | All required user flows pass |
| Independent review | GPT Terra verdict | No critical/security/data-integrity blockers |

## Risks and Tradeoffs

- Client-side Places/Gemini keys remain extractable from a Flutter build even after removing them from Firestore. This is accepted only for the local-demo scope; restrict keys by API and app where supported.
- Allowing authenticated clients to populate `/places` is vulnerable to cache poisoning. Strict field validation reduces but does not eliminate this. A trusted backend proxy is the production fix and remains out of scope.
- Firestore rules for a multi-document client transaction are complex. Emulator tests are mandatory because Fake Firestore does not enforce rules.
- Existing cached documents may contain credential-bearing photo URLs. Before a real demo, delete or migrate those documents and rotate the key if it was exposed.
- Existing dirty changes make broad commits unsafe. All staging must remain path-scoped.
- A configured Gemini model may be unavailable for the user's API account. The preflight result, not the default string, determines readiness.
- Firebase index deployment may be asynchronous. The demo cannot be called ready until required indexes are active.

## Definition of Done

The project is ready for the requested local simulator demo only when:

1. All static, Flutter, group transaction, Firestore rules, Storage rules, and emulator integration tests pass.
2. Rules/indexes are deployed to the explicitly confirmed Firebase project.
3. The user-provided Places and Gemini credentials pass the opt-in preflight.
4. Real Places data is cached by city using real place IDs without storing API keys.
5. Group creation, invite join, session start, multiuser voting, progress, completion, and matches work under deployed rules.
6. The iOS simulator smoke checklist passes with evidence.
7. GPT Terra's independent final review reports no critical, security, or data-integrity blockers.

Until all seven conditions pass, the correct status is **not yet demo-ready**, even if `.env` contains valid keys.
