# SwipeTrip Project Context Index

## Purpose

This is the first file a coding agent should read before changing SwipeTrip. It points to the durable sources of truth and gives the fastest route from a task to the code and logic that matter.

SwipeTrip is a Flutter mobile app for solo and group travel-place discovery. Users swipe through real places, save favorites, and run group sessions where shared matches are calculated from each member's votes.

Older files may call the project Traveller App. Use SwipeTrip for product-facing language.

## Source Of Truth Order

1. `AGENTS.md` - current agent workflow and coding rules.
2. `PROJECT_CORE_IDEA_CANONICAL.md` - product intent, user flows, and scope boundaries.
3. `PROJECT_ARCHITECTURE_CANONICAL.md` - architecture, data model, risks, and recommended fixes.
4. `PROJECT_LOGIC_MAP.md` - critical runtime flows and high-risk behavior.
5. `PROJECT_REFRESH_PLAYBOOK.md` - manual process for keeping docs and codebase-memory current.
6. Current source code - final authority when docs and code disagree.

Historical Markdown files can be useful for audit context, but they may describe older mock-based flows or planned behavior. Prefer the canonical docs above.

## Architecture At A Glance

The app follows feature-first clean architecture:

```text
lib/app/
  app shell, routing, shell navigation, theme

lib/common/
  shared models, widgets, validators, formatters, geo helpers

lib/core/
  config, constants, errors, app-wide Firebase/device/local services

lib/features/{feature}/ui/
  screens and view composition

lib/features/{feature}/logic/
  Riverpod controllers and feature state

lib/features/{feature}/data/
  repositories and external data access
```

Primary dependencies are Riverpod 3, GoRouter 17, Firebase Auth, Cloud Firestore, Firebase Storage, Google Places API New Nearby Search, `flutter_dotenv`, `http`, `cached_network_image`, `mocktail`, and `fake_cloud_firestore`.

## Where To Look Before Coding

- Bootstrap/config: `lib/main.dart`, `lib/main_providers.dart`, `lib/core/config/env.dart`, `lib/core/config/app_config.dart`.
- Routing/auth guards: `lib/app/routes.dart`, `lib/features/auth/logic/auth_controller.dart`, `lib/features/auth/data/auth_repository.dart`, `lib/core/services/auth_service.dart`.
- Onboarding: `lib/features/onboarding/ui/onboarding_screen.dart`, `lib/core/services/preferences_service.dart`.
- Place model and place cards: `lib/common/models/place_model.dart`, `lib/common/widgets/place_card.dart`, `lib/features/places/ui/place_detail_screen.dart`.
- Places API and caching: `lib/features/swipe/data/places_repository.dart`, `test/places_api_migration_test.dart`, `test/places_api_stress_test.dart`.
- Solo swipe/favorites: `lib/features/swipe/logic/swipe_controller.dart`, `lib/features/swipe/ui/swipe_screen.dart`, `lib/features/home/ui/favorites_screen.dart`.
- Group data/session logic: `lib/features/group/data/group_repository.dart`, `lib/features/group/logic/group_controller.dart`, `lib/common/models/group_model.dart`, `lib/common/models/group_session_model.dart`, `lib/common/models/session_vote_model.dart`.
- Group UI/matches: `lib/features/group/ui/simplified_group_screen.dart`, `lib/features/group/ui/group_matches_screen.dart`.
- Profile: `lib/features/profile/data/profile_repository.dart`, `lib/features/profile/logic/profile_controller.dart`, `lib/features/profile/data/image_service.dart`, `lib/features/profile/ui/simplified_profile_screen.dart`.

## Codebase-Memory Search Recipes

Use codebase-memory MCP first:

```text
search_graph(query="group session vote transaction record swipe completion matches", file_pattern="*.dart")
search_graph(query="places repository cache Google Places API city firestore fetch cache", file_pattern="*.dart")
search_graph(query="auth routing onboarding GoRouter redirect authController userGroupsProvider", file_pattern="*.dart")
search_code(pattern="enableRealPlacesAPI|googlePlacesApiKey|flutter_dotenv|places:searchNearby", file_pattern="*.dart")
```

After finding a symbol, use `get_code_snippet` for the exact qualified name. Use grep or file reads for Markdown, config files, generated files, and literal strings that are not represented well in the graph.

## Current High-Risk Areas

- `GroupRepository.recordSwipeInSession` coordinates voting, progress, duplicate prevention, and session completion in one Firestore transaction.
- GoRouter redirects depend on onboarding, auth, and group stream state, so async timing can create loops or stale navigation.
- Places API usage depends on correct `Env` initialization, `AppConfig`, API field masks, city-scoped cache behavior, and real Google Places IDs.
- Firestore rules may drift from current session/vote field names.
- `loadNearbyPlaces` performs local distance filtering and can become expensive with larger cached datasets.
- Mobile `.env` is not a production secret strategy; use API restrictions at minimum and consider a backend proxy before release.

## Optional Skill Context

Repo-local Flutter/Dart skills are present under `.agents/skills`, including widget tests, routing, architecture, analysis, bug fixing, HTTP usage, and responsive layout. Codex should only rely on them if the runtime exposes repo-local skills in the active session. Claude-only skills under `.claude/skills` should not be treated as Codex-visible.
