# SwipeTrip

## What This Is

SwipeTrip is a mobile travel discovery app for deciding where to go and what to see. It gives solo travelers and groups a swipe-based place discovery flow: users like or pass on place cards, save personal favorites, and use group sessions to find places enough members agree on.

The app is also called Traveller App in older files, but SwipeTrip is the product-facing source of truth. Current implementation work is focused on polishing MVP user flows after real Google Places API data, Firestore city caching, and Gemini-generated one-sentence place descriptions were implemented.

## Core Value

Users can discover real travel spots by swiping, alone or with friends, until they have places worth visiting.

## Requirements

### Validated

- Authenticated users can sign up, log in, log out, and return to the app later.
- First-time users can complete onboarding.
- Users can swipe through place cards and save favorites.
- Users can create groups, choose a destination, and join by invite code.

### Active

- [ ] **REQ-09: Profile & Settings** - Settings translation and profile polish remain active for the MVP polish sweep.

### Deferred

- **REQ-08: Group Voting & Consensus** - Ranking and consensus algorithm work is planned for a later phase.

### Out of Scope

- Flight, hotel, or booking workflows - the app stays focused on place discovery and group decision support.
- Full itinerary planning - the MVP outcome is a practical shortlist, not a complete trip schedule.
- Review-platform behavior - SwipeTrip uses concise place metadata and summaries rather than long-form reviews.
- Mixing mock place IDs with real Google Places IDs - current and future real-data flows must keep ID sources consistent.

## Context

Primary source-of-truth documents:

- `PROJECT_CORE_IDEA_CANONICAL.md`
- `PROJECT_ARCHITECTURE_CANONICAL.md`
- `2026-07-03-hybrid-ai-caching-design.md`
- `.planning/phases/01-core-api-and-fixes/01-01-PLAN.md`

Phase 1 completed Google Places API and Gemini AI Hybrid Caching. Phase 2 completed favorites/detail correctness, active-session routing allowances, and dotenv startup initialization. Phase 3 should focus on English copy and settings accuracy before profile/image polish and group consensus voting.

The intended place data flow is cache-first:

1. Query Firestore `/places` by city.
2. On cache miss, call Google Places API New Nearby Search with Essentials fields.
3. Generate one short travel summary with Gemini.
4. Build Google photo media URLs.
5. Store the merged place document in Firestore using the Google Place ID as the document ID.

## Constraints

- **Stack**: Flutter, Dart, Riverpod, GoRouter, Firebase Auth, Firestore, Google Places API New, Gemini API.
- **Architecture**: Feature-first clean architecture: UI -> logic/controller -> data/repository.
- **Secrets**: API keys must use `flutter_dotenv` and environment loading; do not hardcode new secrets.
- **IDs**: Real Google Places API IDs must not be mixed with mock place IDs in the same real-data flow.
- **Language**: User-facing strings must be English.
- **Verification**: Phase 1 plan verification is `flutter test test/places_api_migration_test.dart`.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Use Google Places API New Essentials fields | Avoids Enterprise-tier cost while still supplying real place IDs, names, locations, types, addresses, and photos. | Complete |
| Generate descriptions with Gemini 1.5 Flash on cache miss | Replaces expensive editorial summaries with low-cost, app-branded one-sentence descriptions. | Complete |
| Cache by city in Firestore | Prevents repeat external API calls for later sessions in the same city. | Complete |
| Resolve favorites by exact place IDs | Favorites must not depend on a nearby search centered at zero coordinates. | Complete |
| Keep active-session escape hatches | Users may intentionally open profile, settings, favorites, and group pages during an active session. | Complete |

## Evolution

This document evolves at phase transitions and milestone boundaries.

After each phase transition:

1. Requirements invalidated? Move to Out of Scope with reason.
2. Requirements validated? Move to Validated with phase reference.
3. New requirements emerged? Add to Active.
4. Decisions to log? Add to Key Decisions.
5. "What This Is" still accurate? Update if drifted.

After each milestone:

1. Full review of all sections.
2. Core Value check.
3. Audit Out of Scope.
4. Update Context with current state.

---
*Last updated: 2026-07-05 after GSD planning metadata normalization*
