'use strict';

const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { getStorage } = require('firebase-admin/storage');
const { setGlobalOptions } = require('firebase-functions/v2');
const { HttpsError, onCall } = require('firebase-functions/v2/https');
const {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentWritten,
} = require('firebase-functions/v2/firestore');

const push = require('./push');
const { lookupPaymentHandle, cleanDeletedTrip } = require('./trip-security');

initializeApp();
// Caps a runaway trigger loop's bill; pushes need no more.
setGlobalOptions({ maxInstances: 5 });

// firebase-admin 14 has no namespaced firestore()/messaging() any more.
const db = () => getFirestore();

// ---------------------------------------------------------------------------
// Push notifications for trip events. Firestore triggers must run in the
// database's region (europe-west3). The sender is never notified.

const TRIGGER_REGION = 'europe-west3';

exports.getTripPaymentHandle = onCall({ region: TRIGGER_REGION }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign-in required.');
  const { groupId, uid } = request.data ?? {};
  const validId = (id) => typeof id === 'string' && /^[A-Za-z0-9_~-]{1,128}$/.test(id);
  if (!validId(groupId) || !validId(uid)) {
    throw new HttpsError('invalid-argument', 'A trip and member are required.');
  }
  return lookupPaymentHandle(db(), groupId, request.auth.uid, uid);
});

exports.cleanupDeletedTrip = onDocumentUpdated(
  { document: 'groups/{groupId}', region: TRIGGER_REGION, retry: true },
  async (event) => {
    if (event.data.before.get('deleted') === true ||
        event.data.after.get('deleted') !== true) return;
    await cleanDeletedTrip(db(), getStorage().bucket(), event.data.after.ref);
  }
);

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
      await push.sendToUsers(db(), getMessaging(),
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
    await push.sendToUsers(db(), getMessaging(),
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
    await push.sendToUsers(db(), getMessaging(),
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
      await push.sendToUsers(db(), getMessaging(),
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
