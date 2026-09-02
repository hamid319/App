# SwipeTrip Cloud Functions

Server-side Google Places ingestion. The point of this package is that **no
Google API key ever ships inside the app binary** — the keys live in Secret
Manager and only these functions can read them.

## Functions

| Name | Trigger | Purpose |
|---|---|---|
| `getCityPlaces` | callable (`onCall`) | Returns place ids for a city. Serves the shared Firestore cache when warm; on a miss it calls Nearby Search once, caches each photo into Cloud Storage, optionally generates one-line descriptions, and writes `/places` + `/placeCacheMetadata`. |
| `refreshExpiredCityCaches` | scheduled, daily | Re-fetches cities whose cached content has passed the 30-day TTL, max 10 cities per run. |

## Cost behaviour

- **Cache first.** A city costs money only the first time anyone picks it, and
  again once every 30 days.
- **Photos are fetched once per place, not once per viewer.** This is the
  single biggest saving: the app previously requested every card image from
  Google on every view.
- **Per-user throttle.** A cache miss is rate limited to 5 new cities per user
  per hour (`functions/config.js`), so no single account can run up a bill.
- **Bounded refresh.** The scheduled job processes at most 10 cities per day.

## Setup

Requires the Firebase **Blaze** plan (Cloud Functions are not available on
Spark). Free tiers still apply, and at a few hundred users this stays at or
near zero.

```bash
# 1. Install dependencies
cd functions && npm install && cd ..

# 2. Store the Places key. Until you have a real one, set a placeholder:
#    the function will refuse to call Google and return a clear error.
echo "placeholder" | firebase functions:secrets:set PLACES_API_KEY --data-file=-

# 3. Optional: AI descriptions. Without this secret, places are cached
#    without descriptions and nothing else changes.
echo "placeholder" | firebase functions:secrets:set GEMINI_API_KEY --data-file=-

# 4. Deploy
firebase deploy --only functions,firestore:rules,firestore:indexes,storage
```

When you get a real Places key, replace the secret and redeploy:

```bash
firebase functions:secrets:set PLACES_API_KEY   # paste the real key
firebase deploy --only functions
```

Restrict that key in the Google Cloud console to the **Places API (New)** only.
It is used server-side, so it needs no Android/iOS application restriction.
Also set per-API daily quotas there as a hard cost ceiling.

## Region

Deployed to `europe-west1`. This must stay in sync with
`AppConfig.functionsRegion` in the Flutter app.

## Notes

- `enforceAppCheck` is currently `false` in `index.js`. Turn it on once
  `firebase_app_check` is wired up in the app, so only your real app can call
  the function.
- `includedTypes` / `excludedTypes` accept only Google's "Table A" place types.
  Table B values such as `landmark` or `food` make the whole request fail with
  `INVALID_ARGUMENT`.
- Photo author attributions are stored on each place document
  (`photoAttributions`). Google's terms require displaying them wherever the
  photo is shown; the app does not render them yet.
