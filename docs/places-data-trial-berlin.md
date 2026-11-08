# Place data trial: Berlin (2026-11-08)

Nothing was published. Raw files are local only (scratchpad), not in the repo.

## Sources and terms (read 2026-11-08)

| Source | License | Store in our DB? | Obligations |
|---|---|---|---|
| OpenStreetMap (already used) | ODbL 1.0 | yes | Credit "© OpenStreetMap contributors". Share-alike: a database built from OSM and used publicly must be offered under ODbL on request. |
| Overture Maps Places, release 2026-10-21.0 | per source: Meta, Microsoft, BrightQuery, Uberall, PinMeTo … CDLA Permissive 2.0; Foursquare Apache 2.0; AllThePlaces CC0 | yes | CDLA: ship the license text when sharing the *data*; nothing for results shown in the app. Apache: keep Foursquare's NOTICE / copyright line. Public S3, no account, no gate. |
| Foursquare OS Places (direct, Hugging Face) | Apache 2.0, release dt=2026-10-15 | yes | **Gated:** accepting means sharing your HF info and letting Foursquare use your company name and logo in its marketing. Owner's decision; not used here. Overture already contains part of Foursquare. |
| Google Places | — | **no** (terms forbid storing) | left out |

Not legal advice. Suggested in-app credit: "Places: © OpenStreetMap contributors, Overture Maps Foundation (incl. Meta, Microsoft, Foursquare)".

## Numbers (Berlin box 13.088–13.761 E, 52.338–52.675 N; slightly larger than the city)

**What we have today:** 46 sights (only with Wikidata/Wikipedia) and 40 venues, chosen from 4,544 eligible OSM venues. The cap of 40 (`VENUES.maxPerCity`) is the main gap, not OSM coverage.

| | OSM (named, Berlin area) | Overture (open, confidence ≥ 0.8, no chain) |
|---|---|---|
| Restaurants | 4,725 | ~7,300 |
| Cafés | 2,584 | ~1,800 |
| Fast food / snack | 2,807 | ~3,400 |
| Bars, pubs, beer gardens | 1,959 | ~1,900 |
| Museums / galleries | 242 + galleries | ~530 museums, 1,230 galleries |

- Overture categories are fine-grained and consistent: `italian_restaurant`, `vietnamese_restaurant`, `cocktail_bar`, `wine_bar`, `breakfast_and_brunch_restaurant` … with a hierarchy (food_and_drink › restaurant › european › italian).
- Freshness: 87 % of food entries were confirmed by a source in October 2026.
- Overlap with OSM (same spot ≤ 80 m, similar name): about 35 %. Checking 40 "Overture-only" samples by hand:
  - ~20 % are the same place under a longer name (our matcher missed "Hako Ramen Prenzlauer Berg" = "Hako Ramen"). Easy to fix.
  - ~45 % sit within 30 m of a *different* OSM venue: often the old tenant (Overture stale) or OSM missing a neighbour. Can't tell from data alone.
  - The rest look like real places OSM lacks.
- Noise: ~130 entries with "GmbH/UG/e.K." in the name, wrong categories ("Amcor Tobacco Packaging GmbH" as a bar, an unbranded KFC). Sources Microsoft and Uberall match OSM only 4–10 %; Meta (alone or with BrightQuery) is the most reliable.
- **Missing in both:** popularity or ratings, and photos. Overture's `confidence` only says the place exists.

## Recommendation

1. **Quick win, no new source:** raise the OSM venue cap (e.g. 300–500 per city, by category) and also accept OSM sights without Wikidata (museums, viewpoints, artworks, attractions; skip the ~9,000 `historic` small memorials). The app already loads with `limit` and orders by `popularity`, so more documents don't cost more reads per user.
2. **Overture as a second source:** keep only `confidence ≥ 0.9`, no brand, no legal-form names, and Meta among the sources (or ≥ 2 sources). Merge with OSM by distance plus improved name matching; if OSM has a different named venue at the same spot, trust OSM. Use Overture's fine category (and website/socials) on matched OSM places too.
3. **Ranking (the real gap):** score from data richness (website, socials, opening hours, OSM tags, number of sources) plus a "Tipp" flag for Wikivoyage Eat/Drink/See listings, then over time our own likes, super-likes, group matches and reviews.
4. **Photos:** category images until user photos exist.
5. **Fresh:** rerun monthly (Overture releases monthly, OSM is live).

Open: Firestore storage grows (thousands of docs per city, cheap), and category filters in the app would need new indexes.
