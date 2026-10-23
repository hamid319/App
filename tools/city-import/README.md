# City import

Fills SwipeTrip with curated places. The team decides which cities and
which attractions exist, reviews what was found, then publishes. App users
never trigger data collection.

```
catalog.json (curated: 25 cities × 50 attractions)
cities.json  (which cities to import, centre, radius)
      │
      └─collect─▶ out/<cityId>.json ──report──▶ out/report.html (review)
                          │
                          └──publish──▶ R2 (photos) + Firestore (cities, places)
```

For each catalog entry, `collect`:

1. finds the name on **OpenStreetMap** (one Overpass download per city,
   matched locally by name, English/local names and alternative names);
2. otherwise searches **Wikidata** for it near the city;
3. takes **photos** from Wikimedia Commons: the main image, files tagged as
   showing the place, and the place's Commons category;
4. takes **names and texts** in English and German from Wikidata and the
   Wikipedia lead paragraph; without a Wikipedia article the catalog's own
   description is used.

Sources, all free and storable long-term:

| What | Source | Licence / notice in the app |
|---|---|---|
| Which places, order, categories, fallback text | `catalog.json` (team) | – |
| Coordinates, address, opening hours, website | OpenStreetMap | ODbL, "© OpenStreetMap contributors" on the detail page |
| Names (EN/DE), Wikidata link | Wikidata | CC0 |
| Descriptions (EN/DE) | Wikipedia lead paragraph | CC BY-SA, "Text: Wikipedia" link |
| Photos (up to 3 per place) | Wikimedia Commons | author + licence per photo |

Not mixed in: Google data (its terms forbid storing it next to ODbL data).

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
npm run review                       # pick photos in the browser (http://127.0.0.1:4173)
npm run publish -- --dry-run         # what would be published
npm run publish                      # photos to R2, data to Firestore
```

Photos: `collect` keeps up to 10 Commons candidates per place, because their
quality varies. `npm run review` (`--port` to change 4173, `--city` to limit
the cities) opens a local page per city: click the photos in the order you
want them (1 = cover, at most 3); every click is saved at once to
`photo-picks.json` (`placeId -> [Commons page ids]`). "Passt so" keeps the
automatic choice and marks the place as reviewed, "Ausschließen" writes it to
`exclusions.json`. Places without picks publish their first 3 candidates.
Picks are keyed by Commons page id, so they survive a new `collect`; a picked
photo that is no longer a candidate is ignored. `report` and
`publish -- --dry-run` show the selected photos only.

Review: a place that should not be in the app goes into `exclusions.json`
with its id from the report (`"pt_lisbon": ["wd_Q123"]`), then `report`
again. Excluded places are never published, and are hidden if they were
published before. Catalog entries that were not found or had no usable
photo are listed per city in the report; fixing the name in `catalog.json`
(e.g. the local name) usually solves it.

Adding a city: add its attractions to `catalog.json` and the city to
`cities.json` (`id` must match the app's `PopularCity` id in
`lib/core/constants/popular_cities.dart`), then collect, report, publish.

Refreshing: run collect + publish again, e.g. every few months. Reruns are
safe:

- places keep their id (`wd_<QID>`, or `osm_<type>_<id>` without Wikidata)
  and are updated in place;
- photos already in R2 are reused, not uploaded again;
- places that dropped out are set to `status: "hidden"`, never deleted.

Every publish writes a log entry to `importRuns/{runId}` (not readable by
the app).

OpenStreetMap is read through the public Overpass API (one request per
city). For many cities or frequent refreshes, switch to regional extracts
(e.g. Geofabrik) to stay within the API's fair-use limits.

## Data model

`cities/{cityId}`: `nameEn`, `nameDe`, `countryCode`, `lat`, `lng`,
`placeCount`, `updatedAt`.

`places/{id}`: `cityId`, `status` (`active`/`hidden`), `name` and
`description` (English), `names`/`descriptions`/`wikipediaUrls` per
language, `lat`, `lng`, `address`, `openingHours`, `website`, `osmUrl`,
`types` (app place types), `interests` (app interests), `popularity`
(higher = earlier in the catalog), `imageUrls`, `photos` (with author and
licence), `importRunId`, `updatedAt`.

The app loads one city with `cityId == X && status == active`, ordered by
`popularity` (index in `firestore.indexes.json`).

## Tuning

`src/config.ts`: catalog categories → app place types, extra types from
OSM tags, default radius (25 km; `cities.json` overrides per city), photo
size limits. `src/osm.ts`: which OSM objects are downloaded.
`src/match.ts`: how names are compared.

Accepted photo licences: CC0, public domain, CC BY and CC BY-SA of any
version. Rejected: NC/ND, GFDL-only, anything unclear; also maps, logos,
drawings and files under 800 px.

## Tests

```bash
npm run check   # typecheck + unit tests (no network)
```

Parts of this tool (Commons lookup, image conversion, R2 upload) are
adapted from the city pipeline on `feature/city-collection-pipeline`.
