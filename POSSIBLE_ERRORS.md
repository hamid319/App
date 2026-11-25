# Possible Errors and Known Risks

Findings from a full-project audit on **2026-09-02** (branch `stabilization`).
Six parallel scans covered security, the data layer, external APIs, state and
navigation, UI and architecture compliance, and tests and tooling.

Every entry below was confirmed by reading the code, not inferred from docs.
Where a claim could not be verified, it says so.

**Re-checked against the code on 2026-11-21** (`main` at `4c1b936b`): every
OPEN and PARTIAL entry was read again in the current code; statuses below
reflect that check.

Status legend: **FIXED** = fixed · **OPEN** = still present ·
**PARTIAL** = partly fixed · **OBSOLETE** = the code path no longer exists ·
**BLOCKED** = fix written but not yet deployed.

---

## 0. Read this first: backend status

**Deployed on 2026-10-20:** Firestore rules, Firestore indexes and Storage
rules (`firebase deploy --only firestore:rules,firestore:indexes,storage`).
Firebase Storage was set up in the console the same day.

**Update 2026-11-01:** the Google Places Cloud Functions (`getCityPlaces`,
photo caching, Gemini descriptions) were never deployed and are removed, as
is the app's Google Places client path. Place data comes only from
`tools/city-import`. The functions package now holds only the trip push
notifications.

The Google Places API key in `.env` is a **13-character placeholder**, not a
real key. A live probe returned `HTTP 400 — API key not valid`, which means
real Places calls have never succeeded and the app has been running on data
already seeded in Firestore. There is no Gemini key at all, so place
descriptions have always been `null`.

**Update 2026-11-21:** `firebase deploy --only firestore:rules` reported the
rules as already up to date, so the current `firestore.rules` on `main`
(including `/users` owner-only, item 2.5) is live. The `.env` placeholder
above no longer matters: no app code calls Google Places or Gemini directly.

---

## 1. Critical — would break the app in production

| # | Problem | Where | Status |
|---|---|---|---|
| 1.1 | Firestore rules had **no rules at all** for `/places`, `/placeCacheMetadata`, `/swipeResults` and `sessions/*/userSwipes`. Unmatched paths are denied by default, so the place cache could never be written and solo swiping could never be recorded. | `firestore.rules` | **FIXED** (deployed 2026-10-20) |
| 1.2 | Vote rule required fields `upvotes` / `downvotes` / `votedUsers`, but the code writes `likes` / `dislikes` / `likedBy` / `dislikedBy`. Zero overlap, so **every vote write was denied**. | `firestore.rules` vs `group_repository.dart:338-353` | **FIXED** (deployed 2026-10-20) |
| 1.3 | Session update rule allowed only `progressByUser` and `isCompleted`, but each swipe rewrites the whole session document including `swipeProgress` and `status`. Result: **only the group owner could swipe**. | `firestore.rules` vs `group_repository.dart:382` | **FIXED** (deployed 2026-10-20) |
| 1.4 | The release Android manifest declared **no `INTERNET` permission** and no location permission — those existed only in the debug and profile manifests. A release APK would have had no network access at all: no Firebase, no Places, nothing. | `android/app/src/main/AndroidManifest.xml` | **FIXED** |
| 1.5 | `firebase.json` referenced `firestore.indexes.json`, which did not exist. `firebase deploy` would fail outright. | `firebase.json` | **FIXED** |
| 1.6 | The `swipeResults` history query needs a composite index that did not exist. It threw `FAILED_PRECONDITION`, which a `catch` block swallowed, silently clearing swipe history — so **users kept seeing places they had already swiped**. | `places_repository.dart:315-319`, `swipe_controller.dart:61-64` | **FIXED** (index deployed 2026-10-20; favorites no longer cleared when the history query fails) |
| 1.7 | Storage rule matched `profile_images/{userId}.jpg` while the client uploaded `profile_images/profile_<uid>.jpg`, so **every profile picture upload was denied**. | `storage.rules` vs `image_service.dart:39` | **FIXED** |
| 1.8 | Nearby Search sent `landmark` and `food` in `includedTypes`/`excludedTypes`. Those are Table B place types, which that field rejects, so the request would fail with `INVALID_ARGUMENT` **even with a valid API key**. Two tests asserted the invalid values, locking the bug in. | `places_repository.dart:78-88` | **FIXED** |
| 1.9 | iOS had no `NSLocationWhenInUseUsageDescription`, so the location request failed on iOS. It also requested microphone access it never uses, and disabled App Transport Security app-wide. | `ios/Runner/Info.plist` | **FIXED** |
| 1.10 | A group session could **never finish** when the swipe limit exceeded the place pool. The UI offers up to 100 swipes and time-limited mode forces 100, but the pool is capped at 20, so the "all members done" condition was unreachable. | `group_controller.dart:257-279` | **FIXED** |

---

## 2. High — security and cost

| # | Problem | Where | Status |
|---|---|---|---|
| 2.1 | **Place Photos are billed per view.** Every card, thumbnail and detail image was requested straight from Google with the API key in the URL, cached only on that one device. Cost scaled with views, not with places — roughly €420/month at 1,000 users. | `place_photo_url_builder.dart:12-21` | **FIXED** (Cloud Function now caches each photo once into Storage) |
| 2.2 | `.env` is declared as a Flutter **asset**, so any key in it ships inside the APK/IPA and can be extracted with an unzip. Harmless today only because the key is a placeholder. | `pubspec.yaml:39-40` | **FIXED** — `.env` is no longer a Flutter asset (see the comment in `pubspec.yaml`); `Env.init` loads it optionally for local development only |
| 2.3 | The join rule let **any authenticated user append any UIDs to any group** with joining enabled; the invite code was only checked client-side, and codes are enumerable because groups are readable. | `firestore.rules` | **FIXED** (deployed 2026-10-20) (now restricted to adding only yourself) |
| 2.4 | Group creation allowed the creator to pre-add arbitrary UIDs, forcing strangers into a group. | `firestore.rules` | **FIXED** (deployed 2026-10-20) (now requires members == [creator]) |
| 2.5 | `/users` is readable by every authenticated user, exposing **all emails** and FCM tokens. Nothing currently reads another user's document, so tightening this is safe. | `firestore.rules:19-21` | **FIXED** (2026-11-15; deploy confirmed 2026-11-21) — member names, photos and PayPal handles come from `publicProfiles/{uid}`; `/users` is owner-only; old profiles backfilled (`functions/scripts/backfill-public-profiles.js`) |
| 2.6 | No **Firebase App Check**. Without it, anyone with the public config can call the backend and the Cloud Function directly. | no `firebase_app_check` dependency | **PARTIAL** — App Check is activated in the app (`lib/main.dart`, `_activateAppCheck`) and enforced for Firebase AI Logic (receipt scan, see 9.4). The callable Places function is gone; the remaining functions are Firestore-triggered push functions, which App Check does not cover. Whether enforcement is on for Firestore and Storage is a console setting and cannot be seen in the code |
| 2.7 | Release builds are signed with the **debug keystore**. Not publishable, and it prevents per-app API key restriction. | `android/app/build.gradle.kts` | **OPEN** — still `signingConfigs.getByName("debug")` in `android/app/build.gradle.kts` (checked 2026-11-21) |
| 2.8 | Raw exception text is shown to users in ~15 places, leaking Firestore paths and permission-denied internals. | group, profile, swipe and home screens | **FIXED** |
| 2.9 | Place content (names, addresses, photos) was cached **indefinitely**. Google's Places policy allows storing place IDs indefinitely but not content. Not independently verified against the current policy text — worth confirming. | `place_model.dart`, cache metadata | **FIXED** (30-day TTL plus a daily refresh job in the Cloud Function) |

---

## 3. High — performance and read amplification

| # | Problem | Where | Status |
|---|---|---|---|
| 3.1 | `loadNearbyPlaces` reads the **entire `places` collection** and filters in Dart, on every `SwipeController.build()`. `build()` re-runs on every group state change, including loading flips. | `places_repository.dart:252`, `swipe_controller.dart:41,85` | **OBSOLETE** — places now load per city with a bounded query (`cityId` + `status`, ordered by popularity) or from `placeTiles`; `loadNearbyPlaces` no longer scans the collection and has no callers |
| 3.2 | **The worst cascade:** every "like" reads all group members' profiles and writes the group document. That write wakes every member's group stream, which rebuilds their swipe controller, which re-scans the whole `places` collection. One 20-card solo session with a group selected costs roughly **2,200 reads instead of ~50**. | `swipe_controller.dart:278-317` | **OBSOLETE** — the sharedFavorites sync was removed (2026-11-15, `75923846`); a group like writes only `groups/{g}/swipes/{uid}` |
| 3.3 | The session document is rewritten on **every swipe** by every member — about 2 writes/second on one document with 4 members, above Firestore's ~1 write/second guidance. Causes transaction retries, each costing 2 more reads. | `group_repository.dart:382` | **OBSOLETE** — sessions are no longer written (read and delete only); group votes live in `swipes/{uid}`, one document per member |
| 3.4 | Gemini was called **sequentially, once per place** — 20 round trips on the critical path while the admin waits, 20–60 seconds. | `places_repository.dart:117-147` | **FIXED** (one batched call, server-side, off the critical path) |
| 3.5 | `gemini-2.5-flash` reasons internally by default, and those tokens counted against a 60-token output budget, so responses frequently came back empty and were saved as `null`. | `places_repository.dart:221-224` | **FIXED** (`thinkingBudget: 0`, cheaper `flash-lite` model) |
| 3.6 | Loading a session fetches places **one document at a time** (20+ sequential round trips). | `swipe_controller.dart:73-76` | **OBSOLETE** — session loading was removed with the sessions |
| 3.7 | The solo swipe-history query is **unbounded** and grows by one document per swipe forever. | `places_repository.dart:314-329` | **OPEN** — still one `swipeResults` document per solo swipe, and `getSwipedPlaceIds` reads all of them without a limit on every swipe-controller build (`swipe_controller.dart:123`, `places_repository.dart:301`). Fix: store swiped IDs in one document per user |
| 3.8 | Every session and vote rule performs a `get()` on the parent group — an extra billed read per operation, up to 3 per swipe. | `firestore.rules` | **PARTIAL** — the session and vote rules are no longer used; the current rules for swipes, expenses and journal were not re-measured for extra `get()` reads |

---

## 4. Medium — correctness

| # | Problem | Where | Status |
|---|---|---|---|
| 4.1 | Favourites are written as a **whole-array overwrite** from an in-memory list, and the profile read swallows errors and returns an empty list. One failed read followed by one like **wipes the user's favourites**. | `swipe_controller.dart:158`, `profile_repository.dart:16-18` | **FIXED** |
| 4.2 | A parse error on a session document is treated as "session missing", which **clears the active session for every member**, killing a live session. | `group_repository.dart:425-429`, `group_controller.dart:66-76` | **FIXED** |
| 4.3 | `leaveGroup` is a non-transactional read-modify-write, so a concurrent join is lost. If the owner leaves, `ownerUid` points at a non-member and **nobody can start or end sessions again**. | `group_repository.dart:155-177` | **FIXED** |
| 4.4 | `startSwipeSession` never checks for an existing active session, so a double-tap creates **two sessions**, orphaning the first. | `group_repository.dart:209-257` | **FIXED** |
| 4.5 | A place with an empty id became `doc('')`, which throws and **aborts the entire cache batch**. | `places_repository.dart:134` | **FIXED** |
| 4.6 | `toJson` writes explicit `null`s with `merge: true`, so one failed Gemini call **erases a description that was already cached**. | `place_model.dart:78-89` | **OBSOLETE** — the client Places/Gemini path was removed (2026-11-01) |
| 4.7 | No timeouts on the Places or Gemini HTTP calls — a hang leaves the UI stuck loading forever. | `places_repository.dart:69,207` | **OBSOLETE** — the client Places/Gemini path was removed (2026-11-01) |
| 4.8 | City lookup uses the shared geonames `demo` account, which is usually rate-limited, over plaintext HTTP. It almost always falls back to 10 hardcoded cities whose IDs (`1`–`10`) **ignore the selected country**, so `DE_1` resolves to Paris. The same city can be cached under two different keys, causing duplicate paid fetches. | `location_repository.dart:6-7` | **OBSOLETE** — `LocationRepository` (geonames) is no longer referenced anywhere; `lib/features/group/data/location_repository.dart` is dead code and can be deleted |
| 4.9 | The failing transaction test passed only because the Firestore fake tolerates updating a missing document; real Firestore would reject it. | `group_repository.dart:377` | **FIXED** (group existence now checked inside the transaction) |

---

## 5. Medium — user-facing problems

| # | Problem | Where | Status |
|---|---|---|---|
| 5.1 | **~88 German strings** remain, in the settings, login and register screens — more than the project docs claimed. All UI text is supposed to be English. | `settings_screen.dart`, `login_screen.dart`, `register_screen.dart` | **FIXED** |
| 5.2 | The Impressum shows **placeholder legal identity** ("Musterfirma GmbH", "Max Mustermann", "HRB 12345"), and the privacy dialog claims **end-to-end encryption**, which is false for a Firebase app. Both are a real risk if users see them. | `settings_screen.dart:99-124,214` | **FIXED** |
| 5.3 | Login and register sit **inside the bottom-navigation shell**, so a logged-out user sees the Discover/Groups/Profile tab bar. Confirmed visually on the simulator. | `routes.dart:91-98` | **FIXED** |
| 5.4 | The group member list shows **raw Firebase UIDs** instead of display names. | `simplified_group_screen.dart:630-636` | **FIXED** |
| 5.5 | Dark theme is fully built but **never wired up**, and ~130 hardcoded `Colors.*` values would break it anyway. | `app.dart:13`, `theme.dart` | **FIXED** (hardcoded colours replaced by `colorScheme` / `context.swipeColors`; dark mode follows the device, switchable under Settings → Appearance) |
| 5.6 | The city dropdown keeps a stale selected value when the country changes, causing a Flutter assertion in debug and a blank dropdown in release. | `simplified_group_screen.dart:57-71` | **FIXED** |
| 5.7 | Login and register screens have no scroll view, so on a small screen with the keyboard open the layout **overflows**. | `login_screen.dart:53`, `register_screen.dart:38` | **FIXED** |
| 5.8 | A destructive "reset all places and favourites" action sits permanently in the home app bar behind a single confirm. | `simplified_home_screen.dart:18-22` | **FIXED** |
| 5.9 | In a group session the app shows "Added to favorites!" when the like only cast a vote. | `swipe_screen.dart:224-227` | **FIXED** |
| 5.10 | Only 2 icon buttons in the whole app have accessibility labels. | many screens | **PARTIAL** — about 77 tooltips / semantic labels now; no full accessibility audit yet |

---

## 6. Architecture and maintainability

| # | Problem | Where | Status |
|---|---|---|---|
| 6.1 | **23 cross-feature imports** violate the layer rules. They use relative paths, so the lint hook that checks for `package:` imports never catches them. | `swipe_controller.dart`, `group_controller.dart`, several screens | **PARTIAL** — 2 left: `auth/logic/auth_controller.dart` imports `profile/data/profile_repository.dart`, `group/logic/group_controller.dart` imports `auth/logic/auth_controller.dart` |
| 6.2 | `PlacesRepository()` and `LocationRepository()` are constructed directly inside controllers and widgets instead of injected via providers, which is why the favourites and like paths have no tests. | `swipe_controller.dart:27`, `group_controller.dart:42` | **PARTIAL** — `PlacesRepository` comes from a provider (`main_providers.dart`), but `place_detail_screen.dart:29` still constructs one directly; `LocationRepository` is unused (see 4.8) |
| 6.3 | Providers and data-loading logic live inside UI files. | `group_matches_screen.dart:41-94`, `place_detail_screen.dart:11-15` | **OPEN** — providers are still defined in about 10 UI files under `features/group/ui/` (e.g. `trips_screen.dart`, `costs_screen.dart`, `trip_detail_screen.dart`) |
| 6.4 | The home screen contains a ~400-line **duplicate** of the swipe card stack, which has already drifted from the real one. `PlaceCard` in `common/` is unused. | `simplified_home_screen.dart:176-581` | **FIXED** (both screens use the shared `SwipeDeck`) |
| 6.5 | `analysis_options.yaml` has **zero custom lint rules**. `unawaited_futures` alone would have caught the transaction bug in section 4.9. | `analysis_options.yaml` | **FIXED** (2026-11-15, `edb649e5`) — `unawaited_futures`, `cancel_subscriptions`, `close_sinks` and four more rules in `analysis_options.yaml` |
| 6.6 | Tracked junk in the repo: `lib.rar`, `extract.py`, `extract.dart`. `.gitignore` is missing `*.jks`, `*.keystore`, `android/key.properties`. | repo root | **FIXED** (2026-11-15: junk and the unused linux/macos/windows/web folders removed; keystores and `key.properties` were already ignored in `android/.gitignore`) |
| 6.7 | `GroupRepository` has two parallel code paths (injected vs service), so tests exercise a different path than production. | `group_repository.dart:12,19,47,164` | **OPEN** — `GroupRepository` still switches between injected Firestore and `FirestoreService` (`_usesInjectedFirestore`) |
| 6.8 | Project docs are stale: `CLAUDE.md` and `mvp_architecture_plan.md` describe a mock-data state that no longer exists, several "open risks" are already fixed, and `2026-07-03-group-swipe-matching-design.md` describes a ranked Borda-count matching design that **was never built** (the app uses simple like-count matching). | `*.md` at repo root | **OPEN** |

---

## 7. Test coverage gaps

**Update 2026-11-21:** all Flutter tests pass (268 on `feat/clean-design`,
i.e. `main` plus PR #15) and `flutter analyze` reports no issues. Firestore rules now have 33 emulator
tests (`tools/rules-test`), and CI (`.github/workflows/ci.yml`) runs Flutter,
rules, functions and city-import tests on every PR. The list below is from
the 2026-09-02 audit; which of these gaps remain was not re-checked.

Original list (2026-09-02):

- GoRouter redirect logic (auth, onboarding and active-session gating)
- Favourites add/remove and profile sync
- Solo `like()` / `nextPlace()` behaviour
- `allMembersDone` edge cases (missing participant, null swipe limit)
- `loadNearbyPlaces` radius and tag filtering
- `joinGroupByInvite` failure modes (wrong code, joining disabled, rejoin)
- ~~Firestore **rules** — no emulator test exists~~ — covered since by
  `tools/rules-test`

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
dart pub global activate flutterfire_cli   # once; it is no longer a project dependency
flutterfire configure
```

**Update 2026-11-21:** `lib/firebase_options.dart` now carries iOS and Android
app IDs for `com.swipetrip.app`, which `flutterfire configure` writes, so
the registration looks done; confirm it in the console. The **final** bundle
ID is still open (the local Xcode project may use another one for signing;
never commit `project.pbxproj`).

**Update 2026-11-25:** final ID is `com.hozanstudio.outwego` (iOS bundle ID and
Android `applicationId`; the Kotlin package/namespace stays `com.swipetrip.app`).
Registered as an App ID in Apple team `NT99B7745X` and as new Firebase iOS and
Android apps ("Out We Go"); `firebase_options.dart`, `google-services.json` and
`firebase.json` point to them. The old Firebase iOS/Android apps (`mobileapp`, `com.example.mobileapp`) were removed; the web apps kept their IDs and were renamed "Out We Go (web/windows)".
`project.pbxproj` is not committed, so each developer sets the bundle ID and
team in Xcode (Runner → Signing & Capabilities).

---

## 9. Before launch: remove development shortcuts

Settings that exist only to make local development faster. Every one of them
must be reverted before a public release.

| # | Shortcut | Where | What to do before launch |
|---|---|---|---|
| 9.1 | ~~**Fixed dev location.**~~ **Done 2026-11-01:** `AppConfig.useFixedDevLocation` is `false`; the fallback when GPS is denied or fails is Berlin (a curated city). | `lib/core/config/app_config.dart` | **Ready:** Hamburg is live (checked in the app 2026-11-21). Switch the fallback to Hamburg (`lib/core/config/app_config.dart:40`). |
| 9.2 | ~~**Dev places fallback.**~~ **Removed 2026-11-01** with the `getCityPlaces` path. | — | — |
| 9.3 | ~~**Legacy place data.**~~ **Done 2026-11-15:** the 87 old test places (`DE_*`, `FR_*`, `GB_*`, `TR_*`) are deleted from `places`, `placeCacheMetadata` is empty, and `PlacePhotoUrlBuilder` is removed; `PlacePhoto` reads `imageUrls` only. **Update 2026-11-21:** Hamburg, Cologne and Zürich are live, checked in the app on the simulator together with Munich, Paris and Berlin (must-sees with photos, 150 places in the deck). The other cities added in `4c1b936b` were not checked one by one. | `tools/city-import` | — |
| 9.4 | **App Check for the receipt scan.** Firebase AI Logic enforces App Check (turned on 2026-11-08). Debug builds use the debug provider with a token from `--dart-define=APP_CHECK_DEBUG_TOKEN=...`, registered in the console under App Check → iOS app → debug tokens. Release builds use DeviceCheck (iOS) and Play Integrity (Android), which are not registered yet, so the scan fails in release builds until then. | `lib/main.dart` (`_activateAppCheck`), Firebase console → App Check | Re-register the apps with the final bundle ID (section 8), then register DeviceCheck (needs the Apple Developer account) and Play Integrity. Delete the debug tokens. |
| 9.5 | **Berlin photos at the old size.** Since 2026-11-09 the import stores photos at 1080 px, WebP quality 75 (~40 % smaller). Berlin was published before, at 1280 px / 80 (~1.3 GB in R2); `publish` reuses photos already in R2, so a plain rerun keeps them. | R2 `places/de_berlin/…`, `tools/city-import` | With the owner's OK: delete Berlin's photos in R2, then `npm run collect -- --city de_berlin` and `npm run publish -- --city de_berlin`. |

## 10. Open product decisions

Questions the product owner still has to answer. Features that depend on
them are on hold until then.

| # | Decision | Options | Blocks |
|---|---|---|---|
| 10.1 | ~~**When does a place count as a group match?**~~ **Decided 2026-10-23: (a) majority of participants, minimum 2 likes** (`matchThreshold` in `common/utils/group_swipes.dart`; alone on a trip every like counts). A super-like matches with one more like; one veto per member removes a place. | — | — |
