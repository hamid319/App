# Roadmap: SwipeTrip

## Overview

SwipeTrip's current milestone has completed the real place discovery foundation. The immediate active work is an MVP polish sweep that stabilizes user-visible flows before returning to group consensus voting.

## Phases

- [x] **Phase 1: Core API and Fixes** - Real Google Places API data, Gemini summaries, and Firestore city caching.
- [x] **Phase 2: MVP Correctness Stabilization** - Favorites/detail correctness, active-session routing, and environment startup.
- [ ] **Phase 3: English Copy and Settings Accuracy** - English-only user-facing copy and truthful settings/security claims.
- [ ] **Phase 4: Profile, Image, and Visual Polish** - Profile actions, cached image states, and Material 3 theme consistency.
- [ ] **Phase 5: Group Consensus Voting** - Ranking and consensus algorithm work for group sessions.

## Phase Details

### Phase 1: Core API and Fixes
**Goal**: Implement real place discovery through Google Places API New Essentials, Gemini one-sentence descriptions, and Firestore city caching.
**Depends on**: Existing auth, group/session, Firestore, and swipe foundations.
**Requirements**: REQ-06
**Success Criteria** (what must be TRUE):
  1. Places are loaded from Firestore cache first for the requested city.
  2. Cache misses call Google Places API New Nearby Search with Essentials fields only.
  3. New places receive a Gemini-generated one-sentence travel summary.
  4. New places are written to Firestore `/places/{placeId}` using real Google Place IDs.
  5. `flutter test test/places_api_migration_test.dart` passes.
**Plans**: 1 plan

Plans:
- [x] 01-01: Google Places API and Gemini AI Hybrid Caching (`.planning/phases/01-core-api-and-fixes/01-01-PLAN.md`)

### Phase 2: MVP Correctness Stabilization
**Goal**: Stabilize user-visible MVP correctness before visual polish and group consensus work.
**Depends on**: Phase 1 real Places API and the existing swipe, favorites, detail, group, and routing foundations.
**Requirements**: REQ-04, REQ-05, REQ-06, REQ-07
**Success Criteria** (what must be TRUE):
  1. Favorites load the user's favorite place IDs directly instead of using a zero-coordinate nearby search.
  2. Place detail add/remove favorites targets the displayed place and does not advance the swipe deck.
  3. Active-session routing allows intentional navigation to profile, settings, favorites, and group pages.
  4. Startup initializes dotenv before Places or Gemini configuration is read.
  5. Focused tests cover favorites/detail behavior, router redirect rules, and env startup where feasible.
**Plans**: 1 plan

Plans:
- [x] 02-01: MVP Correctness Stabilization (`.planning/phases/02-mvp-correctness-stabilization/02-01-PLAN.md`)

### Phase 3: English Copy and Settings Accuracy
**Goal**: Ensure user-facing copy is English and settings/security text accurately reflects current app capabilities.
**Depends on**: Phase 2 correctness stabilization.
**Requirements**: REQ-02, REQ-09
**Success Criteria** (what must be TRUE):
  1. Remaining German user-facing strings in touched surfaces are translated to English.
  2. Settings/security claims describe current implemented behavior without overstating protections.
  3. Logic remains unchanged unless a string depends on a false claim.
  4. Lightweight tests or static checks cover obvious German copy in touched settings/auth surfaces.
**Plans**: 0 plans

### Phase 4: Profile, Image, and Visual Polish
**Goal**: Polish profile actions, image states, and Material 3 theme consistency without a broad redesign.
**Depends on**: Phase 3 English copy and settings accuracy.
**Requirements**: REQ-03, REQ-04, REQ-05, REQ-09
**Success Criteria** (what must be TRUE):
  1. Profile display-name and profile-image actions are improved where existing controller support is sufficient.
  2. Place cards, favorites, details, and profile image surfaces have consistent loading and error states.
  3. The Material 3 theme is completed consistently across core MVP surfaces.
  4. `flutter analyze`, targeted widget tests, and screenshots where substantial UI changes occur are verified.
**Plans**: 0 plans

### Phase 5: Group Consensus Voting
**Goal**: Implement draggable ranking and Borda consensus for group sessions after MVP polish.
**Depends on**: Phase 4 profile, image, and visual polish.
**Requirements**: REQ-08
**Success Criteria** (what must be TRUE):
  1. Group members can rank candidate places with a draggable list.
  2. Consensus scoring uses a deterministic Borda count or equivalent documented ranking algorithm.
  3. Firestore transaction logic in `group_repository.dart` remains protected unless explicitly planned.
  4. Group-session behavior has focused tests before implementation changes.
**Plans**: 0 plans

## Future Phase Summary

These phases remain roadmap intent, but they do not currently have executable plan files.

| # | Phase | Goal | Requirements | Status |
|---|---|---|---|---|
| 2 | MVP Correctness Stabilization | Favorites list/detail correctness, active-session router escape hatches, and dotenv startup | REQ-04, REQ-05, REQ-06, REQ-07 | complete |
| 3 | English Copy and Settings Accuracy | Translate remaining German strings and remove misleading settings/security claims | REQ-02, REQ-09 | pending |
| 4 | Profile, Image, and Visual Polish | Profile/image polish, cached image states, and Material 3 theme consistency | REQ-03, REQ-04, REQ-05, REQ-09 | pending |
| 5 | Group Consensus Voting | Group Consensus Voting & Draggable List | REQ-08 | pending |

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Core API and Fixes | 1/1 | Complete | 2026-07-05 |
| 2. MVP Correctness Stabilization | 1/1 | Complete | 2026-07-05 |
| 3. English Copy and Settings Accuracy | 0/0 | Not planned | - |
| 4. Profile, Image, and Visual Polish | 0/0 | Not planned | - |
| 5. Group Consensus Voting | 0/0 | Not planned | - |
