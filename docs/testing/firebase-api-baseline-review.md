# Firebase/API Baseline Review

Date: 2026-07-13
Scope: Firebase Auth/Firestore/Storage, Places API cache, Gemini integration, group-session transaction flow.

## Baseline verification

| Command | Result |
|---|---|
| `/Users/ozanermis/flutter/bin/flutter analyze` | PASS — no issues (3.1s) |
| `/Users/ozanermis/flutter/bin/flutter test` | PASS — all existing tests passed (25s) |
| `git diff --check` | FAIL — pre-existing CRLF/trailing-whitespace issues across the dirty worktree; no cleanup is included in this Firebase/API scope |

## Environment/tooling prerequisites

| Requirement | Status |
|---|---|
| Flutter SDK | Available at `/Users/ozanermis/flutter/bin/flutter` |
| Node.js/npm | Available: Node 22.22.3, npm 10.9.8 |
| Firebase CLI | Missing (`firebase: command not found`) |
| Java runtime | Missing; required by Firebase emulators |
| iOS simulator | Available but not currently launched/connected |

## Confirmed source-of-truth findings

1. `firestore.rules` covers only `/users` and `/groups`; the app also reads/writes `/places`, `/swipeResults`, and `/groups/{groupId}/sessions/{sessionId}/userSwipes/{uid}`. Those current paths are denied by default.
2. Current session writes use `status`, `swipeProgress`, `progressByUser`, `endedAt`, and `endedByUid`, while the session rule permits only the stale `progressByUser` and `isCompleted` fields for members.
3. Current vote writes use `placeId`, `likes`, `dislikes`, `likedBy`, and `dislikedBy`; the vote rule validates stale `upvotes`, `downvotes`, and `votedUsers` instead.
4. `firebase.json` references `firestore.indexes.json`, but no such file exists.
5. `ImageService` writes `profile_images/profile_<uid>.jpg`; the current Storage rule compares its wildcard to the bare authenticated UID, so this upload path is denied.
6. `PlacesRepository` constructs image URLs containing the Google Places key and writes `PlaceModel.toJson()` into Firestore, persisting the key-bearing URL.
7. `PlacesRepository` uses a hardcoded `gemini-1.5-flash` endpoint. Model selection needs configuration and an opt-in verification step after real keys are added.
8. `AppConfig.maxPlacesLimit` is 50. The official Google Nearby Search (New) documentation states `maxResultCount` must be 1–20 inclusive.
9. Existing tests use Fake Firestore/mocked HTTP, so they do not exercise Firestore/Storage rules or real Firebase deployment configuration.
10. `GroupRepository.recordSwipeInSession` is high-risk transactional code and has no direct regression tests.

## Required Firestore data paths

```text
/users/{uid}
/places/{placeId}
/placeCacheMetadata/{countryCode_cityId}
/swipeResults/{uid_placeId}
/groups/{groupId}
/groups/{groupId}/sessions/{sessionId}
/groups/{groupId}/sessions/{sessionId}/votes/{placeId}
/groups/{groupId}/sessions/{sessionId}/userSwipes/{uid}
```

## Rules-test mapping

| Path | Intended actor | Required proof |
|---|---|---|
| `/users/{uid}` | authenticated owner | owner allowed; cross-user write denied |
| `/places/{placeId}` | authenticated demo client | validated read/write allowed; invalid document denied |
| `/placeCacheMetadata/{cityId}` | authenticated demo client | city-scoped metadata allowed; malformed document denied |
| `/swipeResults/{uid_placeId}` | authenticated owner | own CRUD allowed; cross-user access denied |
| `/groups/{groupId}` | owner/member/invite joiner | safe create, join-self, leave-self, owner-only administrative changes |
| `/sessions/{sessionId}` | owner/participant | owner start/end; participant progress restricted |
| `/votes/{placeId}` | participant | aggregate shape current and voter arrays valid |
| `/userSwipes/{uid}` | matching participant | own write/read allowed; other participant denied |

## Provider contract

Official Nearby Search (New) documentation checked at:

`https://developers.google.com/maps/documentation/places/web-service/nearby-search`

Observed requirement: `maxResultCount` must be between 1 and 20 inclusive.

## Safety gates

- No Firebase deployment has occurred.
- No `.env` file was read or modified.
- No live Google Places or Gemini call has occurred.
- Do not deploy rules/indexes or run a live API preflight without explicit user confirmation immediately beforehand.
