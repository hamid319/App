# Phase 2: MVP Correctness Stabilization - Context

**Gathered:** 2026-07-05T12:17:53Z
**Status:** Ready for planning
**Source:** Prior approved MVP polish sweep plan

<domain>
## Phase Boundary

This phase stabilizes correctness bugs in existing MVP flows before copy, visual, profile, or group consensus work. It covers favorites list loading, place detail favorite mutation behavior, active-session router escape hatches, and dotenv startup order.

</domain>

<decisions>
## Implementation Decisions

### Favorites and Detail Correctness
- **D-01:** Favorites must resolve the authenticated user's favorite place IDs directly from Firestore place documents, preserving favorite order and skipping missing documents.
- **D-02:** Place detail "Add to Favorites" must mutate the displayed place ID directly and must not call the swipe deck `like()` path because that advances the current card.
- **D-03:** The direct favorite mutation should reuse existing `SwipeController` state and profile persistence so the favorites list and detail button remain reactive.

### Active-Session Routing
- **D-04:** Active group sessions may still redirect general landing/home routes to the current swipe route.
- **D-05:** Explicit navigation to `/profile`, `/settings`, `/favorites`, `/group`, `/group/*`, `/swipe/*`, and `/group-matches/*` must be allowed while a group session is active.

### Startup Environment
- **D-06:** App startup must initialize `flutter_dotenv` through `Env.init()` before Firebase initialization completes and before repositories read `Env.googlePlacesApiKey` or `Env.geminiApiKey`.
- **D-07:** Startup order should be testable without invoking real Firebase.

### the agent's Discretion
- Add small provider or helper seams only where needed for testability and existing Riverpod patterns.
- Keep UI layout unchanged in this phase unless required by correctness.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Product and Architecture
- `.planning/PROJECT.md` — Product value, constraints, and phase source-of-truth docs.
- `.planning/REQUIREMENTS.md` — Requirement statuses and feature boundaries.
- `.planning/ROADMAP.md` — Phase 2 scope and success criteria.
- `.planning/codebase/ARCHITECTURE.md` — Feature-first architecture, routes, controller, repository, and startup paths.
- `.planning/codebase/TESTING.md` — Flutter test patterns and verification commands.

### Prior Phase
- `.planning/phases/01-core-api-and-fixes/01-01-SUMMARY.md` — Phase 1 implementation context and changed Places/env files.
- `.planning/phases/01-core-api-and-fixes/01-VERIFICATION.md` — Phase 1 verification evidence.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `PlacesRepository.getPlaceById` already reads cached place documents by ID and can back a direct favorites list loader.
- `SwipeController.favoritesList`, `isFavorite`, and `removeFavorite` already provide the reactive state surface needed by favorites and detail UI.
- `createRouter` already centralizes active-session redirects, so route allowance can be isolated as a pure helper.
- `Env.init` already wraps `flutter_dotenv`; startup only needs to call it.

### Established Patterns
- Repositories expose Firestore operations and are constructor-injectable for tests.
- Riverpod providers in `main_providers.dart` expose app-wide data dependencies.
- Tests use `fake_cloud_firestore`, `mocktail`, and `flutter_dotenv.loadFromString` rather than live services.

### Integration Points
- `lib/features/home/ui/favorites_screen.dart`
- `lib/features/places/ui/place_detail_screen.dart`
- `lib/features/swipe/logic/swipe_controller.dart`
- `lib/features/swipe/data/places_repository.dart`
- `lib/app/routes.dart`
- `lib/main.dart`

</code_context>

<specifics>
## Specific Ideas

No UI redesign in this phase. Fix the smallest correctness path and leave copy/settings/profile/theme polish to Phases 3 and 4.

</specifics>

<deferred>
## Deferred Ideas

- English copy and settings accuracy remain Phase 3.
- Profile image and visual polish remain Phase 4.
- Draggable ranking and Borda consensus remain Phase 5.

</deferred>

---

*Phase: 2-MVP Correctness Stabilization*
*Context gathered: 2026-07-05T12:17:53Z*
