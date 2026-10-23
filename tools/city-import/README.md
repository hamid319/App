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

5. collects up to 40 **evening/food venues** per city from OpenStreetMap
   (see [Venues](#venues)).

Sources, all free and storable long-term:

| What | Source | Licence / notice in the app |
|---|---|---|
| Which places, order, categories, fallback text | `catalog.json` (team) | – |
| Coordinates, address, opening hours, website | OpenStreetMap | ODbL, "© OpenStreetMap contributors" on the detail page |
| Venues (restaurants, cafés, bars ...), cuisine | OpenStreetMap | ODbL, same notice |
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

OpenStreetMap is read through the public Overpass API (two requests per
city: sights and venues). For many cities or frequent refreshes, switch to regional extracts
(e.g. Geofabrik) to stay within the API's fair-use limits.

## Venues

For the app's "Heute Abend" slider, `collect` also picks evening and food
venues, without a hand-made catalog (`src/venues.ts`):

1. one extra Overpass request per city: named `amenity=restaurant|cafe|bar|pub|biergarten|nightclub`
   within 5 km of the centre (`VENUES.radiusKm`; `venueRadiusKm` in
   `cities.json` overrides), without `brand`, `brand:wikidata` or
   `operator:wikidata` tags (chains). Fast food is not asked for. A name
   found 3+ times in the area also counts as a chain; of two elements
   with the same name the better one is kept.
2. notability score, each criterion outweighing all later ones together:
   Wikidata item > Commons photo (tag) > opening hours > website >
   cuisine or description > closeness to the centre.
3. best first, at most 40 per city (`VENUES.maxPerCity`) and per type
   ≤ 15 restaurants, ≤ 10 cafés, ≤ 12 bars + pubs, ≤ 5 beer gardens,
   ≤ 5 night clubs (`VENUE_CAPS` in `src/config.ts`).
4. photos like sights (Wikidata image, OSM `image`/`wikimedia_commons`,
   Commons depicts/category, same licence rules), but a venue **without a
   usable photo is kept**; the app draws a placeholder. Texts only for
   venues with a Wikidata item (Wikipedia lead, else the Wikidata
   description), otherwise none.

Ids in `exclusions.json` are skipped at collect time (the next-best venue
takes the slot) and never published. A venue that is also a catalog sight
is published once, as the sight. `report` and `review` show venues in
their own section; `publish -- --dry-run` prints the counts per type.

## Data model

`cities/{cityId}`: `nameEn`, `nameDe`, `countryCode`, `lat`, `lng`,
`placeCount`, `updatedAt`.

`places/{id}`: `cityId`, `status` (`active`/`hidden`), `kind`
(`sight`/`venue`; the app reads a missing kind as `sight`), `name` and
`description` (English), `names`/`descriptions`/`wikipediaUrls` per
language, `lat`, `lng`, `address`, `openingHours`, `website`, `osmUrl`,
`types` (app place types), `interests` (app interests), `popularity`
(higher = earlier in the catalog), `imageUrls`, `photos` (with author and
licence), `importRunId`, `updatedAt`.

Venues have the same fields plus: exactly one type (`restaurant`, `cafe`,
`bar`, `pub`, `biergarten`, `night_club`), `interests` `["food"]`
(restaurant, café, beer garden) or `["nightlife"]` (bar, pub, night club),
optional `cuisine` (first value of the OSM tag, e.g. `portuguese`),
`popularity` 0..499 from the score (sights: 1000 − rank, so ≥ 950),
`names` from OSM `name` (or `name:en`/`name:de`), possibly empty
`descriptions` and `photos`. `cities/{id}.placeCount` counts sights only.

The app loads one city with `cityId == X && status == active`, ordered by
`popularity`, and the venues with `cityId == X && kind == venue && status
== active` ordered by `popularity` desc. Both indexes are in
`firestore.indexes.json`; deploy them before the app uses the venue
query (`firebase deploy --only firestore:indexes`).

## Tuning

`src/config.ts`: catalog categories → app place types, extra types from
OSM tags, default radius (25 km; `cities.json` overrides per city), photo
size limits, venue limits, caps and score weights. `src/osm.ts`: which OSM objects are downloaded.
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
