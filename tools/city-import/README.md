# City import

Fills SwipeTrip with curated places. The team decides which cities exist
(`cities.json`), reviews what was found, then publishes. App users never
trigger data collection.

```
cities.json ──collect──▶ out/<cityId>.json ──report──▶ out/report.html (review)
                                   │
                                   └──publish──▶ R2 (photos) + Firestore (cities, places)
```

Sources, all free and storable long-term:

| What | Source | Licence shown in the app |
|---|---|---|
| Places, coordinates, names (EN/DE) | Wikidata | CC0, no notice needed |
| Descriptions (EN/DE) | Wikipedia lead paragraph | CC BY-SA, "Text: Wikipedia" link on the detail page |
| Photos (up to 3 per place) | Wikimedia Commons | author + licence per photo (photo credit chip) |

## Setup

Node 22 or newer.

```bash
cd tools/city-import
npm install
```

`collect` and `report` need nothing else. `publish` additionally needs:

1. **Cloudflare R2**: a bucket (e.g. `swipetrip-places`) with public access
   (custom domain, or `r2.dev` for testing) and an API token with
   *Object Read & Write* for that bucket only. Copy `.env.example` to `.env`
   and fill it in. `.env` is git-ignored.
2. **Firestore access** for project `travelapp-31255`, one of:
   - `gcloud auth application-default login` (recommended, no key file), or
   - a service-account key in `.secrets/service-account.json` (git-ignored)
     and `GOOGLE_APPLICATION_CREDENTIALS=.secrets/service-account.json` in `.env`.
3. The rules and the `places` index from this repo deployed once:
   `firebase deploy --only firestore`.

## Use

```bash
npm run collect                      # all cities in cities.json (~2 min per city)
npm run collect -- --city pt_lisbon  # one or more: --city pt_lisbon,de_berlin
npm run report                       # open out/report.html and review
npm run publish -- --dry-run         # what would be published
npm run publish                      # photos to R2, data to Firestore
```

Review: a place that should not be in the app goes into `exclusions.json`
(`"pt_lisbon": ["Q123"]`), then `report` again. Excluded places are never
published, and are hidden if they were published before.

Adding a city: add it to `cities.json` (`id` must match the app's
`PopularCity` id in `lib/core/constants/popular_cities.dart`, `wikidataId`
from wikidata.org), then collect, report, publish.

Refreshing: run collect + publish again, e.g. every few months. Reruns are
safe:

- places keep their id (`wd_<QID>`) and are updated in place;
- photos already in R2 are reused, not uploaded again;
- places that dropped out are set to `status: "hidden"`, never deleted.

Every publish writes a log entry to `importRuns/{runId}` (not readable by
the app).

## Data model

`cities/{cityId}`: `nameEn`, `nameDe`, `countryCode`, `lat`, `lng`,
`placeCount`, `updatedAt`.

`places/wd_<QID>`: `cityId`, `status` (`active`/`hidden`), `name` and
`description` (English), `names`/`descriptions`/`wikipediaUrls` per
language, `lat`, `lng`, `types` (app place types), `interests` (app
interests), `popularity` (Wikipedia language editions), `imageUrls`,
`photos` (with author and licence), `importRunId`, `updatedAt`.

The app loads one city with `cityId == X && status == active`, ordered by
`popularity` (index in `firestore.indexes.json`).

## Tuning

`src/config.ts`: which Wikidata classes are searched and how they map to
app place types and interests, the default radius (15 km), places per city
(60), minimum Wikipedia editions (3) and photo size limits. `cities.json`
can override `radiusKm`, `targetPlaces` and `minSitelinks` per city.

Accepted photo licences: CC0, public domain, CC BY and CC BY-SA of any
version. Rejected: NC/ND, GFDL-only, anything unclear; also maps, logos,
drawings and files under 800 px.

## Tests

```bash
npm run check   # typecheck + unit tests (no network)
```

Parts of this tool (SPARQL strategy, Commons lookup, image conversion, R2
upload) are adapted from the city pipeline on
`feature/city-collection-pipeline`.
