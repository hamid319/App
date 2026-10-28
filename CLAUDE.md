# TripFam — Agent Context

TripFam (formerly SwipeTrip; the Dart package is still `swipetrip`, the
Firebase project `travelapp-31255`) is a group-trip app: plan together,
swipe places, day plans on a map, split costs, journal with photos, and a
passport with a stamp per city. Owner: Hamid (GitHub `hamid319/App`).

## Stack
Flutter · Riverpod 3 · Firebase (Auth, Firestore, Storage, Hosting) · GoRouter 17 · Mapbox Maps · share_plus · audioplayers · flutter_dotenv

## Architecture: Feature-First Clean Architecture

```
lib/
├── app/           → GoRouter, ShellNavigation, AppTheme, AccountGate, locale (language) controller + picker
├── l10n/          → app_en.arb / app_de.arb + generated AppLocalizations (`context.l10n`)
├── common/        → Shared models, shared widgets (used by 2+ features)
├── core/          → Services, config, constants, errors
├── features/      → auth | home | swipe | places | group | profile | onboarding
└── main.dart  main_providers.dart  firebase_options.dart  (nothing else here)
```

### Layer rules — enforce strictly
| Folder | Allowed content |
|---|---|
| `features/{name}/ui/` | Widget / Screen classes only. No business logic. |
| `features/{name}/logic/` | `AsyncNotifier` / `StreamNotifier` / `Notifier` only. No `BuildContext`. |
| `features/{name}/data/` | Repository classes only. No `ref.watch`, no UI imports. |
| `features/{name}/widgets/` | Feature-scoped reusable widgets. |
| `common/` | Truly shared models and widgets across 2+ features. |
| `core/services/` | App-wide singleton services. |

## Global providers (`main_providers.dart`)
```dart
authServiceProvider       // Provider<AuthService>
firestoreServiceProvider  // Provider<FirestoreService>
locationServiceProvider   // Provider<LocationService>
profileRepositoryProvider // Provider<ProfileRepository>
tripRepositoryProvider    // Provider<TripRepository> (used from common/ too)
currentAccountProvider    // the signed-in account ({uid, isGuest})
myTripsProvider           // StreamProvider<List<GroupModel>>, the user's trips
placeInTripProvider       // whether a trip's wishlist has a place
```

## Key feature providers
```dart
authControllerProvider   // AsyncNotifierProvider<AuthController, UserModel?>
swipeControllerProvider  // AsyncNotifierProvider<SwipeController, List<PlaceModel>>
groupControllerProvider  // AsyncNotifierProvider<GroupController, GroupModel?>
userGroupsProvider       // StreamProvider<List<GroupModel>>
groupRepositoryProvider  // Provider<GroupRepository>
routerProvider           // Provider<GoRouter>
```

## Routes (`app/routes.dart`)
```
/onboarding   /login   /register
/trips (start, tab Reisen)   /trip/:groupId   /trip/:groupId/day/:index   /trip/:groupId/costs   /trip/:groupId/journal   /trip/:groupId/recap
/home (tab Entdecken, feed)  /discover (solo deck)   /collection/:theme   /place/:id
/trip/:groupId/swipe (group deck)   /group → /trips   /group/join?groupId=&code=
(old /swipe/:groupId, /group-matches/:groupId, /day-plan/… redirect to the trip)
/profile   /passport   /settings   /favorites   /favorites-map
```
- Always use `context.go()` or `context.push()`. Never `Navigator.push()`.
- New routes go in `app/routes.dart` only. Path format: lowercase kebab-case.

## Env / secrets
```dart
Env.googlePlacesApiKey  // from .env via flutter_dotenv; .env is NOT bundled, so empty in builds
```
- Never hardcode API keys or base URLs in `.dart` files. Never add `.env` to pubspec assets (bundled files can be extracted).
- Mapbox public token (`pk.`): iOS `ios/Flutter/Secrets.xcconfig`, Android `android/local.properties` (`MAPBOX_ACCESS_TOKEN`), both git-ignored. Maps use Mapbox via `common/widgets/places_map.dart`; Google is only the "open in Google Maps" link.
- App-wide constants → `AppConfig` / `core/constants/`.

## Firestore structure (short form)
```
/users/{uid}           favorites: string[], groups: string[]
/inviteCodes/{code}    groupId, createdAt, title, cityName, ownerName (get only, no list; written by the owner)
/groups/{groupId}      members: string[], invite.code: string, tripPlan
  /ideas/{id}          wishlist entries (placeId?, title, addedBy, likedBy, source)
  /swipes/{uid}        votes: map<placeId, 0 nope|1 like|2 super-like>, veto: placeId?
                       (the trip's swipe deck, always open; matches are derived in
                       common/utils/group_swipes.dart and shown on the wishlist, not stored)
  /sessions/…          old swipe rounds: read/delete only, nothing writes them
  /journal/{id}        authorUid, day 'yyyy-MM-dd', text ≤500, photos [{path,url,width,height}] ≤6
                       (photos in Storage trips/{groupId}/journal/{id}/{i}.jpg)
/places/{placeId}      imageUrls: string[], types: string[]
                       curated (tools/city-import): id wd_<QID> or osm_<type>_<id>, source 'wikidata', cityId, status,
                       names/descriptions/wikipediaUrls per language, interests, popularity,
                       address/openingHours/website/osmUrl (OpenStreetMap, ODbL: credit it in the UI)
  /reviews/{uid}       rating 1-5, text ≤500, authorName, language, hidden, createdAt, updatedAt
                       (signed-in non-guests only; a report sets hidden=true, moderate in the console)
    /reports/{uid}     createdAt (write-only for clients)
/cities/{cityId}       curated cities (read-only for clients); cityId = PopularCity id
                       prompts: [{kind, text: {en, de}}]   (prompt tiles; kinds in PlacePromptKind)
                       photos: [{publicUrl, creator, licenseName, licenseUrl, commonsFilePageUrl}]  (Wikidata pipeline)
                       photoAttributions: [{displayName, uri}]  (Google; must be shown with the photo)
```

## Known bugs — never reintroduce
1. **Favorites bug**: `place_detail_screen.dart` must NOT call `swipeController.like()` (advances swipe stack). Use `addFavoriteById(placeId)`.
2. **Group swipes**: each member writes only `groups/{g}/swipes/{uid}`; never aggregate votes in shared documents (contention, and members could edit others' votes).
3. **UID display**: group member list must resolve UIDs to `UserModel.displayName`.
4. **Hardcoded UI text**: the app supports English and German. Every user-visible string goes through `context.l10n.<key>` (import `l10n/l10n.dart`), defined in `lib/l10n/app_en.arb` (template) and `lib/l10n/app_de.arb`. Never put a text literal in a widget. Add new keys to both files; `flutter gen-l10n` (or `flutter pub get`) regenerates the Dart code. Errors shown to users go through `userMessage(e, fallback: ..., l10n: context.l10n)`.

## Forbidden patterns (blocked or flagged by hooks)
- `Image.network(` → use `CachedNetworkImage(` (`cached_network_image` is installed)
- Hardcoded secrets or URLs in `.dart`
- Cross-feature imports (`features/A` importing `features/B`)
- `Navigator.push()` anywhere — use GoRouter only
- `rm -rf`, `git reset --hard`, `git clean`, `git rebase`, `firebase deploy` — blocked by `.claude/settings.json`
- `git commit` / `git push` are allowed, but only when the owner asks for them; never force-push, never push to `main` unless told to

## Status (October 2026)
Built and on `main`: trips with invites (web invite page in `web_invite/` on
Firebase Hosting), group swipe and wishlist, add to trip, day plans on
Mapbox, costs (edit/delete), offline mode, journal with photos and trip
recap, TripFam Pass with stamps and sharing (profile), the trip's group
swipe deck with super-like, one veto per member and matches on the
wishlist, password reset, onboarding, dark mode, account deletion, iOS
privacy manifest.

Not started or open:
- FCM push notifications
- Affiliate links (GetYourGuide/Viator, check their terms first)
- Passport: GPS check-in on site
- Untested by the owner: account deletion (throwaway account), offline mode,
  a real web-invite join with a second account, sound and haptics on a real
  iPhone, the Android runtime
- Release: final bundle id, Apple Developer account, domain, trademark check

## House rules (read before changing anything)
- Talk to the owner in **German, du-form, very short summaries**. Code
  comments and commit messages in English.
- **Line endings:** many Dart files use CRLF. Keep them (check with
  `file <path>`); never commit line-ending-only changes.
- **`dart format` only the files you changed.** Running it on a folder
  reformats files you did not touch; revert those.
- **Never commit:** `ios/Runner.xcodeproj/project.pbxproj` and
  `Runner.xcscheme` (local signing), `.claude/settings.local.json`,
  `.mcp.json`, `build`, files ending in ` 2` (iCloud duplicates),
  `docs/data-and-cost-strategy.md` (only if asked).
- **Never print secret values:** the Mapbox token (`ios/Flutter/Secrets.xcconfig`,
  `android/local.properties`), `tools/city-import/.env` (R2 keys), `.env`.
  Refer to them by name only.
- **The owner deploys** (`firebase deploy …`). After rule or index changes,
  tell him the exact command.
- iOS: run `pod install` with `LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8`.
- **Place data:** OpenStreetMap, Wikidata, Wikipedia, Wikimedia Commons via
  `tools/city-import` (Node 22, `npm run check`; collect → report → review →
  publish). **No Google Places content in the database** (Google's terms
  forbid storing it). No Instagram images. Keep within the R2 free tier
  (the tool has a 5 GB budget guard). Publishing city data needs the
  owner's OK.
- Budget: about €60 per month for hundreds of users. Prefer solutions that
  cost no extra Firestore reads or paid API calls.
- Test with throwaway data, never with the owner's real account for
  destructive actions. Temporary demo data in code must be removed before
  committing.

## Open product decisions
Listed in `POSSIBLE_ERRORS.md` section 10 (e.g. the group match rule).
Do not implement features that depend on them before the owner decides.

## Before launch
Dev-only shortcuts that must be reverted before release are listed in
`POSSIBLE_ERRORS.md` section 9 (e.g. `AppConfig.useFixedDevLocation`).
Add any new dev shortcut there too.

## Review skills
- `/flutter-review` — Dart code rules check
- `/firestore-review` — rules vs model field names
- `/arch-review` — Feature-First compliance
- `/simulator-check` — visual verify in running simulator
