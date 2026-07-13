# SwipeTrip Core Idea

## Product Summary

SwipeTrip is a mobile travel-discovery app for deciding where to go and what to see. It replaces long lists, scattered reviews, and group indecision with a simple swipe flow: users see place cards, swipe right to like, swipe left to pass, and build a practical shortlist of places they actually want to visit.

The core product promise is:

> Discover travel spots by swiping, alone or with friends, until you find places worth visiting.

The app is currently also referred to in older project files as Traveller App. The product-facing brand direction is SwipeTrip.

## Problem We Are Solving

Trip planning often breaks down at the decision stage. One person wants museums, another wants viewpoints, another wants food or local experiences, and the group gets stuck comparing lists instead of making a decision.

SwipeTrip turns that problem into a fast mobile workflow:

- Show users concrete places instead of abstract suggestions.
- Let each person react quickly with like or pass.
- Preserve personal favorites for solo discovery.
- Calculate group matches from the places multiple members liked.
- Keep the decision focused on places, not bookings, flights, hotels, or full itinerary planning.

## Target Users

SwipeTrip is built for mobile-first travelers who need lightweight decision support:

- Friends planning weekends, city breaks, or group trips.
- Couples choosing what to visit together.
- Solo travelers discovering nearby places and saving favorites.
- Young adults comfortable with swipe-based interactions.
- International users, with English UI copy as the current project rule.

The app should feel playful, fast, and social, but still practical enough to guide real travel decisions.

## Solo Mode

Solo mode is the personal discovery flow.

1. The user opens the app after onboarding and authentication.
2. The app shows a swipe deck of places.
3. The user swipes right to like a place or left to skip it.
4. Liked places are stored as personal favorites.
5. The user can open a place detail screen, view photos and metadata, and launch maps.
6. Favorites remain available from the profile and favorites screens.

Solo mode is important because it gives users value even before they join a group. It also creates the personal preference data that can later sync into group decisions.

## Group Mode

Group mode is the main differentiator.

1. A user creates a group and becomes the group owner/admin.
2. The group has an invite code, destination location, member list, and session state.
3. Members join by invite code while joining is enabled.
4. The admin starts a swipe session for the selected city.
5. The app builds a shared place pool for the session.
6. Each member swipes on the same set of places.
7. Each vote is stored under the group session.
8. When all participants finish, or the admin ends early, the session becomes completed.
9. The matches screen shows places that reached the group threshold, sorted by likes.

The central idea is that everyone gets the same candidate list, but each person decides independently. The app then turns those independent choices into a shared result.

## Core User Flows

### First Run

Onboarding introduces the app, then authentication gates the main experience. The router should send first-time users through onboarding, unauthenticated users to login, and authenticated users to the home experience.

### Place Discovery

The discovery flow depends on `PlaceModel` records from Firestore. The intended real-data path is city-scoped caching backed by Google Places API New Nearby Search. Cached places should be reused across users and sessions to reduce cost and latency.

### Favorites

Favorites are user-level place IDs. They must stay consistent across swipe screens, place detail screens, profile, and favorites views. Adding a favorite from a detail page must not advance the swipe deck.

### Group Session

Group sessions are stored under `/groups/{groupId}/sessions/{sessionId}`. A session freezes participants and the place pool at start time. Each swipe writes vote data and per-user progress. Session completion clears `activeSessionId` on the group and allows results/history views.

### Group Matches

Group matches are the product outcome. They answer: "Which places did enough of us like?" The current MVP ranks qualified places by like count.

## What We Are Not Building

SwipeTrip is not trying to be:

- A flight or hotel booking app.
- A full itinerary planner.
- A review platform.
- A map-first exploration tool.
- A restaurant-only app.
- A dating app, even though it borrows swipe interaction patterns.

The app should stay focused on fast place discovery and group decision-making.

## MVP Success Criteria

The MVP is successful when a real user can:

- Register, log in, and return to the app later.
- Complete onboarding once.
- Discover places through swipe cards.
- Save and remove favorites reliably.
- Open place details and maps.
- Create a group with a destination.
- Join a group by invite code.
- Start a group swipe session.
- Swipe as multiple group members without progress leaking between groups or sessions.
- See group matches after the session completes.

For a demo or student project, it is acceptable to keep advanced features out of scope, including push notifications, full production backend proxying for Places API, paid analytics, and sophisticated itinerary generation.

## Product Principles

- Keep decisions lightweight: users should not need to read long descriptions before reacting.
- Make group state obvious: idle, live, and completed sessions must be visually distinct.
- Prefer real place IDs consistently: do not mix mock IDs with Google Places IDs in the same session flow.
- Cache aggressively by city: repeated sessions for the same city should not repeatedly call external APIs.
- Keep UI copy English-only unless a full localization system is introduced.
- Keep architecture feature-first: UI, logic, and data should remain separated.

