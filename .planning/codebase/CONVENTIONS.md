# Coding Conventions

**Analysis Date:** 2026-07-04

## Naming Patterns

**Files:**
- Use lowercase `snake_case.dart` for Dart files. Examples: `lib/features/swipe/logic/swipe_controller.dart`, `lib/features/group/data/group_repository.dart`, `lib/common/widgets/error_view.dart`.
- Feature screens live under `ui/` and typically end with `_screen.dart`. Examples: `lib/features/auth/ui/login_screen.dart`, `lib/features/group/ui/simplified_group_screen.dart`, `lib/features/places/ui/place_detail_screen.dart`.
- Feature controllers live under `logic/` and end with `_controller.dart`. Examples: `lib/features/auth/logic/auth_controller.dart`, `lib/features/swipe/logic/swipe_controller.dart`, `lib/features/profile/logic/profile_controller.dart`.
- Repositories live under `data/` and end with `_repository.dart`. Examples: `lib/features/swipe/data/places_repository.dart`, `lib/features/group/data/group_repository.dart`, `lib/features/profile/data/profile_repository.dart`.
- Shared models live under `lib/common/models/` and end with `_model.dart`. Examples: `lib/common/models/place_model.dart`, `lib/common/models/group_model.dart`, `lib/common/models/user_model.dart`.
- Shared widgets live under `lib/common/widgets/`; feature-only widgets live under `lib/features/{feature}/widgets/`. Examples: `lib/common/widgets/primary_button.dart`, `lib/features/swipe/widgets/swipe_card.dart`.
- Tests live under `test/` and end with `_test.dart`. Examples: `test/places_api_migration_test.dart`, `test/places_api_stress_test.dart`, `test/widget_test.dart`.

**Functions:**
- Use lowerCamelCase for functions, methods, and local helpers. Examples: `createRouter` in `lib/app/routes.dart`, `fetchAndCachePlacesForCity` in `lib/features/swipe/data/places_repository.dart`, `calculateGroupMatches` in `lib/features/group/logic/group_controller.dart`.
- Private helpers use a leading underscore. Examples: `_pickActiveSessionGroup` in `lib/app/routes.dart`, `_generateInviteCode` and `_buildMembersSignature` in `lib/features/group/logic/group_controller.dart`, `_syncFavoritesWithGroup` in `lib/features/swipe/logic/swipe_controller.dart`.
- Async methods return `Future<T>` or `Future<void>` and should use verb-led names. Examples: `login`, `signup`, `logout` in `lib/features/auth/logic/auth_controller.dart`; `recordSwipeInSession`, `startSwipeSession`, `streamUserGroups` in `lib/features/group/data/group_repository.dart`.

**Variables:**
- Use lowerCamelCase for locals and fields. Examples: `currentUser`, `groupState`, `sessionId`, `sharedFavorites`.
- Private controller/repository fields use a leading underscore. Examples: `_authRepo`, `_profileRepo`, `_authSubscription` in `lib/features/auth/logic/auth_controller.dart`; `_placesRepo`, `_currentIndex`, `_swipedPlaceIds` in `lib/features/swipe/logic/swipe_controller.dart`.
- Provider variables use lowerCamelCase and end with `Provider`. Examples: `authControllerProvider`, `groupRepositoryProvider`, `userGroupsProvider`, `activeSessionProvider`, `routerProvider`.
- Constants use `static const` or `const` lowerCamelCase. Examples: `_defaultRadiusKm` in `lib/features/swipe/logic/swipe_controller.dart`, `maxPlacesLimit` in `lib/core/config/app_config.dart`.

**Types:**
- Use PascalCase for classes and immutable model types. Examples: `PlaceModel`, `GroupModel`, `GroupSessionModel`, `SwipeController`, `GroupRepository`.
- Riverpod notifier classes end with `Controller` for feature state or `Notifier` for narrowly scoped state. Examples: `AuthController`, `GroupController`, `SelectedGroupIdNotifier`, `ActiveSessionNotifier`.
- Repository classes end with `Repository`. Examples: `AuthRepository`, `GroupRepository`, `PlacesRepository`, `ProfileRepository`, `LocationRepository`.
- Service classes end with `Service`. Examples: `AuthService`, `FirestoreService`, `LocationService`, `ImageService`.

## Code Style

**Formatting:**
- Use Dart and Flutter standard formatting through `dart format` or editor-integrated Dart formatting.
- The repo uses the default Flutter lint package via `analysis_options.yaml`.
- Prefer `const` constructors for widgets and immutable values where possible. Examples: `ProviderScope(child: MobileApp())` in `lib/main.dart`, `const ErrorView(...)` patterns in shared widgets.
- Prefer early returns for guard clauses. Examples: `if (group == null) return;` in `lib/features/group/logic/group_controller.dart`, `if (place == null) return;` in `lib/features/swipe/logic/swipe_controller.dart`.
- Keep UI text in English. This is a project rule in `AGENTS.md`, `CLAUDE.md`, and `.agents/skills/flutter-translator/SKILL.md`.
- Do not hardcode API keys. Use `Env` from `lib/core/config/env.dart` and app constants from `lib/core/config/app_config.dart`.

**Linting:**
- Tool: Flutter analyzer with `flutter_lints`.
- Config: `analysis_options.yaml`.
- Active include: `package:flutter_lints/flutter.yaml`.
- Analyzer excludes `build/**`.
- No custom lint rules are enabled beyond the default Flutter lints. Commented examples in `analysis_options.yaml` show `avoid_print` and `prefer_single_quotes` are not currently customized.
- Generated FlutterFire config uses `// ignore_for_file: type=lint` in `lib/firebase_options.dart`; do not copy this suppression into hand-written source files.

## Import Organization

**Order:**
1. Dart SDK imports first, when present. Examples: `dart:async` in `lib/features/auth/logic/auth_controller.dart`, `dart:convert` in `lib/features/swipe/data/places_repository.dart`.
2. Package imports next. Examples: `package:flutter_riverpod/flutter_riverpod.dart`, `package:cloud_firestore/cloud_firestore.dart`, `package:http/http.dart` in feature files and tests.
3. Relative project imports last. Examples: `../../../common/models/place_model.dart`, `../data/group_repository.dart`, `../../../main_providers.dart`.

**Path Aliases:**
- Most production source uses relative imports within `lib/`. Examples: `../../../common/models/group_model.dart` in `lib/features/group/logic/group_controller.dart`.
- Some files use package imports for app-internal modules. Example: `package:mobileapp/core/config/env.dart` in `lib/features/swipe/data/places_repository.dart`.
- Tests use package imports for app code. Examples: `package:mobileapp/features/swipe/data/places_repository.dart` and `package:mobileapp/common/models/place_model.dart` in `test/places_api_migration_test.dart`.
- Prefer consistency within a file. If a file already uses relative imports for app modules, continue that pattern unless a larger import cleanup is explicitly scoped.

## Error Handling

**Patterns:**
- Feature controllers expose loading, success, and failure through Riverpod `AsyncValue`. Set `state = const AsyncLoading()` before long-running mutations and `state = AsyncError(e, st)` on caught failures. Examples: `login` and `signup` in `lib/features/auth/logic/auth_controller.dart`, `refreshWithLocation` in `lib/features/swipe/logic/swipe_controller.dart`, `updateProfile` in `lib/features/profile/logic/profile_controller.dart`.
- Use `StateError` for invalid user/session state in controllers. Examples: unauthenticated group actions and admin-only session operations in `lib/features/group/logic/group_controller.dart`.
- Repositories currently throw plain `Exception` for external/data-layer failures. Examples: invite validation and session validation in `lib/features/group/data/group_repository.dart`, Google Places failures in `lib/features/swipe/data/places_repository.dart`, image upload failures in `lib/features/profile/data/image_service.dart`.
- Use fallback values only when the caller can safely continue. Examples: `ProfileRepository.getUserProfile` returns an empty `UserModel` fallback in `lib/features/profile/data/profile_repository.dart`; `PlacesRepository.getPlaceById` returns `null` on read/parsing failure in `lib/features/swipe/data/places_repository.dart`.
- Avoid swallowing errors unless the user flow intentionally proceeds optimistically. Existing optimistic swipe behavior catches persistence errors after advancing the UI in `lib/features/swipe/logic/swipe_controller.dart`.
- Use `ErrorView` for reusable UI error states with optional retry. Implementation: `lib/common/widgets/error_view.dart`.
- Validation helpers return nullable error strings for form fields. Implementation: `lib/common/utils/validators.dart`.
- `lib/core/errors/exceptions.dart` and `lib/core/errors/failure.dart` are placeholders; do not build new error flows around them until they are expanded.

## Logging

**Framework:** console / `print` only in isolated locations

**Patterns:**
- No structured logging framework is configured.
- Avoid new `print` calls in production code. Existing `print` usage appears in `lib/features/group/data/location_repository.dart` for HTTP country/city fetch errors.
- Surface user-facing failures through `AsyncError`, form validation strings, `ErrorView`, or SnackBars in UI files instead of console-only reporting.
- Keep secret values out of logs. Only env var names such as `GOOGLE_PLACES_API_KEY` may be referenced in docs or error messages.

## Comments

**When to Comment:**
- Use comments for non-obvious behavior, cost controls, generated code, and Firestore session transaction semantics.
- Good existing examples:
  - Cost-control notes in `lib/core/config/app_config.dart`.
  - Optimistic UI notes in `lib/features/swipe/logic/swipe_controller.dart`.
  - Firestore session comments in `lib/features/group/data/group_repository.dart`.
  - Route-flow comments in `lib/app/routes.dart`.
- Do not add comments that restate a method name or obvious assignment.

**JSDoc/TSDoc:**
- Not applicable for Dart.
- Dart doc comments (`///`) are used sparingly. Existing examples document session repository methods in `lib/features/group/data/group_repository.dart`.
- Use `///` for public repository/controller methods when the method has important invariants, transaction behavior, or caller obligations.

## Function Design

**Size:** Keep new functions focused and prefer extraction when UI or transaction logic grows.
- Repository methods may be longer when they encapsulate a complete Firestore transaction. Example: `recordSwipeInSession` in `lib/features/group/data/group_repository.dart`.
- UI files can be large in the current codebase, but new UI should prefer extracted widgets under `lib/features/{feature}/widgets/` or `lib/common/widgets/`.
- Follow `.agents/skills/flutter-refactor/SKILL.md` before extracting or deleting widgets: read the full source, update imports, and verify analyzer status.

**Parameters:** Use named required parameters for multi-field operations and positional parameters for simple identity lookups.
- Named examples: `startSwipeSession({required groupId, required destination, ...})` in `lib/features/group/data/group_repository.dart`, `castVote({required placeId, required liked})` in `lib/features/group/logic/group_controller.dart`.
- Positional examples: `getPlaceById(String id)` in `lib/features/swipe/data/places_repository.dart`, `getUserProfile(String uid)` in `lib/features/profile/data/profile_repository.dart`.
- Inject external clients into repositories for testability. Example: `PlacesRepository({FirebaseFirestore? firestore, http.Client? httpClient})` in `lib/features/swipe/data/places_repository.dart`.

**Return Values:** Use explicit async return types and immutable collections where callers should not mutate internal state.
- Controllers expose state through `AsyncNotifier<T>` or `StreamNotifier<T>`.
- Repository methods return domain models, lists, sets, or `void`. Examples: `Future<List<PlaceModel>>`, `Future<GroupSessionModel?>`, `Stream<List<GroupModel>>`.
- Expose defensive/unmodifiable collections for internal controller lists. Example: `favoritesList => List.unmodifiable(_favorites)` in `lib/features/swipe/logic/swipe_controller.dart`.

## Module Design

**Exports:** Direct imports; no barrel files detected.
- There are no `export` barrel modules in `lib/`.
- Import the concrete module needed by the feature. Examples: `lib/features/group/logic/group_controller.dart` imports `../data/group_repository.dart`; UI files import their feature controller directly.

**Barrel Files:** Not used.
- Do not add barrel files unless a broader architecture phase introduces them consistently.

## State Management

**Riverpod:**
- Global singleton providers live in `lib/main_providers.dart`. Examples: `authServiceProvider`, `firestoreServiceProvider`, `locationServiceProvider`, `profileRepositoryProvider`.
- App routing is exposed through `routerProvider` in `lib/app/routes.dart` and watched by `MobileApp` in `lib/app/app.dart`.
- Feature state uses Riverpod 3 notifiers:
  - `AsyncNotifierProvider<AuthController, UserModel?>` in `lib/features/auth/logic/auth_controller.dart`.
  - `AsyncNotifierProvider<GroupController, GroupModel?>` and `StreamProvider<List<GroupModel>>` in `lib/features/group/logic/group_controller.dart`.
  - `AsyncNotifierProvider<SwipeController, List<PlaceModel>>` in `lib/features/swipe/logic/swipe_controller.dart`.
  - `AsyncNotifierProvider<ProfileController, UserModel?>` in `lib/features/profile/logic/profile_controller.dart`.
  - `StreamNotifierProvider<ActiveSessionNotifier, GroupSessionModel?>` in `lib/features/group/logic/group_controller.dart`.
- Use `ref.watch` for reactive dependencies inside `build()` and providers. Examples: `userGroupsProvider` watches `authControllerProvider`; `GroupController.build` watches `selectedGroupIdProvider` and `userGroupsProvider`.
- Use `ref.read` for one-shot commands and repository/service access inside mutations. Examples: `ref.read(groupRepositoryProvider)`, `ref.read(authControllerProvider)`, `ref.read(firestoreServiceProvider)`.
- Use `ref.invalidateSelf()` after state resets. Existing example: `resetAll` in `lib/features/swipe/logic/swipe_controller.dart`.
- Register provider cleanup with `ref.onDispose`. Existing example: auth stream subscription cleanup in `lib/features/auth/logic/auth_controller.dart`.

## Architecture Rules

**Feature-first clean architecture:**
- UI belongs in `lib/features/{feature}/ui/`.
- Controllers and notifiers belong in `lib/features/{feature}/logic/`.
- Repositories belong in `lib/features/{feature}/data/`.
- Feature-scoped widgets belong in `lib/features/{feature}/widgets/`.
- Shared widgets, models, and utils belong in `lib/common/`.
- App-wide services, config, constants, and errors belong in `lib/core/`.
- App shell, theme, and routing belong in `lib/app/`.

**Layer constraints:**
- UI may watch providers and call controller methods, but business logic belongs in controllers or repositories.
- Controllers should not use `BuildContext`.
- Repositories should not use `ref.watch` and should not import Flutter UI packages.
- Use GoRouter navigation (`context.go`, `context.push`) rather than `Navigator.push`. Route definitions live in `lib/app/routes.dart`.
- Use `CachedNetworkImage` for network images instead of `Image.network`. Existing examples: `lib/common/widgets/place_card.dart`, `lib/features/swipe/widgets/swipe_card.dart`.
- Never mix mock Google place IDs with real Google Places API IDs.

## Documentation Expectations

**Project docs:**
- Keep project-level architecture and product decisions in root Markdown files such as `PROJECT_CORE_IDEA_CANONICAL.md`, `PROJECT_ARCHITECTURE_CANONICAL.md`, and `.planning/PROJECT.md`.
- Testing readiness for Places API migration is documented in `TEST_READY.md`.
- Agent-facing implementation rules are duplicated in `AGENTS.md` and `CLAUDE.md`; preserve those constraints in future plans.
- Local workflow skills under `.agents/skills/` define additional rules for Flutter fixes, features, refactors, translation cleanup, TDD, verification, and security review.

---

*Convention analysis: 2026-07-04*
