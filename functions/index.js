'use strict';

const admin = require('firebase-admin');
const { setGlobalOptions } = require('firebase-functions/v2');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentWritten,
} = require('firebase-functions/v2/firestore');
const { defineSecret } = require('firebase-functions/params');
const { logger } = require('firebase-functions');

const C = require('./config');
const {
  assertUsableKey,
  cityKeyFor,
  enforceRateLimit,
  ingestCity,
  readCachedPlaceIds,
} = require('./places');
const push = require('./push');

admin.initializeApp();
setGlobalOptions({ region: C.REGION, maxInstances: 5 });

// Secrets live in Secret Manager and never ship inside the app bundle. Set
// them once per project:
//   firebase functions:secrets:set PLACES_API_KEY
//   firebase functions:secrets:set GEMINI_API_KEY   (optional)
const PLACES_API_KEY = defineSecret('PLACES_API_KEY');
const GEMINI_API_KEY = defineSecret('GEMINI_API_KEY');

const db = () => admin.firestore();
const bucket = () => admin.storage().bucket();

function readCityArgs(data) {
  const countryCode = String(data?.countryCode ?? '').trim();
  const cityId = String(data?.cityId ?? '').trim();
  const cityName = String(data?.cityName ?? '').trim();
  const lat = Number(data?.lat);
  const lng = Number(data?.lng);
  const requested = Number(data?.limit ?? C.MAX_PLACES_PER_CITY);

  if (!countryCode || !cityId) {
    throw new HttpsError(
      'invalid-argument',
      'countryCode and cityId are required.'
    );
  }
  if (!Number.isFinite(lat) || lat < -90 || lat > 90) {
    throw new HttpsError('invalid-argument', 'lat must be between -90 and 90.');
  }
  if (!Number.isFinite(lng) || lng < -180 || lng > 180) {
    throw new HttpsError(
      'invalid-argument',
      'lng must be between -180 and 180.'
    );
  }

  const limit = Math.max(
    1,
    Math.min(
      Number.isFinite(requested) ? Math.trunc(requested) : C.MAX_PLACES_PER_CITY,
      C.MAX_PLACES_PER_CITY
    )
  );

  return { countryCode, cityId, cityName, lat, lng, limit };
}

/**
 * Returns the place ids for a city, serving the shared Firestore cache when it
 * is warm and calling Google only on a miss. This is the only place that holds
 * a Google API key, so the app can never leak one.
 */
exports.getCityPlaces = onCall(
  {
    secrets: [PLACES_API_KEY, GEMINI_API_KEY],
    // Flip to true once Firebase App Check is wired up in the app.
    enforceAppCheck: false,
    timeoutSeconds: 120,
    memory: '512MiB',
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        'unauthenticated',
        'You must be signed in to load places.'
      );
    }

    const city = readCityArgs(request.data);
    const cityKey = cityKeyFor(city.countryCode, city.cityId);
    const firestore = db();

    // 1. Cache first: never spend money on a city we already know.
    const metadataSnap = await firestore
      .collection('placeCacheMetadata')
      .doc(cityKey)
      .get();
    const metadata = metadataSnap.exists ? metadataSnap.data() : null;
    const expiresAtMs = metadata?.expiresAt?.toMillis?.() ?? 0;
    const isFresh = expiresAtMs > Date.now();

    if (metadata && isFresh) {
      const cachedIds = await readCachedPlaceIds(
        firestore,
        cityKey,
        C.MAX_PLACES_PER_CITY
      );
      const enough =
        cachedIds.length >= city.limit ||
        (metadata.isExhausted === true && cachedIds.length > 0);
      if (enough) {
        return {
          placeIds: cachedIds.slice(0, city.limit),
          fromCache: true,
          cityKey,
        };
      }
    }

    // 2. Cache miss: this is the paid path, so throttle it per user.
    try {
      await enforceRateLimit(firestore, request.auth.uid);
    } catch (error) {
      throw new HttpsError('resource-exhausted', error.message);
    }

    let placesKey;
    try {
      placesKey = assertUsableKey(PLACES_API_KEY.value(), 'PLACES_API_KEY');
    } catch (error) {
      logger.error('Places API key missing or placeholder');
      throw new HttpsError('failed-precondition', error.message);
    }

    // Optional: without it, places are cached without AI descriptions.
    let geminiKey = null;
    try {
      geminiKey = assertUsableKey(GEMINI_API_KEY.value(), 'GEMINI_API_KEY');
    } catch (_) {
      logger.info('Gemini key not configured; skipping AI descriptions.');
    }

    try {
      const { placeIds } = await ingestCity({
        db: firestore,
        bucket: bucket(),
        apiKey: placesKey,
        geminiKey,
        city,
        limit: city.limit,
      });

      if (placeIds.length === 0) {
        throw new HttpsError(
          'not-found',
          'No places found for this destination.'
        );
      }

      return { placeIds, fromCache: false, cityKey };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      logger.error(`Ingestion failed for ${cityKey}`, error);
      throw new HttpsError('internal', 'Could not load places right now.');
    }
  }
);

/**
 * Refreshes cities whose cached content has passed its TTL. Google's Places
 * policy does not permit caching place content indefinitely.
 */
exports.refreshExpiredCityCaches = onSchedule(
  {
    schedule: 'every 24 hours',
    secrets: [PLACES_API_KEY, GEMINI_API_KEY],
    timeoutSeconds: 540,
    memory: '512MiB',
  },
  async () => {
    const firestore = db();

    let placesKey;
    try {
      placesKey = assertUsableKey(PLACES_API_KEY.value(), 'PLACES_API_KEY');
    } catch (error) {
      logger.warn('Skipping refresh: Places API key not configured.');
      return;
    }

    let geminiKey = null;
    try {
      geminiKey = assertUsableKey(GEMINI_API_KEY.value(), 'GEMINI_API_KEY');
    } catch (_) {
      geminiKey = null;
    }

    // Bounded per run so a large cache cannot produce a surprise bill.
    const expired = await firestore
      .collection('placeCacheMetadata')
      .where('expiresAt', '<', new Date())
      .limit(10)
      .get();

    if (expired.empty) {
      logger.info('No expired city caches.');
      return;
    }

    for (const doc of expired.docs) {
      const data = doc.data();
      if (
        typeof data.lat !== 'number' ||
        typeof data.lng !== 'number' ||
        !data.countryCode
      ) {
        logger.warn(`Skipping ${doc.id}: incomplete cache metadata.`);
        continue;
      }

      try {
        await ingestCity({
          db: firestore,
          bucket: bucket(),
          apiKey: placesKey,
          geminiKey,
          city: {
            countryCode: data.countryCode,
            cityId: String(doc.id).split('_').slice(1).join('_'),
            cityName: data.cityName ?? '',
            lat: data.lat,
            lng: data.lng,
          },
          limit: C.MAX_PLACES_PER_CITY,
        });
        logger.info(`Refreshed ${doc.id}`);
      } catch (error) {
        logger.error(`Refresh failed for ${doc.id}`, error);
      }
    }
  }
);

// ---------------------------------------------------------------------------
// Push notifications for trip events. Firestore triggers must run in the
// database's region (europe-west3). The sender is never notified.

const TRIGGER_REGION = 'europe-west3';

async function tripMembers(groupId) {
  const doc = await db().collection('groups').doc(groupId).get();
  return doc.exists ? doc.data() : null;
}

exports.pushOnMemberJoined = onDocumentUpdated(
  { document: 'groups/{groupId}', region: TRIGGER_REGION },
  async (event) => {
    const before = event.data.before.get('members') ?? [];
    const group = event.data.after.data();
    const joined = (group.members ?? []).filter((u) => !before.includes(u));
    const { groupId } = event.params;
    for (const uid of joined) {
      const name = await push.displayName(db(), uid);
      await push.sendToUsers(db(), admin.messaging(),
        before.filter((u) => (group.members ?? []).includes(u)),
        (t) => ({
          title: t.joinTitle(push.tripTitle(group)),
          body: t.joinBody(name ?? t.someone),
        }),
        { route: `/trip/${groupId}` });
    }
  }
);

exports.pushOnExpenseAdded = onDocumentCreated(
  { document: 'groups/{groupId}/expenses/{expenseId}', region: TRIGGER_REGION },
  async (event) => {
    const expense = event.data.data();
    const { groupId } = event.params;
    const group = await tripMembers(groupId);
    if (!group) return;
    const name = await push.displayName(db(), expense.createdBy);
    await push.sendToUsers(db(), admin.messaging(),
      (group.members ?? []).filter((u) => u !== expense.createdBy),
      (t, lang) => ({
        title: t.expenseTitle(push.tripTitle(group)),
        body: t.expenseBody(name ?? t.someone, expense.title,
          push.formatAmount(expense.amountCents, expense.currency, lang)),
      }),
      { route: `/trip/${groupId}/costs` });
  }
);

exports.pushOnJournalEntry = onDocumentCreated(
  { document: 'groups/{groupId}/journal/{entryId}', region: TRIGGER_REGION },
  async (event) => {
    const entry = event.data.data();
    const { groupId } = event.params;
    const group = await tripMembers(groupId);
    if (!group) return;
    const name = await push.displayName(db(), entry.authorUid);
    await push.sendToUsers(db(), admin.messaging(),
      (group.members ?? []).filter((u) => u !== entry.authorUid),
      (t) => ({
        title: t.journalTitle(push.tripTitle(group)),
        body: t.journalBody(name ?? t.someone),
      }),
      { route: `/trip/${groupId}/journal` });
  }
);

// Runs on every swipe, so it returns before any read unless the change is a
// new like (most swipes are nopes or swipes of someone planning alone).
exports.pushOnSwipeMatch = onDocumentWritten(
  { document: 'groups/{groupId}/swipes/{uid}', region: TRIGGER_REGION },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (!push.hasNewLike(before, after)) return;
    const { groupId, uid } = event.params;
    const group = await tripMembers(groupId);
    const members = group?.members ?? [];
    if (members.length < 2 || !members.includes(uid)) return;
    const snap = await db().collection('groups').doc(groupId)
      .collection('swipes').get();
    const others = {};
    snap.forEach((doc) => {
      if (doc.id !== uid) others[doc.id] = doc.data();
    });
    const matches = push.newMatches({ uid, before, after, others, members });
    for (const placeId of matches.slice(0, 3)) {
      const place = await db().collection('places').doc(placeId).get();
      await push.sendToUsers(db(), admin.messaging(),
        members.filter((u) => u !== uid),
        (t, lang) => ({
          title: t.matchTitle(),
          body: t.matchBody(
            place.get(`names.${lang}`) || place.get('name') || t.aPlace,
            push.tripTitle(group)),
        }),
        { route: `/trip/${groupId}` });
    }
  }
);
