# Possible Errors and Known Risks

Findings from a full-project audit on **2026-09-02** (branch `stabilization`).
Six parallel scans covered security, the data layer, external APIs, state and
navigation, UI and architecture compliance, and tests and tooling.

Every entry below was confirmed by reading the code, not inferred from docs.
Where a claim could not be verified, it says so.

Status legend: **FIXED** = fixed on this branch · **OPEN** = still present ·
**BLOCKED** = fix written but not yet deployed.

---

## 0. Read this first: nothing backend is live yet

The Firestore rules, indexes, Storage rules and Cloud Functions in this repo
are **not deployed**. Until they are, the app behaves as if none of the fixes
below exist.

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
firebase deploy --only functions   # requires the Blaze plan
```

The Google Places API key in `.env` is a **13-character placeholder**, not a
real key. A live probe returned `HTTP 400 — API key not valid`, which means
real Places calls have never succeeded and the app has been running on data
already seeded in Firestore. There is no Gemini key at all, so place
descriptions have always been `null`.

---

## 1. Critical — would break the app in production

| # | Problem | Where | Status |
|---|---|---|---|
| 1.1 | Firestore rules had **no rules at all** for `/places`, `/placeCacheMetadata`, `/swipeResults` and `sessions/*/userSwipes`. Unmatched paths are denied by default, so the place cache could never be written and solo swiping could never be recorded. | `firestore.rules` | **BLOCKED** (fixed, needs deploy) |
| 1.2 | Vote rule required fields `upvotes` / `downvotes` / `votedUsers`, but the code writes `likes` / `dislikes` / `likedBy` / `dislikedBy`. Zero overlap, so **every vote write was denied**. | `firestore.rules` vs `group_repository.dart:338-353` | **BLOCKED** |
| 1.3 | Session update rule allowed only `progressByUser` and `isCompleted`, but each swipe rewrites the whole session document including `swipeProgress` and `status`. Result: **only the group owner could swipe**. | `firestore.rules` vs `group_repository.dart:382` | **BLOCKED** |
| 1.4 | The release Android manifest declared **no `INTERNET` permission** and no location permission — those existed only in the debug and profile manifests. A release APK would have had no network access at all: no Firebase, no Places, nothing. | `android/app/src/main/AndroidManifest.xml` | **FIXED** |
| 1.5 | `firebase.json` referenced `firestore.indexes.json`, which did not exist. `firebase deploy` would fail outright. | `firebase.json` | **FIXED** |
| 1.6 | The `swipeResults` history query needs a composite index that did not exist. It threw `FAILED_PRECONDITION`, which a `catch` block swallowed, silently clearing swipe history — so **users kept seeing places they had already swiped**. | `places_repository.dart:315-319`, `swipe_controller.dart:61-64` | **FIXED** (index added; needs deploy) |
| 1.7 | Storage rule matched `profile_images/{userId}.jpg` while the client uploaded `profile_images/profile_<uid>.jpg`, so **every profile picture upload was denied**. | `storage.rules` vs `image_service.dart:39` | **FIXED** |
| 1.8 | Nearby Search sent `landmark` and `food` in `includedTypes`/`excludedTypes`. Those are Table B place types, which that field rejects, so the request would fail with `INVALID_ARGUMENT` **even with a valid API key**. Two tests asserted the invalid values, locking the bug in. | `places_repository.dart:78-88` | **FIXED** |
| 1.9 | iOS had no `NSLocationWhenInUseUsageDescription`, so the location request failed on iOS. It also requested microphone access it never uses, and disabled App Transport Security app-wide. | `ios/Runner/Info.plist` | **FIXED** |
| 1.10 | A group session could **never finish** when the swipe limit exceeded the place pool. The UI offers up to 100 swipes and time-limited mode forces 100, but the pool is capped at 20, so the "all members done" condition was unreachable. | `group_controller.dart:257-279` | **FIXED** |

---

## 2. High — security and cost

| # | Problem | Where | Status |
|---|---|---|---|
| 2.1 | **Place Photos are billed per view.** Every card, thumbnail and detail image was requested straight from Google with the API key in the URL, cached only on that one device. Cost scaled with views, not with places — roughly €420/month at 1,000 users. | `place_photo_url_builder.dart:12-21` | **FIXED** (Cloud Function now caches each photo once into Storage) |
| 2.2 | `.env` is declared as a Flutter **asset**, so any key in it ships inside the APK/IPA and can be extracted with an unzip. Harmless today only because the key is a placeholder. | `pubspec.yaml:39-40` | **OPEN** — keys now live in Cloud Function secrets; remove `.env` from assets once the client no longer reads any key |
| 2.3 | The join rule let **any authenticated user append any UIDs to any group** with joining enabled; the invite code was only checked client-side, and codes are enumerable because groups are readable. | `firestore.rules` | **BLOCKED** (now restricted to adding only yourself) |
| 2.4 | Group creation allowed the creator to pre-add arbitrary UIDs, forcing strangers into a group. | `firestore.rules` | **BLOCKED** (now requires members == [creator]) |
| 2.5 | `/users` is readable by every authenticated user, exposing **all emails** and FCM tokens. Nothing currently reads another user's document, so tightening this is safe. | `firestore.rules:19-21` | **OPEN** — needs a `publicProfiles` collection for member names first |
| 2.6 | No **Firebase App Check**. Without it, anyone with the public config can call the backend and the Cloud Function directly. | no `firebase_app_check` dependency | **OPEN** — `enforceAppCheck` is ready to switch on in `functions/index.js` |
| 2.7 | Release builds are signed with the **debug keystore**. Not publishable, and it prevents per-app API key restriction. | `android/app/build.gradle.kts` | **OPEN** |
| 2.8 | Raw exception text is shown to users in ~15 places, leaking Firestore paths and permission-denied internals. | group, profile, swipe and home screens | **OPEN** |
| 2.9 | Place content (names, addresses, photos) was cached **indefinitely**. Google's Places policy allows storing place IDs indefinitely but not content. Not independently verified against the current policy text — worth confirming. | `place_model.dart`, cache metadata | **FIXED** (30-day TTL plus a daily refresh job in the Cloud Function) |

---

## 3. High — performance and read amplification

| # | Problem | Where | Status |
|---|---|---|---|
| 3.1 | `loadNearbyPlaces` reads the **entire `places` collection** and filters in Dart, on every `SwipeController.build()`. `build()` re-runs on every group state change, including loading flips. | `places_repository.dart:252`, `swipe_controller.dart:41,85` | **OPEN** |
| 3.2 | **The worst cascade:** every "like" reads all group members' profiles and writes the group document. That write wakes every member's group stream, which rebuilds their swipe controller, which re-scans the whole `places` collection. One 20-card solo session with a group selected costs roughly **2,200 reads instead of ~50**. | `swipe_controller.dart:278-317` | **OPEN** |
| 3.3 | The session document is rewritten on **every swipe** by every member — about 2 writes/second on one document with 4 members, above Firestore's ~1 write/second guidance. Causes transaction retries, each costing 2 more reads. | `group_repository.dart:382` | **OPEN** |
| 3.4 | Gemini was called **sequentially, once per place** — 20 round trips on the critical path while the admin waits, 20–60 seconds. | `places_repository.dart:117-147` | **FIXED** (one batched call, server-side, off the critical path) |
| 3.5 | `gemini-2.5-flash` reasons internally by default, and those tokens counted against a 60-token output budget, so responses frequently came back empty and were saved as `null`. | `places_repository.dart:221-224` | **FIXED** (`thinkingBudget: 0`, cheaper `flash-lite` model) |
| 3.6 | Loading a session fetches places **one document at a time** (20+ sequential round trips). | `swipe_controller.dart:73-76` | **OPEN** — use a batched `whereIn` query |
| 3.7 | The solo swipe-history query is **unbounded** and grows by one document per swipe forever. | `places_repository.dart:314-329` | **OPEN** — store swiped IDs in one document |
| 3.8 | Every session and vote rule performs a `get()` on the parent group — an extra billed read per operation, up to 3 per swipe. | `firestore.rules` | **OPEN** — partially reduced; can use the denormalised `participants` field |

---

## 4. Medium — correctness

| # | Problem | Where | Status |
|---|---|---|---|
| 4.1 | Favourites are written as a **whole-array overwrite** from an in-memory list, and the profile read swallows errors and returns an empty list. One failed read followed by one like **wipes the user's favourites**. | `swipe_controller.dart:158`, `profile_repository.dart:16-18` | **OPEN** — use `arrayUnion`/`arrayRemove` |
| 4.2 | A parse error on a session document is treated as "session missing", which **clears the active session for every member**, killing a live session. | `group_repository.dart:425-429`, `group_controller.dart:66-76` | **OPEN** |
| 4.3 | `leaveGroup` is a non-transactional read-modify-write, so a concurrent join is lost. If the owner leaves, `ownerUid` points at a non-member and **nobody can start or end sessions again**. | `group_repository.dart:155-177` | **OPEN** |
| 4.4 | `startSwipeSession` never checks for an existing active session, so a double-tap creates **two sessions**, orphaning the first. | `group_repository.dart:209-257` | **OPEN** |
| 4.5 | A place with an empty id became `doc('')`, which throws and **aborts the entire cache batch**. | `places_repository.dart:134` | **FIXED** |
| 4.6 | `toJson` writes explicit `null`s with `merge: true`, so one failed Gemini call **erases a description that was already cached**. | `place_model.dart:78-89` | **OPEN** in the legacy path; **FIXED** in the Cloud Function (nulls omitted) |
| 4.7 | No timeouts on the Places or Gemini HTTP calls — a hang leaves the UI stuck loading forever. | `places_repository.dart:69,207` | **OPEN** in the legacy path; **FIXED** in the Cloud Function |
| 4.8 | City lookup uses the shared geonames `demo` account, which is usually rate-limited, over plaintext HTTP. It almost always falls back to 10 hardcoded cities whose IDs (`1`–`10`) **ignore the selected country**, so `DE_1` resolves to Paris. The same city can be cached under two different keys, causing duplicate paid fetches. | `location_repository.dart:6-7` | **PARTIAL** — switched to HTTPS; still needs a real username and stable cache keys |
| 4.9 | The failing transaction test passed only because the Firestore fake tolerates updating a missing document; real Firestore would reject it. | `group_repository.dart:377` | **FIXED** (group existence now checked inside the transaction) |

---

## 5. Medium — user-facing problems

| # | Problem | Where | Status |
|---|---|---|---|
| 5.1 | **~88 German strings** remain, in the settings, login and register screens — more than the project docs claimed. All UI text is supposed to be English. | `settings_screen.dart`, `login_screen.dart`, `register_screen.dart` | **OPEN** |
| 5.2 | The Impressum shows **placeholder legal identity** ("Musterfirma GmbH", "Max Mustermann", "HRB 12345"), and the privacy dialog claims **end-to-end encryption**, which is false for a Firebase app. Both are a real risk if users see them. | `settings_screen.dart:99-124,214` | **OPEN** — awaiting a decision on real text vs removal |
| 5.3 | Login and register sit **inside the bottom-navigation shell**, so a logged-out user sees the Discover/Groups/Profile tab bar. Confirmed visually on the simulator. | `routes.dart:91-98` | **OPEN** |
| 5.4 | The group member list shows **raw Firebase UIDs** instead of display names. | `simplified_group_screen.dart:630-636` | **OPEN** |
| 5.5 | Dark theme is fully built but **never wired up**, and ~130 hardcoded `Colors.*` values would break it anyway. | `app.dart:13`, `theme.dart` | **OPEN** |
| 5.6 | The city dropdown keeps a stale selected value when the country changes, causing a Flutter assertion in debug and a blank dropdown in release. | `simplified_group_screen.dart:57-71` | **OPEN** |
| 5.7 | Login and register screens have no scroll view, so on a small screen with the keyboard open the layout **overflows**. | `login_screen.dart:53`, `register_screen.dart:38` | **OPEN** |
| 5.8 | A destructive "reset all places and favourites" action sits permanently in the home app bar behind a single confirm. | `simplified_home_screen.dart:18-22` | **OPEN** |
| 5.9 | In a group session the app shows "Added to favorites!" when the like only cast a vote. | `swipe_screen.dart:224-227` | **OPEN** |
| 5.10 | Only 2 icon buttons in the whole app have accessibility labels. | many screens | **OPEN** |

---

## 6. Architecture and maintainability

| # | Problem | Where | Status |
|---|---|---|---|
| 6.1 | **23 cross-feature imports** violate the layer rules. They use relative paths, so the lint hook that checks for `package:` imports never catches them. | `swipe_controller.dart`, `group_controller.dart`, several screens | **OPEN** |
| 6.2 | `PlacesRepository()` and `LocationRepository()` are constructed directly inside controllers and widgets instead of injected via providers, which is why the favourites and like paths have no tests. | `swipe_controller.dart:27`, `group_controller.dart:42` | **OPEN** |
| 6.3 | Providers and data-loading logic live inside UI files. | `group_matches_screen.dart:41-94`, `place_detail_screen.dart:11-15` | **OPEN** |
| 6.4 | The home screen contains a ~400-line **duplicate** of the swipe card stack, which has already drifted from the real one. `PlaceCard` in `common/` is unused. | `simplified_home_screen.dart:176-581` | **OPEN** |
| 6.5 | `analysis_options.yaml` has **zero custom lint rules**. `unawaited_futures` alone would have caught the transaction bug in section 4.9. | `analysis_options.yaml` | **OPEN** |
| 6.6 | Tracked junk in the repo: `lib.rar`, `extract.py`, `extract.dart`. `.gitignore` is missing `*.jks`, `*.keystore`, `android/key.properties`. | repo root | **OPEN** |
| 6.7 | `GroupRepository` has two parallel code paths (injected vs service), so tests exercise a different path than production. | `group_repository.dart:12,19,47,164` | **OPEN** |
| 6.8 | Project docs are stale: `CLAUDE.md` and `mvp_architecture_plan.md` describe a mock-data state that no longer exists, several "open risks" are already fixed, and `2026-07-03-group-swipe-matching-design.md` describes a ranked Borda-count matching design that **was never built** (the app uses simple like-count matching). | `*.md` at repo root | **OPEN** |

---

## 7. Test coverage gaps

50 tests pass and `flutter analyze` reports only one deprecation notice
(`onReorder` in `group_matches_screen.dart:429`). Untested critical paths:

- GoRouter redirect logic (auth, onboarding and active-session gating)
- Favourites add/remove and profile sync
- Solo `like()` / `nextPlace()` behaviour
- `allMembersDone` edge cases (missing participant, null swipe limit)
- `loadNearbyPlaces` radius and tag filtering
- `joinGroupByInvite` failure modes (wrong code, joining disabled, rejoin)
- Firestore **rules** — no emulator test exists, which is why the mismatches
  in section 1 went unnoticed for so long

---

## 8. Firebase registration mismatch

The app ID was changed from `com.example.mobileapp` to `com.swipetrip.app`,
and the Dart package from `mobileapp` to `swipetrip`. The config files were
updated so both platforms build and run — verified on an iOS simulator and an
Android APK build.

The Firebase console, however, still has the app registered under the **old**
ID. Email login and Firestore work regardless, because they identify the
project by API key. But **push notifications, App Check and Google Sign-In
will not work** until the apps are re-registered:

```bash
dart run flutterfire_cli:flutterfire configure
```
