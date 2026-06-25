# SwipeTrip — Agent Context

## Stack
Flutter · Riverpod 3 · Firebase (Auth, Firestore, Storage) · GoRouter 17 · flutter_dotenv

## Architecture: Feature-First Clean Architecture

```
lib/
├── app/           → GoRouter, ShellNavigation, AppTheme
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
/home         /swipe/:groupId   /place/:id
/group        /group/join?groupId=&code=   /group-matches/:groupId
/profile      /settings   /favorites
```
- Always use `context.go()` or `context.push()`. Never `Navigator.push()`.
- New routes go in `app/routes.dart` only. Path format: lowercase kebab-case.

## Env / secrets
```dart
Env.googlePlacesApiKey  // loaded from .env via flutter_dotenv
```
- Never hardcode API keys or base URLs in `.dart` files.
- App-wide constants → `AppConfig` / `core/constants/`.

## Firestore structure (short form)
```
/users/{uid}           favorites: string[], groups: string[]
/groups/{groupId}      members: string[], activeSessionId: string?, invite.code: string
  /sessions/{id}       swipeProgress: map<uid,int>, placePool: string[], status: 'in_progress'|'completed'
    /votes/{placeId}   likedBy: string[], dislikedBy: string[]
    /userSwipes/{uid}  swipedPlaceIds: string[]
/places/{placeId}      imageUrls: string[], types: string[]
```

## Known bugs — never reintroduce
1. **Favorites bug**: `place_detail_screen.dart` must NOT call `swipeController.like()` (advances swipe stack). Use `addFavoriteById(placeId)`.
2. **Firestore rule mismatch**: session `update` rule must allow `swipeProgress`, not `isCompleted`.
3. **UID display**: group member list must resolve UIDs to `UserModel.displayName`.
4. **German strings**: all UI text must be English. Catch: `Fehler`, `Zurück`, `Einstellungen`, `Datenschutz`, `Impressum`, `Überspringen`.

## Forbidden patterns (blocked or flagged by hooks)
- `Image.network(` → use `CachedNetworkImage(` (package not yet added — add it)
- Hardcoded secrets or URLs in `.dart`
- Cross-feature imports (`features/A` importing `features/B`)
- `Navigator.push()` anywhere — use GoRouter only
- `git commit`, `git push`, `rm -rf`, `firebase deploy` — blocked by `.claude/settings.json`

## MVP pending (as of June 2026)
- Google Places API key (currently mock data, 51 hardcoded places)
- `cached_network_image` package not yet added
- German strings remain in `settings_screen.dart`
- FCM push notifications (not started)
- Password reset screen (not started)
- Dark theme wired in `app.dart` (built in `theme.dart`, not applied yet)

## Review skills
- `/flutter-review` — Dart code rules check
- `/firestore-review` — rules vs model field names
- `/arch-review` — Feature-First compliance
- `/simulator-check` — visual verify in running simulator
