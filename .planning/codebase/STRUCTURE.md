# Codebase Structure

**Analysis Date:** 2026-07-04

## Directory Layout

```text
App/
|-- lib/                         # Flutter/Dart application source
|   |-- main.dart                 # Firebase bootstrap and ProviderScope root
|   |-- main_providers.dart       # Shared Riverpod dependency providers
|   |-- firebase_options.dart     # FlutterFire generated Firebase options
|   |-- app/                      # App shell, router, theme, navigation
|   |-- core/                     # Config, constants, errors, platform services
|   |-- common/                   # Shared models, utilities, reusable widgets
|   `-- features/                 # Feature-first UI/logic/data modules
|       |-- auth/
|       |-- group/
|       |-- home/
|       |-- onboarding/
|       |-- places/
|       |-- profile/
|       `-- swipe/
|-- test/                         # Flutter/unit tests
|-- android/ ios/ macos/ web/     # Flutter platform targets
|-- linux/ windows/               # Flutter desktop platform targets
|-- .agents/skills/               # Project-specific agent skill instructions
|-- .planning/codebase/           # Generated GSD codebase maps
|-- pubspec.yaml                  # Package manifest and Flutter assets
|-- analysis_options.yaml         # Analyzer and lint configuration
|-- firebase.json                 # Firebase project configuration
`-- .env                          # Environment configuration present; do not read contents
```

## Directory Purposes

**`lib/`:**
- Purpose: All Flutter application code.
- Contains: Entry points, app shell, feature modules, core services, common domain/shared code.
- Key files: `lib/main.dart`, `lib/app/app.dart`, `lib/app/routes.dart`, `lib/main_providers.dart`.

**`lib/app/`:**
- Purpose: App-level composition.
- Contains: `MobileApp`, GoRouter route table, shell navigation, Material theme.
- Key files: `lib/app/app.dart`, `lib/app/routes.dart`, `lib/app/shell_navigation.dart`, `lib/app/theme.dart`.

**`lib/core/`:**
- Purpose: Cross-cutting infrastructure that is not owned by a single feature.
- Contains: Config access, constants, error types, SDK/platform services.
- Key files: `lib/core/config/app_config.dart`, `lib/core/config/env.dart`, `lib/core/services/auth_service.dart`, `lib/core/services/firestore_service.dart`, `lib/core/services/location_service.dart`, `lib/core/services/preferences_service.dart`.

**`lib/common/`:**
- Purpose: Shared domain models, helpers, and reusable UI.
- Contains: Firestore/JSON model classes, utilities, common widgets.
- Key files: `lib/common/models/user_model.dart`, `lib/common/models/group_model.dart`, `lib/common/models/group_session_model.dart`, `lib/common/models/place_model.dart`, `lib/common/widgets/error_view.dart`, `lib/common/widgets/loading_spinner.dart`.

**`lib/features/`:**
- Purpose: Feature-first modules following UI, logic/controller, and data/repository layering.
- Contains: `auth`, `group`, `home`, `onboarding`, `places`, `profile`, and `swipe` features.
- Key files: `lib/features/auth/logic/auth_controller.dart`, `lib/features/group/logic/group_controller.dart`, `lib/features/swipe/logic/swipe_controller.dart`.

**`lib/features/auth/`:**
- Purpose: Firebase Auth login, signup, logout, and hydrated app user state.
- Contains: `data/auth_repository.dart`, `logic/auth_controller.dart`, `ui/login_screen.dart`, `ui/register_screen.dart`.
- Key files: `lib/features/auth/data/auth_repository.dart`, `lib/features/auth/logic/auth_controller.dart`.

**`lib/features/group/`:**
- Purpose: Group membership, invites, destination selection, active sessions, votes, and results.
- Contains: Firestore repository, controller/providers, group dashboard, group results screen, location repository.
- Key files: `lib/features/group/data/group_repository.dart`, `lib/features/group/data/location_repository.dart`, `lib/features/group/logic/group_controller.dart`, `lib/features/group/ui/simplified_group_screen.dart`, `lib/features/group/ui/group_matches_screen.dart`.

**`lib/features/swipe/`:**
- Purpose: Place discovery, swipe cards, standalone swipe results, and active-session votes.
- Contains: Places repository, swipe controller, swipe screen, extracted swipe widgets.
- Key files: `lib/features/swipe/data/places_repository.dart`, `lib/features/swipe/logic/swipe_controller.dart`, `lib/features/swipe/ui/swipe_screen.dart`, `lib/features/swipe/widgets/swipe_card.dart`, `lib/features/swipe/widgets/swipe_buttons.dart`.

**`lib/features/profile/`:**
- Purpose: User profile data, favorites, profile image selection/upload/delete, and settings/profile UI.
- Contains: Profile repository, image service, profile controller, profile/settings screens.
- Key files: `lib/features/profile/data/profile_repository.dart`, `lib/features/profile/data/image_service.dart`, `lib/features/profile/logic/profile_controller.dart`, `lib/features/profile/ui/simplified_profile_screen.dart`, `lib/features/profile/ui/settings_screen.dart`.

**`lib/features/places/`:**
- Purpose: Single place detail display and place-specific actions.
- Contains: Place detail screen and local place-detail provider.
- Key files: `lib/features/places/ui/place_detail_screen.dart`.

**`lib/features/home/`:**
- Purpose: Home/discover dashboard and favorites view.
- Contains: Home and favorites screens.
- Key files: `lib/features/home/ui/simplified_home_screen.dart`, `lib/features/home/ui/favorites_screen.dart`.

**`lib/features/onboarding/`:**
- Purpose: First-run onboarding flow and onboarding preference completion.
- Contains: Onboarding UI.
- Key files: `lib/features/onboarding/ui/onboarding_screen.dart`.

**`test/`:**
- Purpose: Dart/Flutter tests.
- Contains: Places API migration/stress tests and the default widget test.
- Key files: `test/places_api_migration_test.dart`, `test/places_api_stress_test.dart`, `test/widget_test.dart`.

**`.agents/skills/`:**
- Purpose: Project-specific agent instructions for Flutter feature work, refactors, theme work, translations, bug fixes, TDD, security, and verification.
- Contains: `SKILL.md` files for each skill.
- Key files: `.agents/skills/flutter-feature-builder/SKILL.md`, `.agents/skills/flutter-refactor/SKILL.md`.

## Key File Locations

**Entry Points:**
- `lib/main.dart`: Flutter `main()`; initializes Firebase and creates `ProviderScope`.
- `lib/app/app.dart`: Root `MobileApp`; builds `MaterialApp.router`.
- `lib/app/routes.dart`: Route declarations, redirects, shell route.

**Configuration:**
- `pubspec.yaml`: Flutter package manifest, dependencies, asset registration for `.env`.
- `analysis_options.yaml`: Flutter lint preset and analyzer excludes.
- `firebase.json`: Firebase configuration.
- `lib/firebase_options.dart`: FlutterFire-generated Firebase options.
- `lib/core/config/app_config.dart`: App constants and Google Places API enablement flag.
- `lib/core/config/env.dart`: `flutter_dotenv` loading and environment getters.
- `.env`: Environment configuration file present; do not read or commit secret values.

**Core Logic:**
- `lib/features/auth/logic/auth_controller.dart`: Auth state and auth actions.
- `lib/features/group/logic/group_controller.dart`: Group selection, group lifecycle, session lifecycle, active-session stream.
- `lib/features/swipe/logic/swipe_controller.dart`: Place deck loading, swipe/favorite actions, session vote delegation.
- `lib/features/profile/logic/profile_controller.dart`: Profile/favorite/image state.

**Data Access:**
- `lib/features/auth/data/auth_repository.dart`: Firebase Auth repository wrapper.
- `lib/features/group/data/group_repository.dart`: Firestore group/session/vote persistence.
- `lib/features/swipe/data/places_repository.dart`: Firestore places cache, Google Places HTTP calls, standalone swipe persistence.
- `lib/features/profile/data/profile_repository.dart`: Firestore user profile persistence.
- `lib/features/profile/data/image_service.dart`: Image picker and Firebase Storage profile image operations.
- `lib/features/group/data/location_repository.dart`: Static country/city location data.

**Shared Domain:**
- `lib/common/models/user_model.dart`: User profile model.
- `lib/common/models/group_model.dart`: Group, invite, and destination location models.
- `lib/common/models/group_session_model.dart`: Group session model and completion rules.
- `lib/common/models/place_model.dart`: Place model used by swipe/detail/results views.
- `lib/common/models/swipe_result_model.dart`: Standalone swipe result model.
- `lib/common/models/session_vote_model.dart`: Session vote model.

**Testing:**
- `test/places_api_migration_test.dart`: Places API/data migration related tests.
- `test/places_api_stress_test.dart`: Places API/data stress tests.
- `test/widget_test.dart`: Flutter widget test entry.

## Naming Conventions

**Files:**
- `snake_case.dart` for Dart files: `auth_controller.dart`, `group_repository.dart`, `place_detail_screen.dart`.
- Feature screens use `_screen.dart`: `login_screen.dart`, `swipe_screen.dart`, `simplified_group_screen.dart`.
- Controllers use `_controller.dart`: `auth_controller.dart`, `group_controller.dart`, `swipe_controller.dart`, `profile_controller.dart`.
- Data repositories use `_repository.dart`: `auth_repository.dart`, `group_repository.dart`, `places_repository.dart`, `profile_repository.dart`.
- Services use `_service.dart`: `auth_service.dart`, `firestore_service.dart`, `location_service.dart`, `image_service.dart`.
- Models use `_model.dart`: `user_model.dart`, `group_model.dart`, `place_model.dart`.

**Directories:**
- Feature modules use `lib/features/<feature>/`.
- Feature sublayers use `data/`, `logic/`, `ui/`, and `widgets/` when a feature has extracted widgets.
- Shared app infrastructure uses `lib/core/<concern>/`.
- Cross-feature reusable code uses `lib/common/<concern>/`.

## Where to Add New Code

**New Feature:**
- Primary code: create `lib/features/<feature>/ui/`, `lib/features/<feature>/logic/`, and `lib/features/<feature>/data/` as needed.
- Tests: add matching tests under `test/`, using feature names in test filenames.
- Routing: add route imports and `GoRoute` entries in `lib/app/routes.dart` only when the feature has a navigable screen.

**New Screen in Existing Feature:**
- Implementation: add `lib/features/<feature>/ui/<screen_name>_screen.dart`.
- State access: watch existing providers from `lib/features/<feature>/logic/`; add controller methods rather than putting data-access logic in the widget.
- Navigation: add or update route entries in `lib/app/routes.dart`.

**New Controller/Provider:**
- Implementation: add or extend `lib/features/<feature>/logic/<feature>_controller.dart`.
- Pattern: define the Riverpod provider near the notifier/controller it exposes.
- Dependencies: read repository/service providers instead of constructing SDK clients in UI.

**New Repository:**
- Implementation: add `lib/features/<feature>/data/<thing>_repository.dart`.
- Provider: expose the repository via a feature provider or `lib/main_providers.dart` when shared app-wide.
- Models: accept and return models from `lib/common/models/` or feature-local model files if the model is feature-private.

**Utilities:**
- Shared helpers: `lib/common/utils/`.
- Core platform helpers: `lib/core/services/`.
- App constants: `lib/core/constants/` or `lib/core/config/`.

**Reusable Widgets:**
- Cross-feature widgets: `lib/common/widgets/`.
- Feature-specific widgets: `lib/features/<feature>/widgets/`.
- Keep widget extraction inside the owning feature unless the widget is used by more than one feature.

**New Model:**
- Shared domain model: `lib/common/models/<name>_model.dart`.
- Keep `fromJson`, `toJson`, and `copyWith` on the model when it crosses repository/UI boundaries.
- Normalize Firestore `Timestamp` parsing inside model factories.

## Special Directories

**`.planning/codebase/`:**
- Purpose: GSD-generated codebase mapping documents.
- Generated: Yes
- Committed: Yes

**`.agents/skills/`:**
- Purpose: Project-specific agent workflow and coding rules.
- Generated: No
- Committed: Yes

**`.dart_tool/`:**
- Purpose: Dart/Flutter tool cache.
- Generated: Yes
- Committed: No

**`build/`:**
- Purpose: Flutter build outputs and generated test assets.
- Generated: Yes
- Committed: No

**Platform directories:**
- Purpose: Flutter platform host projects.
- Generated: Initially by Flutter; maintained as source when platform integration changes.
- Committed: Yes
- Paths: `android/`, `ios/`, `macos/`, `web/`, `linux/`, `windows/`.

**`.env`:**
- Purpose: Local environment configuration and Google Places API key source.
- Generated: No
- Committed: Treat as secret-bearing configuration; do not read or quote contents.

---

*Structure analysis: 2026-07-04*
