---
phase: 02-mvp-correctness-stabilization
plan: 02-01
subsystem: mvp-correctness
tags: [favorites, routing, env-startup, flutter, riverpod, gorouter]

requires:
  - Phase 01 real Places cache and Env configuration
provides:
  - Direct favorite place ID loading
  - Non-swipe place detail favorite mutation
  - Active-session route allowlist for normal app sections
  - Testable dotenv-before-Firebase startup order
affects: [favorites, place-detail, swipe-controller, routing, startup]

key-files:
  created:
    - test/mvp_correctness_stabilization_test.dart
    - docs/testing/mvp-correctness-stabilization.tdd.md
    - .planning/phases/02-mvp-correctness-stabilization/02-CONTEXT.md
    - .planning/phases/02-mvp-correctness-stabilization/02-01-PLAN.md
    - .planning/phases/02-mvp-correctness-stabilization/02-01-SUMMARY.md
  modified:
    - lib/features/swipe/data/places_repository.dart
    - lib/features/home/ui/favorites_screen.dart
    - lib/features/swipe/logic/swipe_controller.dart
    - lib/features/places/ui/place_detail_screen.dart
    - lib/app/routes.dart
    - lib/main.dart
    - lib/main_providers.dart

requirements-completed: [REQ-04]

coverage:
  - id: D1
    description: "Favorites resolve place documents directly by favorite IDs, preserve order, and skip missing documents."
    requirement: REQ-05
    verification:
      - kind: unit
        ref: "flutter test test/mvp_correctness_stabilization_test.dart"
        status: pass
    human_judgment: false
  - id: D2
    description: "Active sessions allow intentional navigation to profile, settings, favorites, and group pages."
    requirement: REQ-07
    verification:
      - kind: unit
        ref: "flutter test test/mvp_correctness_stabilization_test.dart"
        status: pass
    human_judgment: false
  - id: D3
    description: "Startup initializes Env before Firebase and app rendering."
    requirement: REQ-06
    verification:
      - kind: unit
        ref: "flutter test test/mvp_correctness_stabilization_test.dart"
        status: pass
    human_judgment: false

completed: 2026-07-05
status: complete
---

# Phase 2: MVP Correctness Stabilization Summary

Implemented the Phase 2 correctness sweep for favorites/detail behavior, active-session routing, and dotenv startup.

## Accomplishments

- Added `PlacesRepository.loadPlacesByIds` and changed the favorites screen to load favorite place documents directly instead of using `loadNearbyPlaces(0, 0)`.
- Added `SwipeController.addFavorite(placeId)` and changed place detail "Add to Favorites" to target the displayed place without advancing the swipe deck.
- Extracted and tested `isActiveSessionRouteAllowed`, then used it to let active-session users intentionally reach profile, settings, favorites, and group pages.
- Extracted and tested `bootstrapApp`, ensuring `Env.init()` runs before Firebase initialization.
- Added focused regression tests for the Phase 2 correctness fixes.

## Verification

- `$HOME/flutter/bin/flutter test test/mvp_correctness_stabilization_test.dart` - passed, 3 tests.
- `$HOME/flutter/bin/flutter test test/places_api_migration_test.dart` - passed, 11 tests.
- `$HOME/flutter/bin/flutter analyze` - passed, no issues found.

## Deviations

No schema migration was introduced. Favorites use the existing `/places/{placeId}` cache documents and existing profile `favorites` IDs.

## Next Phase Readiness

Phase 3 can now focus on English copy and settings accuracy without carrying the Phase 2 correctness bugs forward.
