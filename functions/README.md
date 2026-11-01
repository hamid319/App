# TripFam Cloud Functions

Push notifications for trip events (Firebase Cloud Messaging). The texts,
the match rule and the token clean-up live in `push.js`; `index.js` wires
them to Firestore triggers.

## Functions

| Name | Trigger | Who gets a push |
|---|---|---|
| `pushOnSwipeMatch` | `groups/{g}/swipes/{uid}` written | the other members, when a swipe makes a place a group match |
| `pushOnMemberJoined` | `groups/{g}` updated | the members who were already in the trip |
| `pushOnExpenseAdded` | `groups/{g}/expenses/{id}` created | the other members |
| `pushOnJournalEntry` | `groups/{g}/journal/{id}` created | the other members |

The sender is never notified. Devices register in `pushTokens/{token}`
(`uid`, `lang`); tokens FCM reports as dead are deleted.

Triggers run in `europe-west3`, the Firestore database's region (Firestore
triggers must match it).

## Cost

Swipes that add no like return before any Firestore read. Every other event
reads the trip, the sender's name and the recipients' tokens. FCM itself is
free.

## Commands

```bash
npm install
npm test                                   # push.js logic, no Firebase needed
firebase deploy --only functions           # the owner deploys
```

Place data does not come from here: it is imported with `tools/city-import`
(OpenStreetMap, Wikidata, Wikimedia Commons).
