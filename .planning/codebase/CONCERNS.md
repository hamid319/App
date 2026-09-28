# Codebase Concerns

**Analysis Date:** 2026-07-04

## Tech Debt

**Compile-blocking AppConfig typo:**
- Issue: `lib/core/config/app_config.dart:6` assigns `faIse` instead of Dart's `false`.
- Files: `lib/core/config/app_config.dart`, `lib/features/swipe/data/places_repository.dart`, `test/places_api_migration_test.dart`, `test/places_api_stress_test.dart`
- Impact: The app and tests cannot compile while `AppConfig.enableRealPlacesAPI` references an undefined identifier.
- Fix approach: Change `faIse` to `false`, keep the cost-control flag explicit, then run `flutter analyze` and the Places repository tests.

**Environment loading is wired but not invoked:**
- Issue: `lib/core/config/env.dart` defines `Env.init()` and `Env.googlePlacesApiKey`, but `lib/main.dart` initializes Firebase and starts `MobileApp` without calling `Env.init()`.
- Files: `lib/core/config/env.dart`, `lib/main.dart`, `lib/features/swipe/data/places_repository.dart`, `pubspec.yaml`
- Impact: `Env.googlePlacesApiKey` resolves to an empty string in runtime paths, so real Places sessions fail with "Google Places API key not configured in .env" even when `.env` exists.
- Fix approach: Call `await Env.init()` after `WidgetsFlutterBinding.ensureInitialized()` and before code paths that read `Env.googlePlacesApiKey`; add a startup or repository test that proves dotenv is initialized.

**Cost-control configuration is mutable global state:**
- Issue: `AppConfig.enableRealPlacesAPI` is a mutable static toggled by tests and read by production session-start flows.
- Files: `lib/core/config/app_config.dart`, `lib/features/group/logic/group_controller.dart`, `lib/features/swipe/data/places_repository.dart`, `test/places_api_migration_test.dart`, `test/places_api_stress_test.dart`
- Impact: Production behavior depends on global mutable state, and tests can leak configuration across cases because `setUpAll()` changes the flag once.
- Fix approach: Read the flag from environment-backed configuration or inject a typed config object into `PlacesRepository`; restore global config in test teardown if the static remains.

**Project rule status reference is partially out of sync with current files:**
- Issue: `swipe_card.dart`, `swipe_buttons.dart`, `app_config.dart`, and `env.dart` are present with content, while `home_screen.dart`, `group_screen.dart`, and `profile_screen.dart` are not present under `lib/features`; `theme.dart` is implemented but remains minimal compared with the project skill's Material 3 theme guidance.
- Files: `lib/features/swipe/widgets/swipe_card.dart`, `lib/features/swipe/widgets/swipe_buttons.dart`, `lib/core/config/app_config.dart`, `lib/core/config/env.dart`, `lib/app/theme.dart`
- Impact: Future planners may target already-filled files or deleted legacy screens unless the status reference is refreshed.
- Fix approach: Update project planning/status docs to mark completed/absent files accurately and keep `lib/app/theme.dart` as the remaining theme-completion target if a full design pass is still required.

**Very large UI/controller files concentrate unrelated behavior:**
- Issue: `SimplifiedGroupScreen`, `GroupRepository`, `GroupController`, `SwipeController`, and group matches UI own validation, network orchestration, Firestore operations, presentation, and error handling in large files.
- Files: `lib/features/group/ui/simplified_group_screen.dart`, `lib/features/group/data/group_repository.dart`, `lib/features/group/logic/group_controller.dart`, `lib/features/swipe/logic/swipe_controller.dart`, `lib/features/group/ui/group_matches_screen.dart`
- Impact: Changes to group session behavior have a high regression surface and are difficult to test in isolation.
- Fix approach: Keep Firestore transaction logic in `lib/features/group/data/group_repository.dart` untouched unless necessary; extract UI widgets and pure validators from `lib/features/group/ui/simplified_group_screen.dart`, and add focused controller/repository tests before behavior changes.

**German strings still violate the English-only project rule:**
- Issue: User-facing German text remains in auth validation, auth error messages, and settings/legal dialogs.
- Files: `lib/features/auth/ui/login_screen.dart`, `lib/features/auth/ui/register_screen.dart`, `lib/features/profile/ui/settings_screen.dart`
- Impact: The UI violates the AGENTS.md rule "All strings must be in English" and creates inconsistent user-facing language.
- Fix approach: Translate only string literals and comments in the affected files; do not change auth/settings logic during translation.

## Known Bugs

**App cannot pass analyzer until `AppConfig` is fixed:**
- Symptoms: Dart resolves `faIse` in `lib/core/config/app_config.dart:6` as an undefined identifier.
- Files: `lib/core/config/app_config.dart`
- Trigger: Run `flutter analyze`, `flutter test`, or compile any target importing `AppConfig`.
- Workaround: None in source; `flutter` is also unavailable on the current shell `PATH`, so analyzer verification could not be executed in this mapping run.

**Favorites screen queries around coordinates `0,0`:**
- Symptoms: Favorites are filtered from `PlacesRepository().loadNearbyPlaces(0, 0)`, which only loads cached places within the default radius around the Gulf of Guinea rather than fetching favorited place IDs directly.
- Files: `lib/features/home/ui/favorites_screen.dart`, `lib/features/swipe/data/places_repository.dart`, `lib/features/swipe/logic/swipe_controller.dart`
- Trigger: Open `/favorites` with favorites whose cached coordinates are not near `0,0`.
- Workaround: None in UI; use `getPlaceById()` for each favorite ID or add a repository method that fetches favorites by document IDs.

**Place detail "Add to Favorites" likes the current swipe card, not the displayed place:**
- Symptoms: The detail screen calls `ref.read(swipeControllerProvider.notifier).like()` when adding the displayed place to favorites, and `like()` operates on `currentPlace`.
- Files: `lib/features/places/ui/place_detail_screen.dart`, `lib/features/swipe/logic/swipe_controller.dart`
- Trigger: Open a place detail for a place that is not exactly `SwipeController.currentPlace`, then tap "Add to Favorites".
- Workaround: None in UI; call a dedicated `addFavorite(place.id)` path instead of reusing swipe `like()`.

**Router redirects can block normal navigation during an active group session:**
- Symptoms: Any logged-in route outside `/swipe` and `/group-matches` redirects to `/swipe/{groupId}` when `_pickActiveSessionGroup()` finds an active session.
- Files: `lib/app/routes.dart`, `lib/features/group/logic/group_controller.dart`
- Trigger: Log in with a group whose `activeSessionId` is set, then navigate to `/profile`, `/settings`, `/favorites`, or `/group`.
- Workaround: End the session; a code fix should narrow forced redirects to entry routes or allow explicit navigation escape paths.

**Session admin detection uses first participant rather than owner/admin:**
- Symptoms: `SwipeScreen` treats `session.participants.first` as the admin for timed-session ending.
- Files: `lib/features/swipe/ui/swipe_screen.dart`, `lib/features/group/logic/group_controller.dart`, `lib/features/group/data/group_repository.dart`
- Trigger: Start a session where participant order does not match the group owner/admin.
- Workaround: Manual session ending is only reliable when the owner is first in `participantUids`; use `GroupController.isAdmin` or group owner data instead.

**Profile repository masks missing/corrupt profile data as a new empty user:**
- Symptoms: `getUserProfile()` returns a synthetic `UserModel` with empty email/favorites/groups for both missing documents and caught exceptions.
- Files: `lib/features/profile/data/profile_repository.dart`, `lib/features/profile/logic/profile_controller.dart`, `lib/features/profile/ui/simplified_profile_screen.dart`
- Trigger: Firestore read fails, profile JSON is invalid, or the user document is missing.
- Workaround: None; return explicit failure for errors and only create a default profile through a separate creation path.

## Security Considerations

**`.env` is packaged as a Flutter asset:**
- Risk: `pubspec.yaml` lists `.env` under Flutter assets, so environment values can be bundled into client builds.
- Files: `pubspec.yaml`, `lib/core/config/env.dart`
- Current mitigation: `.env` exists at repo root and is loaded through `flutter_dotenv`; contents were not read during this audit.
- Recommendations: Do not ship sensitive values in client assets. Use platform-specific secret injection, backend proxying, or restrict public client keys by app/package/domain and API scope.

**Places photo URLs persist the Google API key in cached data:**
- Risk: `PlacesRepository.fetchAndCachePlacesForCity()` builds photo media URLs with `key=` in the query string and writes `place.toJson()` to Firestore.
- Files: `lib/features/swipe/data/places_repository.dart`, `lib/common/models/place_model.dart`
- Current mitigation: Real API calls are gated by `AppConfig.enableRealPlacesAPI`, but cached URLs still expose the key whenever real calls are enabled.
- Recommendations: Store Google photo resource names, not key-bearing URLs; resolve media through a backend proxy or construct short-lived URLs at render time without persisting the key.

**API keys/config values are committed in generated platform config:**
- Risk: Firebase/Google API key fields are present in generated config files and Android service config.
- Files: `lib/firebase_options.dart`, `android/app/google-services.json`
- Current mitigation: Firebase client keys are often public identifiers, but the project rule says never hardcode API keys.
- Recommendations: Confirm each committed key is non-secret and restricted in Google Cloud/Firebase by app ID, SHA/package, domain, and API allowlist; document why these generated files are allowed if they remain committed.

**GeoNames lookup uses plaintext HTTP and a shared demo username:**
- Risk: Country/city lookups use `http://api.geonames.org/...` and `_username = 'demo'`, exposing requests to interception and rate-limit instability.
- Files: `lib/features/group/data/location_repository.dart`, `lib/features/group/ui/simplified_group_screen.dart`
- Current mitigation: Requests time out after 3 seconds and fallback to local mock data.
- Recommendations: Use HTTPS if the provider supports it, move the username/configuration out of source, handle provider errors in UI, and consider a curated static dataset or backend endpoint.

**User-uploaded profile images lack explicit validation beyond picker resizing:**
- Risk: `ImageService.uploadProfileImage()` uploads `File(imageFile.path)` as `image/jpeg` without checking actual MIME type, file size, path provenance, or ownership authorization beyond Storage rules.
- Files: `lib/features/profile/data/image_service.dart`, `lib/features/profile/logic/profile_controller.dart`, `lib/features/profile/ui/simplified_profile_screen.dart`
- Current mitigation: `image_picker` constrains dimensions and image quality.
- Recommendations: Enforce max bytes, validate content type from file metadata/content, keep filenames scoped to authenticated UID, and verify Firebase Storage rules before enabling profile image uploads broadly.

**Security settings UI overclaims unimplemented controls:**
- Risk: Settings states end-to-end encryption and security-update claims, while password change and two-factor auth are explicitly future features.
- Files: `lib/features/profile/ui/settings_screen.dart`, `lib/features/auth/logic/auth_controller.dart`
- Current mitigation: The dialog marks password change and 2FA as unavailable in a note.
- Recommendations: Replace claims with accurate current controls and add real account-security actions before presenting them as available protections.

## Performance Bottlenecks

**Firestore full-collection scan for nearby places:**
- Problem: `loadNearbyPlaces()` reads every document in `places` and filters radius/tags client-side.
- Files: `lib/features/swipe/data/places_repository.dart`, `lib/features/swipe/logic/swipe_controller.dart`, `lib/features/home/ui/favorites_screen.dart`
- Cause: Firestore query has no geospatial/city/tag bounds before `.get()`.
- Improvement path: Query by `cityId` or geohash buckets, cap reads, and add index-backed filters; avoid using `loadNearbyPlaces()` for favorite IDs.

**Sequential Firestore reads for session place pools:**
- Problem: `SwipeController.build()` loops through `session.placePool` and awaits `getPlaceById()` one place at a time.
- Files: `lib/features/swipe/logic/swipe_controller.dart`, `lib/features/swipe/data/places_repository.dart`, `lib/features/group/data/group_repository.dart`
- Cause: The session place pool stores IDs, but no bulk fetch path is used.
- Improvement path: Fetch in parallel with bounded concurrency or add a repository method for batched document reads.

**Session votes and progress use one transaction per swipe:**
- Problem: Every group swipe reads and writes the session doc, vote doc, user swipe doc, and maybe group doc inside a Firestore transaction.
- Files: `lib/features/group/data/group_repository.dart`, `lib/features/swipe/logic/swipe_controller.dart`
- Cause: `recordSwipeInSession()` keeps per-place vote membership lists and session progress in the transaction.
- Improvement path: Keep the transaction logic isolated, load-test write contention for larger groups, and consider sharded/append-only vote records if contention appears.

**Large group UI rebuild surface:**
- Problem: `SimplifiedGroupScreen` stores location loading, create-group state, join dialogs, session start state, and group detail rendering in one stateful widget.
- Files: `lib/features/group/ui/simplified_group_screen.dart`
- Cause: Local `setState()` and multiple Riverpod watches share the same widget boundary.
- Improvement path: Extract create/join/session panels into smaller `ConsumerWidget` or `ConsumerStatefulWidget` classes and test each flow independently.

## Fragile Areas

**Do-not-touch transaction boundary:**
- Files: `lib/features/group/data/group_repository.dart`, `lib/features/group/logic/group_controller.dart`, `lib/features/swipe/logic/swipe_controller.dart`
- Why fragile: Group session correctness depends on Firestore transactions, active-session cleanup, vote deduplication, and participant progress all agreeing.
- Safe modification: Treat `lib/features/group/data/group_repository.dart` as a protected boundary; add tests around `recordSwipeInSession()`, `startSwipeSession()`, `endSessionManually()`, and `clearActiveSessionIfMatch()` before changing transaction behavior.
- Test coverage: Existing tests target Places API only; no group repository/controller tests are present under `test/`.

**Silent error handling hides data loss and failed writes:**
- Files: `lib/features/swipe/logic/swipe_controller.dart`, `lib/features/group/logic/group_controller.dart`, `lib/features/group/ui/simplified_group_screen.dart`, `lib/features/group/data/group_repository.dart`, `lib/features/swipe/ui/swipe_screen.dart`
- Why fragile: Failed votes, failed favorite writes, stale sessions, and location failures are swallowed or converted to empty state while UI continues.
- Safe modification: Convert expected failures into `AsyncError` or user-visible messages; log diagnostic-only details without exposing secrets.
- Test coverage: No tests exercise failed vote writes, failed favorite sync, location errors, or stale active-session cleanup.

**Router redirect uses async provider reads inside redirect:**
- Files: `lib/app/routes.dart`, `lib/features/group/logic/group_controller.dart`
- Why fragile: `redirect` awaits `userGroupsProvider.future` and reads auth/group provider state while also using `refreshListenable`, which can cause unexpected redirect timing and repeated provider work.
- Safe modification: Keep redirect rules minimal and deterministic; push session-routing decisions into route entry points or a dedicated auth/session gate with tests.
- Test coverage: `test/widget_test.dart` only checks that `MobileApp` builds; no GoRouter redirect scenarios are covered.

**Swipe state mixes local mutable fields with Riverpod AsyncData:**
- Files: `lib/features/swipe/logic/swipe_controller.dart`, `lib/features/home/ui/simplified_home_screen.dart`, `lib/features/home/ui/favorites_screen.dart`, `lib/features/places/ui/place_detail_screen.dart`
- Why fragile: `_currentIndex`, `_favorites`, and `_swipedPlaceIds` live outside the emitted state, so screens read notifier fields and depend on manual `AsyncData(List.of(data))` emissions.
- Safe modification: Move cursor/favorites/swiped IDs into an immutable state object, or keep all public mutators narrow and covered by notifier tests.
- Test coverage: No unit tests cover `like()`, `skip()`, `removeFavorite()`, `resetAll()`, or detail/favorites interactions.

**Profile image lifecycle depends on URL parsing and nullable profile state:**
- Files: `lib/features/profile/data/image_service.dart`, `lib/features/profile/logic/profile_controller.dart`, `lib/features/profile/ui/simplified_profile_screen.dart`
- Why fragile: Deletes use `refFromURL(imageUrl)`, uploads overwrite `profile_$userId.jpg`, and UI editing only updates display name while image controller paths are not exposed in `SimplifiedProfileScreen`.
- Safe modification: Add explicit image actions, validate ownership, store storage path separately from download URL, and test upload/delete failure states.
- Test coverage: No profile repository/controller/image tests exist under `test/`.

## Scaling Limits

**Places cache query volume:**
- Current capacity: `AppConfig.maxPlacesLimit` caps Places API fetch size at 50, but `loadNearbyPlaces()` has no Firestore read cap.
- Limit: The `places` collection grows without bounded client reads for home, swipe, and favorites flows.
- Scaling path: Add city/geohash indexes, pagination, and query limits before expanding real Places ingestion.

**Group session participant/write contention:**
- Current capacity: One transaction per swipe, one vote document per place, and one session progress map containing participant counters.
- Limit: Larger groups increase transaction contention and document size/write frequency around `groups/{groupId}/sessions/{sessionId}`.
- Scaling path: Keep per-user progress in separate docs or aggregate asynchronously once group sizes exceed small travel groups.

**Invite-code lookup uniqueness:**
- Current capacity: `joinGroupByCodeOnly()` queries the first group matching a six-character invite code.
- Limit: Invite code generation has no repository-enforced uniqueness guarantee.
- Scaling path: Store invite codes in a unique lookup collection or retry generation inside a transaction.

## Dependencies at Risk

**GeoNames demo API:**
- Risk: `LocationRepository` uses the shared `demo` username and falls back to fixed mock cities when API calls fail.
- Impact: Group creation destination data can silently become generic and disconnected from real provider results.
- Migration plan: Use a dedicated configured provider account, an offline curated city list, or a backend endpoint with caching and quotas.

**Flutter toolchain not available in current shell:**
- Risk: `flutter analyze` could not be executed because `flutter` is not on `PATH`.
- Impact: Compile/analyzer status cannot be verified from this environment, despite the project rule requiring analyzer checks after changes.
- Migration plan: Ensure Flutter SDK is installed and exported in the agent shell profile, then rerun `flutter analyze` and `flutter test`.

## Missing Critical Features

**Real account security actions:**
- Problem: Settings mentions password change and 2FA as future functionality, while the auth controller only covers login/signup/logout/current user stream.
- Blocks: Users cannot manage credentials or strengthen account security from the app.
- Files: `lib/features/profile/ui/settings_screen.dart`, `lib/features/auth/logic/auth_controller.dart`, `lib/features/auth/data/auth_repository.dart`

**Robust environment/config validation at startup:**
- Problem: Startup does not validate required env/config values before routes can reach Places flows.
- Blocks: Real Google Places sessions fail late at session start instead of presenting actionable setup state.
- Files: `lib/main.dart`, `lib/core/config/env.dart`, `lib/core/config/app_config.dart`, `lib/features/group/logic/group_controller.dart`

**Dedicated favorites data access:**
- Problem: Favorites are modeled as profile place IDs, but the UI lacks a repository method to fetch those IDs directly.
- Blocks: Favorites rendering is incorrect for places outside `0,0` radius and couples the favorites page to swipe-controller internals.
- Files: `lib/features/home/ui/favorites_screen.dart`, `lib/features/swipe/data/places_repository.dart`, `lib/features/profile/data/profile_repository.dart`

## Test Coverage Gaps

**Compile/analyzer verification:**
- What's not tested: Current compile status and lint/analyzer errors.
- Files: `analysis_options.yaml`, `lib/core/config/app_config.dart`, `test/places_api_migration_test.dart`, `test/places_api_stress_test.dart`
- Risk: The `faIse` typo and any analyzer errors block all runtime work.
- Priority: High

**Auth, routing, and onboarding flows:**
- What's not tested: Login/register validation strings, auth redirect behavior, onboarding completion, and active-session redirects.
- Files: `lib/features/auth/ui/login_screen.dart`, `lib/features/auth/ui/register_screen.dart`, `lib/app/routes.dart`, `lib/features/onboarding/ui/onboarding_screen.dart`, `test/widget_test.dart`
- Risk: Route loops or language regressions can ship unnoticed.
- Priority: High

**Group/session flows:**
- What's not tested: Group creation, invite joins, session start/end, vote deduplication, progress completion, and qualified matches.
- Files: `lib/features/group/logic/group_controller.dart`, `lib/features/group/data/group_repository.dart`, `lib/features/group/ui/simplified_group_screen.dart`, `lib/features/group/ui/group_matches_screen.dart`
- Risk: Firestore transaction regressions can break the core collaborative travel flow.
- Priority: High

**Swipe/favorites/detail interactions:**
- What's not tested: `SwipeController.like()`, `skip()`, `removeFavorite()`, `resetAll()`, `FavoritesScreen`, and `PlaceDetailScreen` favorite actions.
- Files: `lib/features/swipe/logic/swipe_controller.dart`, `lib/features/home/ui/favorites_screen.dart`, `lib/features/places/ui/place_detail_screen.dart`, `lib/features/home/ui/simplified_home_screen.dart`
- Risk: User favorites and swiped-place history can drift or update the wrong place.
- Priority: High

**Profile and image upload flows:**
- What's not tested: Profile fallback behavior, display-name edits, profile image upload/delete, and Firebase Storage failure handling.
- Files: `lib/features/profile/data/profile_repository.dart`, `lib/features/profile/logic/profile_controller.dart`, `lib/features/profile/data/image_service.dart`, `lib/features/profile/ui/simplified_profile_screen.dart`
- Risk: Profile data loss or upload errors can be masked until users interact with account settings.
- Priority: Medium

**Location provider fallback:**
- What's not tested: GeoNames timeout/error behavior, fallback country/city lists, and UI messaging when live location data is unavailable.
- Files: `lib/features/group/data/location_repository.dart`, `lib/features/group/ui/simplified_group_screen.dart`
- Risk: Group setup can silently use fallback data with no user explanation.
- Priority: Medium

---

*Concerns audit: 2026-07-04*
