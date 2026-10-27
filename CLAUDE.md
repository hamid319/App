# SwipeTrip — Agent Context

## Stack
Flutter · Riverpod 3 · Firebase (Auth, Firestore, Storage) · GoRouter 17 · flutter_dotenv

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
/trips (start, tab Reisen)   /trip/:groupId   /trip/:groupId/day/:index   /trip/:groupId/costs
/home (tab Entdecken, feed)  /discover (solo deck)   /collection/:theme   /place/:id
/group → /trips   /group/join?groupId=&code=   /swipe/:groupId   /group-matches/:groupId   /day-plan/:groupId/:sessionId
/profile      /settings   /favorites   /favorites-map
```
- Always use `context.go()` or `context.push()`. Never `Navigator.push()`.
- New routes go in `app/routes.dart` only. Path format: lowercase kebab-case.

## Env / secrets
```dart
Env.googlePlacesApiKey  // from .env via flutter_dotenv; .env is NOT bundled, so empty in builds
```
- Never hardcode API keys or base URLs in `.dart` files. Never add `.env` to pubspec assets (bundled files can be extracted).
- Google Maps SDK key: iOS `ios/Flutter/Secrets.xcconfig`, Android `android/local.properties` (`MAPS_API_KEY`), both git-ignored.
- App-wide constants → `AppConfig` / `core/constants/`.

## Firestore structure (short form)
```
/users/{uid}           favorites: string[], groups: string[]
/groups/{groupId}      members: string[], activeSessionId: string?, invite.code: string
  /sessions/{id}       swipeProgress: map<uid,int>, placePool: string[], status: 'in_progress'|'completed'
    /votes/{placeId}   likedBy: string[], dislikedBy: string[]
    /userSwipes/{uid}  swipedPlaceIds: string[]
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
2. **Firestore rule mismatch**: session `update` rule must allow `swipeProgress`, not `isCompleted`.
3. **UID display**: group member list must resolve UIDs to `UserModel.displayName`.
4. **Hardcoded UI text**: the app supports English and German. Every user-visible string goes through `context.l10n.<key>` (import `l10n/l10n.dart`), defined in `lib/l10n/app_en.arb` (template) and `lib/l10n/app_de.arb`. Never put a text literal in a widget. Add new keys to both files; `flutter gen-l10n` (or `flutter pub get`) regenerates the Dart code. Errors shown to users go through `userMessage(e, fallback: ..., l10n: context.l10n)`.

## Forbidden patterns (blocked or flagged by hooks)
- `Image.network(` → use `CachedNetworkImage(` (package not yet added — add it)
- Hardcoded secrets or URLs in `.dart`
- Cross-feature imports (`features/A` importing `features/B`)
- `Navigator.push()` anywhere — use GoRouter only
- `git commit`, `git push`, `rm -rf`, `firebase deploy` — blocked by `.claude/settings.json`

## MVP pending (as of June 2026)
- Google Places API key (currently mock data, 51 hardcoded places)
- FCM push notifications (not started)
- Password reset screen (not started)
- Dark theme wired in `app.dart` (built in `theme.dart`, not applied yet)

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
