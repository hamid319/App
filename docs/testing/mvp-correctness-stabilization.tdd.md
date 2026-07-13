# MVP Correctness Stabilization TDD Evidence

## Source Plan

Derived from `.planning/phases/02-mvp-correctness-stabilization/02-01-PLAN.md`.

## User Journeys

- As a user, I want my favorites list to show the exact places I saved, so that it is not affected by my current location or a zero-coordinate lookup.
- As a user, I want adding a favorite from place detail to save that displayed place, so that my swipe deck does not unexpectedly advance.
- As a user in an active group session, I want to intentionally open profile, settings, favorites, or group pages, so that the active-session redirect does not trap me in the swipe screen.
- As the app runtime, I want dotenv initialized before config-backed services start, so that Places and Gemini keys are available when repositories read `Env`.

## Task Report

| Task | RED Evidence | GREEN Evidence | Guarantee |
|---|---|---|---|
| Direct favorite ID loading | `flutter test test/mvp_correctness_stabilization_test.dart` failed to compile because `loadPlacesByIds` was missing. | Same command passed with 3 tests. | Favorite IDs resolve exact Firestore place documents in requested order and skip missing IDs. |
| Active-session route allowlist | Same RED run failed to compile because `isActiveSessionRouteAllowed` was missing. | Same command passed with 3 tests. | Active sessions allow `/profile`, `/settings`, `/favorites`, `/group`, `/group/*`, `/swipe/*`, and `/group-matches/*`, but still redirect `/home`. |
| Env startup order | Same RED run failed to compile because `bootstrapApp` was missing. | Same command passed with 3 tests. | `Env.init` runs before Firebase initialization and app rendering. |

## Test Specification

| # | What is guaranteed | Test file or command | Test type | Result | Evidence |
|---|---|---|---|---|---|
| 1 | Favorites load cached places by favorite IDs in order, including places outside any nearby radius. | `test/mvp_correctness_stabilization_test.dart` | unit/repository | PASS | `$HOME/flutter/bin/flutter test test/mvp_correctness_stabilization_test.dart` |
| 2 | Active-session routing allows explicit navigation to normal app sections. | `test/mvp_correctness_stabilization_test.dart` | unit/pure function | PASS | `$HOME/flutter/bin/flutter test test/mvp_correctness_stabilization_test.dart` |
| 3 | Bootstrap initializes env before Firebase and app rendering. | `test/mvp_correctness_stabilization_test.dart` | unit/startup seam | PASS | `$HOME/flutter/bin/flutter test test/mvp_correctness_stabilization_test.dart` |
| 4 | Existing Places API migration behavior remains intact. | `test/places_api_migration_test.dart` | unit/repository | PASS | `$HOME/flutter/bin/flutter test test/places_api_migration_test.dart` |
| 5 | Flutter analyzer is clean after the implementation. | `$HOME/flutter/bin/flutter analyze` | static analysis | PASS | No issues found |

## Coverage and Known Gaps

No coverage report was generated in this run. The targeted tests cover the changed correctness seams, while full authenticated widget navigation remains a future integration-test candidate if the project adds Firebase/Riverpod test harnesses for logged-in flows.

## Merge Evidence

No checkpoint commits were created because the repository already had a broad dirty worktree. RED and GREEN command evidence is preserved in this file and the Phase 2 verification artifact.
