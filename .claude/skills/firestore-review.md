---
description: Review Firestore security rules against model field names for SwipeTrip
---

Read these two files:
- `firestore.rules`
- `lib/common/models/group_session_model.dart`

Then check:

| Rule section | Field checked | Status | Issue |
|---|---|---|---|

Checks:
1. Session `update` rule — must allow `swipeProgress` field (known bug: old rule used `isCompleted`)
2. Session `update` rule — must allow `progressByUser` map updates by participants
3. Votes subcollection write rule — must allow `likedBy[]` and `dislikedBy[]` array mutations
4. Field names in `allow update: if ... resource.data.keys().hasOnly([...])` must exactly match keys from `GroupSessionModel.toJson()`
5. `users/{uid}` write rule — must only allow the document owner (`request.auth.uid == uid`)
6. No rule grants `delete` on group documents to non-owners
7. Groups `update` rule covers the `activeSessionId` field write from `startSwipeSession`

Verdict: **PASS** or **FAIL** with specific line numbers from `firestore.rules`.
