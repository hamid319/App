'use strict';

// Tunables for the Places ingestion pipeline. Kept in one place so cost
// behaviour can be adjusted without touching the function logic.
module.exports = {
  REGION: 'europe-west1',

  // Google caps Nearby Search (New) at 20 results per request.
  MAX_PLACES_PER_CITY: 20,

  // Search radius around the city centre, in metres (API maximum is 50000).
  SEARCH_RADIUS_METRES: 15000,

  // Downscaled width for cached photos. Smaller means cheaper egress and
  // faster card rendering; 1200px still looks sharp on a full-bleed card.
  PHOTO_MAX_WIDTH_PX: 1200,

  // How many photos to download concurrently.
  PHOTO_CONCURRENCY: 5,

  // Google's Places policy does not allow caching place content indefinitely,
  // so cached cities expire and are refreshed.
  CACHE_TTL_DAYS: 30,

  // Per-user throttle on cache-miss ingestion, which is the only path that
  // spends money.
  RATE_LIMIT_MAX_FETCHES: 5,
  RATE_LIMIT_WINDOW_MINUTES: 60,

  // Nearby Search (New) accepts only "Table A" place types in
  // includedTypes/excludedTypes. Table B values such as 'landmark' or 'food'
  // make the whole request fail with INVALID_ARGUMENT.
  INCLUDED_TYPES: [
    'tourist_attraction',
    'museum',
    'church',
    'art_gallery',
    'historical_landmark',
    'cultural_landmark',
    'monument',
    'national_park',
    'sculpture',
  ],
  EXCLUDED_TYPES: ['restaurant', 'cafe', 'bar'],

  // Cheapest current Gemini tier that is good enough for a one-line summary.
  GEMINI_MODEL: 'gemini-2.5-flash-lite',

  SCHEMA_VERSION: 2,
};
