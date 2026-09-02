'use strict';

const crypto = require('crypto');
const admin = require('firebase-admin');
const { logger } = require('firebase-functions');
const C = require('./config');

const NEARBY_SEARCH_URL =
  'https://places.googleapis.com/v1/places:searchNearby';
const GEMINI_URL_BASE =
  'https://generativelanguage.googleapis.com/v1beta/models';

// A secret that was never set comes back as an empty string; the placeholder
// values below are what a developer typically leaves in .env by accident.
const PLACEHOLDER_KEYS = new Set([
  '',
  'your_key_here',
  'YOUR_API_KEY',
  'changeme',
  'placeholder',
]);

function assertUsableKey(key, name) {
  const trimmed = (key || '').trim();
  if (PLACEHOLDER_KEYS.has(trimmed) || trimmed.length < 20) {
    throw new Error(
      `${name} is not configured. Set it with: ` +
        `firebase functions:secrets:set ${name}`
    );
  }
  return trimmed;
}

function cityKeyFor(countryCode, cityId) {
  return `${String(countryCode).toUpperCase()}_${cityId}`;
}

/**
 * Rejects the call when a user has triggered too many paid ingestions in the
 * current window. Cache hits never reach this.
 */
async function enforceRateLimit(db, uid) {
  const ref = db.collection('rateLimits').doc(uid);
  const windowMs = C.RATE_LIMIT_WINDOW_MINUTES * 60 * 1000;
  const now = Date.now();

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.exists ? snap.data() : null;
    const windowStart = data?.windowStartMs ?? 0;
    const withinWindow = now - windowStart < windowMs;
    const count = withinWindow ? data?.fetchCount ?? 0 : 0;

    if (count >= C.RATE_LIMIT_MAX_FETCHES) {
      const retryInMin = Math.ceil((windowStart + windowMs - now) / 60000);
      throw new Error(
        `Too many new cities requested. Try again in ${retryInMin} minute(s).`
      );
    }

    tx.set(
      ref,
      {
        fetchCount: count + 1,
        windowStartMs: withinWindow ? windowStart : now,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  });
}

async function nearbySearch({ apiKey, lat, lng, limit }) {
  const response = await fetch(NEARBY_SEARCH_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': apiKey,
      'X-Goog-FieldMask': [
        'places.id',
        'places.displayName',
        'places.location',
        'places.types',
        'places.rating',
        'places.formattedAddress',
        'places.photos',
      ].join(','),
    },
    body: JSON.stringify({
      includedTypes: C.INCLUDED_TYPES,
      excludedTypes: C.EXCLUDED_TYPES,
      locationRestriction: {
        circle: {
          center: { latitude: lat, longitude: lng },
          radius: C.SEARCH_RADIUS_METRES,
        },
      },
      maxResultCount: limit,
    }),
    signal: AbortSignal.timeout(15000),
  });

  const bodyText = await response.text();
  if (!response.ok) {
    // Deliberately does not echo the body, which can repeat the API key.
    let status = '';
    try {
      status = JSON.parse(bodyText)?.error?.status ?? '';
    } catch (_) {
      // non-JSON error body
    }
    throw new Error(
      `Nearby Search failed (HTTP ${response.status}${
        status ? ` ${status}` : ''
      })`
    );
  }

  let parsed;
  try {
    parsed = JSON.parse(bodyText);
  } catch (_) {
    throw new Error('Nearby Search returned malformed JSON');
  }
  return Array.isArray(parsed.places) ? parsed.places : [];
}

/**
 * Downloads one photo and stores it in Cloud Storage. Returns a token-based
 * download URL, so the app never needs a Google API key to render images.
 */
async function cachePhoto({ apiKey, bucket, placeId, photoName }) {
  const mediaUrl =
    `https://places.googleapis.com/v1/${photoName}/media` +
    `?maxWidthPx=${C.PHOTO_MAX_WIDTH_PX}&skipHttpRedirect=true`;

  const metaResponse = await fetch(mediaUrl, {
    headers: { 'X-Goog-Api-Key': apiKey },
    signal: AbortSignal.timeout(15000),
  });
  if (!metaResponse.ok) {
    throw new Error(`Photo lookup failed (HTTP ${metaResponse.status})`);
  }
  const { photoUri } = await metaResponse.json();
  if (!photoUri) throw new Error('Photo response contained no photoUri');

  const imageResponse = await fetch(photoUri, {
    signal: AbortSignal.timeout(20000),
  });
  if (!imageResponse.ok) {
    throw new Error(`Photo download failed (HTTP ${imageResponse.status})`);
  }
  const buffer = Buffer.from(await imageResponse.arrayBuffer());
  const contentType = imageResponse.headers.get('content-type') || 'image/jpeg';

  const objectPath = `places/${placeId}/0.jpg`;
  const downloadToken = crypto.randomUUID();
  await bucket.file(objectPath).save(buffer, {
    resumable: false,
    contentType,
    metadata: {
      cacheControl: 'public, max-age=2592000',
      metadata: { firebaseStorageDownloadTokens: downloadToken },
    },
  });

  return (
    `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/` +
    `${encodeURIComponent(objectPath)}?alt=media&token=${downloadToken}`
  );
}

async function mapWithConcurrency(items, limit, worker) {
  const results = new Array(items.length);
  let cursor = 0;
  const runners = Array.from({ length: Math.min(limit, items.length) }, () =>
    (async () => {
      while (cursor < items.length) {
        const index = cursor++;
        results[index] = await worker(items[index], index);
      }
    })()
  );
  await Promise.all(runners);
  return results;
}

/**
 * One batched Gemini request for every place in the city. Returns a map of
 * placeId -> one-sentence summary. Never throws: descriptions are a nice to
 * have, so a failure here must not fail the whole ingestion.
 */
async function generateDescriptions({ geminiKey, cityName, places }) {
  if (!geminiKey || places.length === 0) return {};

  const roster = places
    .map((p) => `${p.id} | ${p.name} | ${p.types.slice(0, 3).join(', ')}`)
    .join('\n');

  const prompt =
    `For each place in ${cityName || 'this city'}, write one short, vivid ` +
    `English sentence (max 18 words) that would make a traveller want to ` +
    `visit. Return JSON only.\n\n` +
    `Format: id | name | types\n${roster}`;

  try {
    const response = await fetch(
      `${GEMINI_URL_BASE}/${encodeURIComponent(C.GEMINI_MODEL)}:generateContent`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': geminiKey,
        },
        body: JSON.stringify({
          contents: [{ role: 'user', parts: [{ text: prompt }] }],
          generationConfig: {
            temperature: 0.7,
            maxOutputTokens: 2048,
            responseMimeType: 'application/json',
            responseSchema: {
              type: 'ARRAY',
              items: {
                type: 'OBJECT',
                properties: {
                  id: { type: 'STRING' },
                  sentence: { type: 'STRING' },
                },
                required: ['id', 'sentence'],
              },
            },
            // 2.5 models think by default, and thinking tokens count against
            // the output budget, which silently yields empty candidates.
            thinkingConfig: { thinkingBudget: 0 },
          },
        }),
        signal: AbortSignal.timeout(20000),
      }
    );

    if (!response.ok) {
      logger.warn(`Gemini request failed (HTTP ${response.status})`);
      return {};
    }

    const payload = await response.json();
    const text = payload?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!text) {
      logger.warn('Gemini returned no text part');
      return {};
    }

    const summaries = {};
    for (const entry of JSON.parse(text)) {
      const sentence = String(entry?.sentence ?? '').trim();
      if (entry?.id && sentence) summaries[entry.id] = sentence;
    }
    return summaries;
  } catch (error) {
    logger.warn('Gemini description generation skipped', error);
    return {};
  }
}

/**
 * Reads the cached place ids for a city, newest cache first.
 */
async function readCachedPlaceIds(db, cityKey, limit) {
  const snap = await db
    .collection('places')
    .where('cityId', '==', cityKey)
    .limit(limit)
    .get();
  return snap.docs.map((doc) => doc.id);
}

/**
 * Fetches a city from Google, caches photos in Storage, writes places and
 * cache metadata with the Admin SDK, and returns the place ids.
 */
async function ingestCity({ db, bucket, apiKey, geminiKey, city, limit }) {
  const cityKey = cityKeyFor(city.countryCode, city.cityId);

  const rawPlaces = await nearbySearch({
    apiKey,
    lat: city.lat,
    lng: city.lng,
    limit,
  });

  const places = [];
  for (const raw of rawPlaces) {
    const id = raw?.id;
    // An empty id would become doc('') below and abort the whole batch.
    if (!id) continue;
    places.push({
      id,
      name: raw?.displayName?.text ?? 'Unknown',
      lat: raw?.location?.latitude ?? 0,
      lng: raw?.location?.longitude ?? 0,
      address: raw?.formattedAddress ?? null,
      types: Array.isArray(raw?.types) ? raw.types : [],
      rating: typeof raw?.rating === 'number' ? raw.rating : null,
      photoName: raw?.photos?.[0]?.name ?? null,
      // Google requires photo attributions to be displayed alongside photos.
      photoAttributions: (raw?.photos?.[0]?.authorAttributions ?? []).map(
        (a) => ({
          displayName: a?.displayName ?? '',
          uri: a?.uri ?? '',
        })
      ),
    });
  }

  if (places.length === 0) {
    return { placeIds: [], fetchedCount: 0 };
  }

  const [imageUrls, descriptions] = await Promise.all([
    mapWithConcurrency(places, C.PHOTO_CONCURRENCY, async (place) => {
      if (!place.photoName) return null;
      try {
        return await cachePhoto({
          apiKey,
          bucket,
          placeId: place.id,
          photoName: place.photoName,
        });
      } catch (error) {
        logger.warn(`Photo caching failed for ${place.id}`, error);
        return null;
      }
    }),
    generateDescriptions({ geminiKey, cityName: city.cityName, places }),
  ]);

  const now = admin.firestore.FieldValue.serverTimestamp();
  const expiresAt = new Date(Date.now() + C.CACHE_TTL_DAYS * 86400000);
  const batch = db.batch();

  places.forEach((place, index) => {
    const imageUrl = imageUrls[index];
    const document = {
      id: place.id,
      name: place.name,
      lat: place.lat,
      lng: place.lng,
      types: place.types,
      cityId: cityKey,
      photoAttributions: place.photoAttributions,
      fetchedAt: now,
      expiresAt,
    };
    // Null values are omitted so a later refresh that loses a description or
    // photo cannot erase the copy that is already cached.
    if (place.address) document.address = place.address;
    if (place.rating !== null) document.averageRating = place.rating;
    if (descriptions[place.id]) document.description = descriptions[place.id];
    if (imageUrl) document.imageUrls = [imageUrl];

    batch.set(db.collection('places').doc(place.id), document, {
      merge: true,
    });
  });

  batch.set(db.collection('placeCacheMetadata').doc(cityKey), {
    cityId: cityKey,
    cityName: city.cityName ?? null,
    countryCode: city.countryCode ?? null,
    lat: city.lat,
    lng: city.lng,
    fetchedCount: places.length,
    requestedLimit: limit,
    isExhausted: places.length < limit,
    lastSyncedAt: now,
    expiresAt,
    schemaVersion: C.SCHEMA_VERSION,
  });

  await batch.commit();

  return {
    placeIds: places.map((p) => p.id),
    fetchedCount: places.length,
  };
}

module.exports = {
  assertUsableKey,
  cityKeyFor,
  enforceRateLimit,
  ingestCity,
  readCachedPlaceIds,
};
