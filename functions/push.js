'use strict';

// Push notifications for trip events. Pure helpers (texts, match check) sit
// next to the sending code so they can be tested without Firebase.

const TEXTS = {
  en: {
    joinTitle: (trip) => trip,
    joinBody: (name) => `${name} joined the trip.`,
    expenseTitle: (trip) => trip,
    expenseBody: (name, what, amount) => `${name} added ${what} (${amount}).`,
    journalTitle: (trip) => trip,
    journalBody: (name) => `${name} wrote in the journal.`,
    matchTitle: () => "It's a match!",
    matchBody: (place, trip) => `${place} is now on the wishlist for ${trip}.`,
    someone: 'Someone',
    aPlace: 'A place',
  },
  de: {
    joinTitle: (trip) => trip,
    joinBody: (name) => `${name} ist der Reise beigetreten.`,
    expenseTitle: (trip) => trip,
    expenseBody: (name, what, amount) =>
      `${name} hat ${what} (${amount}) eingetragen.`,
    journalTitle: (trip) => trip,
    journalBody: (name) => `${name} hat ins Tagebuch geschrieben.`,
    matchTitle: () => 'Match!',
    matchBody: (place, trip) =>
      `${place} steht jetzt auf der Wunschliste für ${trip}.`,
    someone: 'Jemand',
    aPlace: 'Ein Ort',
  },
};

function textsFor(lang) {
  return TEXTS[lang] ?? TEXTS.en;
}

function tripTitle(group) {
  return group?.groupName || group?.location?.cityName || 'TripFam';
}

function formatAmount(cents, currency, lang) {
  try {
    return new Intl.NumberFormat(lang, {
      style: 'currency',
      currency: currency || 'EUR',
    }).format((Number(cents) || 0) / 100);
  } catch (_) {
    return `${((Number(cents) || 0) / 100).toFixed(2)} ${currency ?? ''}`.trim();
  }
}

// Same rule as lib/common/utils/group_swipes.dart (keep them in sync):
// a majority and at least 2 likes, or a super-like plus one more like, and
// never a vetoed place.
function matchThreshold(memberCount) {
  if (memberCount <= 1) return 1;
  return Math.max(2, Math.floor(memberCount / 2) + 1);
}

const LIKE = 1;
const SUPER_LIKE = 2;

function isMatch(placeId, swipes, members) {
  let likes = 0;
  let superLikes = 0;
  for (const uid of members) {
    const s = swipes[uid];
    if (!s) continue;
    if (s.veto === placeId) return false;
    const vote = s.votes?.[placeId];
    if (vote === LIKE || vote === SUPER_LIKE) likes++;
    if (vote === SUPER_LIKE) superLikes++;
  }
  return likes >= matchThreshold(members.length) ||
    (superLikes > 0 && likes >= 2);
}

/**
 * Places that became a group match through one member's swipe change.
 * [others] holds the other members' swipe docs by uid; [before]/[after] are
 * the changed member's doc (or undefined).
 */
function newMatches({ uid, before, after, others, members }) {
  if (members.length < 2) return [];
  const changed = Object.keys(after?.votes ?? {}).filter((id) => {
    const v = after.votes[id];
    return (v === LIKE || v === SUPER_LIKE) && v !== before?.votes?.[id];
  });
  return changed.filter((id) =>
    isMatch(id, { ...others, [uid]: after }, members) &&
    !isMatch(id, { ...others, [uid]: before }, members));
}

/** Only these swipe changes can create a match, so others skip all reads. */
function hasNewLike(before, after) {
  return Object.entries(after?.votes ?? {}).some(([id, v]) =>
    (v === LIKE || v === SUPER_LIKE) && v !== before?.votes?.[id]);
}

const DEAD_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

/**
 * Sends one push per language to every device of [uids]. [build] gets the
 * texts for a language and returns {title, body}. Tokens live in
 * pushTokens/{token} with {uid, lang}; dead ones are deleted.
 */
async function sendToUsers(db, messaging, uids, build, data) {
  const recipients = [...new Set(uids)];
  if (recipients.length === 0) return;
  const tokens = [];
  // shortcut: 'in' takes at most 30 values; fine for trip-sized groups.
  for (let i = 0; i < recipients.length; i += 30) {
    const snap = await db.collection('pushTokens')
      .where('uid', 'in', recipients.slice(i, i + 30)).get();
    snap.forEach((doc) => tokens.push({ token: doc.id, lang: doc.get('lang') }));
  }
  const byLang = new Map();
  for (const t of tokens) {
    const lang = TEXTS[t.lang] ? t.lang : 'en';
    if (!byLang.has(lang)) byLang.set(lang, []);
    byLang.get(lang).push(t.token);
  }
  for (const [lang, list] of byLang) {
    const { title, body } = build(textsFor(lang), lang);
    const res = await messaging.sendEachForMulticast({
      tokens: list,
      notification: { title, body },
      data,
      android: { notification: { channelId: 'trip_updates' } },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    await Promise.all(res.responses.map((r, i) =>
      !r.success && DEAD_TOKEN_CODES.has(r.error?.code)
        ? db.collection('pushTokens').doc(list[i]).delete()
        : null));
  }
}

/** The user's display name, or null (then the texts' "someone"). */
async function displayName(db, uid) {
  const doc = await db.collection('users').doc(uid).get();
  return doc.get('displayName') || null;
}

module.exports = {
  TEXTS,
  textsFor,
  tripTitle,
  formatAmount,
  matchThreshold,
  isMatch,
  newMatches,
  hasNewLike,
  sendToUsers,
  displayName,
};
