<!-- refreshed: 2026-07-04 -->
# Architecture

**Analysis Date:** 2026-07-04

## System Overview

```text
+-------------------------------------------------------------+
| Flutter application shell                                   |
| `lib/main.dart` -> `lib/app/app.dart` -> `lib/app/routes.dart` |
+------------------+------------------+-----------------------+
| Auth UI          | Group UI         | Swipe/Profile/Place UI |
| `lib/features/auth/ui` | `lib/features/group/ui` | `lib/features/*/ui` |
+--------+---------+--------+---------+----------+------------+
         |                  |                    |
         v                  v                    v
+-------------------------------------------------------------+
| Riverpod controllers and feature providers                  |
| `lib/features/*/logic/*_controller.dart`                    |
+-------------------------------------------------------------+
         |                  |                    |
         v                  v                    v
+-------------------------------------------------------------+
| Repositories and platform services                          |
| `lib/features/*/data/*_repository.dart`, `lib/core/services` |
+-------------------------------------------------------------+
         |                  |                    |
         v                  v                    v
+-------------------------------------------------------------+
| Firebase Auth, Cloud Firestore, Firebase Storage,            |
| Google Places HTTP API, Geolocator, SharedPreferences        |
| `lib/firebase_options.dart`, `lib/core/config/*`             |
+-------------------------------------------------------------+
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| Bootstrap | Initialize Flutter bindings, Firebase, and the root Riverpod `ProviderScope`. | `lib/main.dart` |
| App shell | Create `MaterialApp.router` with the app theme and router provider. | `lib/app/app.dart` |
| Router | Own GoRouter routes, onboarding/auth redirects, active-session redirects, and shell navigation wiring. | `lib/app/routes.dart` |
| Shell navigation | Provide persistent bottom navigation for home, group, and profile areas. | `lib/app/shell_navigation.dart` |
| Shared providers | Register core service singletons and shared repositories for Riverpod. | `lib/main_providers.dart` |
| Auth feature | Authenticate with Firebase Auth and hydrate app user state from Firestore profiles. | `lib/features/auth/logic/auth_controller.dart`, `lib/features/auth/data/auth_repository.dart` |
| Group feature | Create/join groups, maintain selected group state, stream user groups and active sessions, and manage session voting. | `lib/features/group/logic/group_controller.dart`, `lib/features/group/data/group_repository.dart` |
| Swipe feature | Load candidate places, track swipe position/favorites/swiped IDs, and record standalone or group-session votes. | `lib/features/swipe/logic/swipe_controller.dart`, `lib/features/swipe/data/places_repository.dart` |
| Profile feature | Load and update user profile data, favorites, and profile images. | `lib/features/profile/logic/profile_controller.dart`, `lib/features/profile/data/profile_repository.dart`, `lib/features/profile/data/image_service.dart` |
| Places detail | Read one place by route id and display actions/maps/favorite state. | `lib/features/places/ui/place_detail_screen.dart` |
| Domain models | Provide immutable JSON/Firestore mapping for users, groups, sessions, places, votes, and swipe results. | `lib/common/models/*.dart` |
| Core services | Wrap Firebase Auth, Firestore, location, maps, preferences, and config access. | `lib/core/services/*.dart`, `lib/core/config/*.dart` |

## Pattern Overview

**Overall:** Feature-first clean architecture with Riverpod state management and GoRouter navigation.

**Key Characteristics:**
- Put user-facing widgets in `lib/features/<feature>/ui/`.
- Put feature state, orchestration, and business decisions in `lib/features/<feature>/logic/`.
- Put Firestore, Firebase Auth, Firebase Storage, HTTP, and static data access in `lib/features/<feature>/data/` or `lib/core/services/`.
- Share cross-feature models and reusable UI through `lib/common/`.
- Register app-wide dependencies through Riverpod providers in `lib/main_providers.dart` and feature provider files.

## Layers

**Bootstrap and App Shell:**
- Purpose: Start Firebase and render the router-backed Flutter app.
- Location: `lib/main.dart`, `lib/app/app.dart`
- Contains: `main()`, `MobileApp`, `MaterialApp.router`, `ProviderScope`.
- Depends on: `firebase_core`, `flutter_riverpod`, `lib/firebase_options.dart`, `lib/app/routes.dart`, `lib/app/theme.dart`.
- Used by: Native Flutter platform entry points in `android/`, `ios/`, `macos/`, `web/`, `linux/`, and `windows/`.

**Routing:**
- Purpose: Centralize navigation paths and redirect rules.
- Location: `lib/app/routes.dart`, `lib/app/shell_navigation.dart`
- Contains: `routerProvider`, `createRouter`, `ShellRoute`, `GoRoute` definitions, onboarding/auth/session redirects.
- Depends on: `authControllerProvider`, `userGroupsProvider`, `PreferencesService`, feature UI screens.
- Used by: `MobileApp` in `lib/app/app.dart`.

**Presentation/UI:**
- Purpose: Render screens and collect user intent.
- Location: `lib/features/*/ui/`, `lib/features/swipe/widgets/`, `lib/common/widgets/`
- Contains: Flutter `Widget`, `ConsumerWidget`, and `ConsumerStatefulWidget` classes.
- Depends on: Riverpod providers, GoRouter, common models/widgets.
- Used by: Routes in `lib/app/routes.dart`.

**Logic/Controller:**
- Purpose: Own feature state transitions, input validation at the feature boundary, and coordination between repositories.
- Location: `lib/features/*/logic/*_controller.dart`
- Contains: `AsyncNotifier`, `StreamNotifier`, `Notifier`, `StreamProvider`, and `FutureProvider` definitions.
- Depends on: Repositories, core service providers, common models, other feature providers when a workflow crosses a feature boundary.
- Used by: Feature UI and router redirects.

**Data/Repository:**
- Purpose: Translate app operations into Firebase, Firestore, Storage, HTTP, or local static data calls.
- Location: `lib/features/*/data/*_repository.dart`, `lib/features/profile/data/image_service.dart`
- Contains: Repository classes such as `AuthRepository`, `GroupRepository`, `PlacesRepository`, `ProfileRepository`, and `LocationRepository`.
- Depends on: `lib/core/services/*`, Firebase SDKs, `http`, `image_picker`, common models.
- Used by: Logic providers and a small number of screen-local providers.

**Core Services:**
- Purpose: Provide low-level wrappers around platform and external SDKs.
- Location: `lib/core/services/`, `lib/core/config/`
- Contains: `AuthService`, `FirestoreService`, `LocationService`, `MapsLauncher`, `PreferencesService`, `Env`, `AppConfig`.
- Depends on: Firebase Auth, Cloud Firestore, Geolocator, URL launcher, SharedPreferences, flutter_dotenv.
- Used by: Repositories, controllers, routes, and onboarding.

**Shared Domain:**
- Purpose: Define app data shapes and reusable helpers.
- Location: `lib/common/models/`, `lib/common/utils/`, `lib/common/widgets/`
- Contains: Immutable model classes with `fromJson`, `toJson`, and `copyWith`; utility functions; reusable view widgets.
- Depends on: `cloud_firestore` for timestamp conversion in models and Flutter for widgets.
- Used by: All feature layers.

## Data Flow

### Primary Request Path

1. Flutter starts, initializes Firebase, and runs `ProviderScope(child: MobileApp())` (`lib/main.dart:8`).
2. `MobileApp` watches `routerProvider` and creates `MaterialApp.router` (`lib/app/app.dart:9`).
3. `routerProvider` creates GoRouter, listens to auth and group providers, and applies redirects (`lib/app/routes.dart:21`).
4. A route builds a feature screen such as `SwipeScreen` for `/swipe/:groupId` (`lib/app/routes.dart:99`).
5. The screen watches a Riverpod controller such as `swipeControllerProvider` (`lib/features/swipe/ui/swipe_screen.dart`).
6. The controller loads data from repositories and services, then emits `AsyncData` or `AsyncError` (`lib/features/swipe/logic/swipe_controller.dart:26`).
7. Repositories read/write Firebase, Firestore, HTTP APIs, or local services and return common models (`lib/features/swipe/data/places_repository.dart:21`).

### Authentication Flow

1. `AuthController.build()` creates `AuthRepository` and subscribes to Firebase Auth state (`lib/features/auth/logic/auth_controller.dart:17`).
2. Firebase users are hydrated from Firestore profiles through `ProfileRepository.getUserProfile()` (`lib/features/auth/logic/auth_controller.dart:25`).
3. Login and signup set `AsyncLoading`, call `AuthRepository`, then emit hydrated `UserModel` or `AsyncError` (`lib/features/auth/logic/auth_controller.dart:53`).
4. Router redirects unauthenticated users to `/login` after onboarding is complete (`lib/app/routes.dart:47`).

### Group Session Flow

1. `userGroupsProvider` streams Firestore groups where the authenticated user is a member (`lib/features/group/logic/group_controller.dart:26`).
2. `selectedGroupIdProvider` chooses the active group for `GroupController.build()` (`lib/features/group/logic/group_controller.dart:16`).
3. `GroupController.startSessionWithLimit()` fetches places for the group location and starts a Firestore session (`lib/features/group/logic/group_controller.dart:239`).
4. `GroupRepository.startSwipeSession()` writes the session document and updates the parent group with `activeSessionId` (`lib/features/group/data/group_repository.dart:173`).
5. `activeSessionProvider` streams the active session document for live UI changes (`lib/features/group/logic/group_controller.dart:381`).
6. Router sends logged-in users with an active group session to `/swipe/<groupId>` (`lib/app/routes.dart:61`).

### Swipe and Vote Flow

1. `SwipeController.build()` loads location, auth user, profile favorites, group session state, and swiped place ids (`lib/features/swipe/logic/swipe_controller.dart:26`).
2. With an active group session, the controller resolves `session.placePool` into `PlaceModel` instances and filters already-swiped places (`lib/features/swipe/logic/swipe_controller.dart:67`).
3. Without an active group session, the controller loads nearby cached places from Firestore and filters standalone swipes (`lib/features/swipe/logic/swipe_controller.dart:83`).
4. `like()` and `skip()` advance UI state immediately, then persist either group-session votes or standalone swipe results (`lib/features/swipe/logic/swipe_controller.dart:121`).
5. `GroupRepository.recordSwipeInSession()` records votes, updates per-user progress, and completes the session when all participants are done (`lib/features/group/data/group_repository.dart:233`).
6. `GroupMatchesScreen` reads completed sessions and qualified places to render sorted results (`lib/features/group/ui/group_matches_screen.dart`).

### Places Cache Flow

1. Group session startup calls `PlacesRepository.fetchAndCachePlacesForCity()` with `GroupLocation` (`lib/features/group/logic/group_controller.dart:257`).
2. The repository checks Firestore `places` by `cityId` before any external API call (`lib/features/swipe/data/places_repository.dart:29`).
3. On cache miss, the repository checks `AppConfig.enableRealPlacesAPI` and `Env.googlePlacesApiKey` before calling Google Places Nearby Search (`lib/features/swipe/data/places_repository.dart:40`).
4. API results map into `PlaceModel` and are cached in Firestore under `places/<place.id>` (`lib/features/swipe/data/places_repository.dart:102`).

**State Management:**
- Use Riverpod providers as the app state boundary: `Provider`, `AsyncNotifierProvider`, `NotifierProvider`, `StreamProvider`, `StreamNotifierProvider`, `FutureProvider.family`.
- Use `AsyncValue.when` in UI screens to render loading, error, and data states.
- Use Firestore streams for live group/session data and explicit provider invalidation for refresh actions.
- Use model `copyWith` methods for immutable updates in `lib/common/models/*.dart`.

## Key Abstractions

**Riverpod Providers:**
- Purpose: Dependency injection and reactive state.
- Examples: `routerProvider` in `lib/app/routes.dart`, `authControllerProvider` in `lib/features/auth/logic/auth_controller.dart`, `groupControllerProvider` in `lib/features/group/logic/group_controller.dart`, `swipeControllerProvider` in `lib/features/swipe/logic/swipe_controller.dart`.
- Pattern: Define the provider beside the controller or service it exposes; watch providers in widgets, read providers inside event handlers and controller methods.

**Controllers:**
- Purpose: Feature orchestration and state transitions.
- Examples: `AuthController`, `GroupController`, `SwipeController`, `ProfileController`.
- Pattern: Extend `AsyncNotifier<T>` for async feature state; expose methods for user actions; use `state = AsyncLoading()`, `AsyncData(...)`, or `AsyncError(e, st)`.

**Repositories:**
- Purpose: Data access and persistence.
- Examples: `AuthRepository`, `GroupRepository`, `PlacesRepository`, `ProfileRepository`, `LocationRepository`.
- Pattern: Keep SDK calls and collection names in repository/data files; return common models to controllers.

**Common Models:**
- Purpose: Stable app data contracts across UI, logic, repositories, and Firestore.
- Examples: `UserModel`, `GroupModel`, `GroupSessionModel`, `PlaceModel`, `SwipeResultModel`, `SessionVoteModel`.
- Pattern: Use immutable classes with `fromJson`, `toJson`, and `copyWith`; normalize Firestore `Timestamp` values in model parsing.

**Core Services:**
- Purpose: Thin wrappers around SDKs and platform APIs.
- Examples: `FirestoreService`, `AuthService`, `LocationService`, `PreferencesService`, `MapsLauncher`.
- Pattern: Keep platform details in `lib/core/services/`; expose simple methods consumed by repositories/controllers.

## Entry Points

**Flutter app startup:**
- Location: `lib/main.dart`
- Triggers: Flutter runtime invokes `main()`.
- Responsibilities: Ensure Flutter bindings, initialize Firebase with `DefaultFirebaseOptions.currentPlatform`, and run `MobileApp` inside `ProviderScope`.

**App widget:**
- Location: `lib/app/app.dart`
- Triggers: `main()` creates `MobileApp`.
- Responsibilities: Watch `routerProvider`, apply `AppTheme.light`, and configure `MaterialApp.router`.

**Navigation table and redirects:**
- Location: `lib/app/routes.dart`
- Triggers: `MaterialApp.router` consumes `routerProvider`.
- Responsibilities: Define route paths, shell navigation, onboarding/auth redirects, and active-session redirects.

**Feature screens:**
- Location: `lib/features/*/ui/*.dart`
- Triggers: GoRouter route builders.
- Responsibilities: Render UI from providers and dispatch user actions to controllers.

**Provider graph root:**
- Location: `lib/main_providers.dart`
- Triggers: Controllers and widgets read/watch shared providers.
- Responsibilities: Provide app-wide instances of auth, Firestore, location, and profile repository dependencies.

## Architectural Constraints

- **Threading:** Flutter runs UI and Riverpod state on the main isolate; Firebase, HTTP, location, and storage work is asynchronous through `Future` and `Stream`.
- **Global state:** Firebase SDK singletons appear in `lib/core/services/auth_service.dart`, `lib/core/services/firestore_service.dart`, `lib/features/group/data/group_repository.dart`, and `lib/features/swipe/data/places_repository.dart`; Riverpod provider state is rooted by `ProviderScope` in `lib/main.dart`.
- **Circular imports:** No direct circular source import chain is apparent from the inspected feature files. Cross-feature dependencies are present: `lib/features/swipe/logic/swipe_controller.dart` imports group/auth/profile logic/data; `lib/features/group/logic/group_controller.dart` imports auth/profile/swipe dependencies.
- **Navigation coupling:** `lib/app/routes.dart` imports feature UI and selected feature state providers directly; route redirects depend on onboarding preferences, auth state, and group stream state.
- **Firestore schema coupling:** Collection and subcollection names are embedded in repositories: `groups`, `groups/<id>/sessions`, `votes`, `userSwipes`, `places`, `swipeResults`, and `users`.
- **Configuration:** `.env` is listed as a Flutter asset in `pubspec.yaml`; config access is defined in `lib/core/config/env.dart` and `lib/core/config/app_config.dart`.

## Anti-Patterns

### UI Directly Instantiates Repositories

**What happens:** Some UI/provider files create repositories directly, such as `PlacesRepository()` in `lib/features/places/ui/place_detail_screen.dart` and `lib/features/group/ui/group_matches_screen.dart`, and `LocationRepository()` in `lib/features/group/ui/simplified_group_screen.dart`.
**Why it's wrong:** It bypasses the feature controller/repository provider boundary, making dependencies harder to override in tests and spreading data-access decisions into UI files.
**Do this instead:** Define a provider in the feature logic/data layer, then have UI watch/read that provider. Use the `groupRepositoryProvider` pattern in `lib/features/group/logic/group_controller.dart:12` or the shared provider pattern in `lib/main_providers.dart:7`.

### Controllers Construct Dependencies Inline

**What happens:** Controllers construct repositories inside methods or getters, such as `PlacesRepository()` and `ProfileRepository(ref.read(firestoreServiceProvider))` in `lib/features/swipe/logic/swipe_controller.dart` and `lib/features/group/logic/group_controller.dart`.
**Why it's wrong:** Inline construction weakens Riverpod dependency injection and makes tests depend on real Firebase/HTTP unless constructor overrides are manually threaded.
**Do this instead:** Expose repositories through providers beside the repository or in `lib/main_providers.dart`, then read the provider from controllers.

### Router Owns Business Redirect Decisions

**What happens:** `lib/app/routes.dart` reads `userGroupsProvider`, `authControllerProvider`, and onboarding preferences to decide auth and active-session redirects.
**Why it's wrong:** Router logic becomes coupled to feature state and async Firestore streams, so changes in group/session rules can require edits in the app shell.
**Do this instead:** Keep low-level route declarations in `lib/app/routes.dart`, but move reusable redirect decisions into focused feature/provider helpers when rules expand.

## Error Handling

**Strategy:** Surface user-facing async states through Riverpod `AsyncValue`, while repositories throw exceptions for invalid operations and return null/empty fallbacks for missing optional data.

**Patterns:**
- Controllers set `AsyncLoading`, `AsyncData`, and `AsyncError` around user actions (`lib/features/auth/logic/auth_controller.dart`, `lib/features/profile/logic/profile_controller.dart`, `lib/features/group/logic/group_controller.dart`).
- UI renders `AsyncValue.when` branches for loading, error, and data (`lib/features/swipe/ui/swipe_screen.dart`, `lib/features/group/ui/simplified_group_screen.dart`, `lib/features/group/ui/group_matches_screen.dart`).
- Repositories throw exceptions for invalid group/session states (`lib/features/group/data/group_repository.dart`) and Google Places failures (`lib/features/swipe/data/places_repository.dart`).
- Some noncritical paths intentionally swallow errors and continue, such as location fallback and favorite/group sync in `lib/features/swipe/logic/swipe_controller.dart`.

## Cross-Cutting Concerns

**Logging:** No structured logging framework is detected. Error handling is mostly state-based; caught errors are often ignored or converted to `AsyncError`.
**Validation:** Auth/session/group rules are checked in controllers and repositories. Utility validators live in `lib/common/utils/validators.dart`.
**Authentication:** Firebase Auth is wrapped by `AuthService` and `AuthRepository`, then exposed as hydrated `UserModel?` through `authControllerProvider`.
**Configuration:** App constants live in `lib/core/config/app_config.dart`; environment access is in `lib/core/config/env.dart`.
**Reusable UI:** Shared loading, error, button, and place-card widgets live in `lib/common/widgets/`.

---

*Architecture analysis: 2026-07-04*
