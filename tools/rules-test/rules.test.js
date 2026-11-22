// Firestore rules tests. Run with `npm test` (starts the emulator; needs Java 21).
import { after, before, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

let env;
const rules = readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8');
const db = (uid) => env.authenticatedContext(uid).firestore();
const signedOut = () => env.unauthenticatedContext().firestore();

// Trip g1: owner alice, member bob; carol is a stranger.
const group = {
  ownerUid: 'alice',
  members: ['alice', 'bob'],
  title: 'Hamburg',
  invite: { code: 'JOIN42' },
};
const expense = (by, extra = {}) => ({
  title: 'Dinner',
  amountCents: 4200,
  currency: 'EUR',
  paidBy: by,
  participants: ['alice', 'bob'],
  createdBy: by,
  createdAt: Timestamp.now(),
  ...extra,
});
const newGroupId = 'trip~AbCd1234AbCd1234AbCd';
function createTrip(database, id, code, members) {
  const batch = writeBatch(database);
  batch.set(doc(database, 'groups', id), {
    groupId: id, ownerUid: members[0], members, invite: { code },
  });
  batch.set(doc(database, 'inviteCodes', code), { groupId: id });
  return batch.commit();
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-rules-test',
    firestore: { rules, host: '127.0.0.1', port: 8080 },
  });
});
after(() => env.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const admin = ctx.firestore();
    await setDoc(doc(admin, 'users/bob'), { email: 'bob@example.com', displayName: 'Bob' });
    await setDoc(doc(admin, 'publicProfiles/bob'), { displayName: 'Bob' });
    await setDoc(doc(admin, 'groups/g1'), group);
    await setDoc(doc(admin, 'groups/g1/swipes/bob'), { votes: { p1: 1 } });
    await setDoc(doc(admin, 'groups/g1/expenses/e1'), expense('bob'));
    await setDoc(doc(admin, 'inviteCodes/JOIN42'), { groupId: 'g1' });
  });
});

describe('users and public profiles', () => {
  test('others cannot read /users (emails stay private)', () =>
    assertFails(getDoc(doc(db('alice'), 'users/bob'))));
  test('owner reads own /users', () => assertSucceeds(getDoc(doc(db('bob'), 'users/bob'))));
  test('signed-in users read a public profile', () =>
    assertSucceeds(getDoc(doc(db('alice'), 'publicProfiles/bob'))));
  test('signed-out users cannot read a public profile', () =>
    assertFails(getDoc(doc(signedOut(), 'publicProfiles/bob'))));
  test('public profiles cannot be listed', () =>
    assertFails(getDocs(collection(db('alice'), 'publicProfiles'))));
  test('owner writes own public profile', () =>
    assertSucceeds(setDoc(doc(db('alice'), 'publicProfiles/alice'),
      { displayName: 'Alice', photoUrl: null })));
  test('legacy PayPal handles stay private until removed', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'publicProfiles/bob'),
        { displayName: 'Bob', paypalHandle: 'bob1' }));
    await assertFails(getDoc(doc(db('carol'), 'publicProfiles/bob')));
    await assertFails(getDoc(doc(db('alice'), 'publicProfiles/bob')));
    await assertFails(setDoc(doc(db('bob'), 'publicProfiles/bob'),
      { displayName: 'Bob', paypalHandle: 'bob2' }));
    await assertSucceeds(setDoc(doc(db('bob'), 'publicProfiles/bob'),
      { displayName: 'Bob' }));
    await assertSucceeds(getDoc(doc(db('carol'), 'publicProfiles/bob')));
  });
  test("nobody writes someone else's public profile", () =>
    assertFails(setDoc(doc(db('alice'), 'publicProfiles/bob'), { displayName: 'X' })));
  test('email cannot go into a public profile', () =>
    assertFails(setDoc(doc(db('alice'), 'publicProfiles/alice'), { email: 'a@example.com' })));
  test('name is capped at 100 characters', () =>
    assertFails(setDoc(doc(db('alice'), 'publicProfiles/alice'), { displayName: 'x'.repeat(101) })));
});

describe('groups', () => {
  test('members read the trip', () => assertSucceeds(getDoc(doc(db('bob'), 'groups/g1'))));
  test('strangers cannot read the trip', () =>
    assertFails(getDoc(doc(db('carol'), 'groups/g1'))));
  test('a new trip may only contain its creator', async () => {
    await assertFails(createTrip(db('carol'), newGroupId, 'UNIQUE', ['carol', 'bob']));
    await assertSucceeds(createTrip(db('carol'), newGroupId, 'UNIQUE', ['carol']));
  });
  test('joining works with the invite code', () =>
    assertSucceeds(updateDoc(doc(db('carol'), 'groups/g1'),
      { members: ['alice', 'bob', 'carol'], joinCode: 'JOIN42' })));
  test('joining fails with a wrong code', () =>
    assertFails(updateDoc(doc(db('carol'), 'groups/g1'),
      { members: ['alice', 'bob', 'carol'], joinCode: 'WRONG' })));
  test('a member cannot rename the trip', () =>
    assertFails(updateDoc(doc(db('bob'), 'groups/g1'), { title: 'Mine' })));
  test('a member cannot write sharedFavorites (no longer used)', () =>
    assertFails(updateDoc(doc(db('bob'), 'groups/g1'), { sharedFavorites: ['p1'] })));
  test('a member may leave', () =>
    assertSucceeds(updateDoc(doc(db('bob'), 'groups/g1'), { members: ['alice'] })));
  test('a member cannot remove someone else', () =>
    assertFails(updateDoc(doc(db('bob'), 'groups/g1'), { members: ['bob'] })));
  test('leaving preserves every other member', () =>
    assertFails(updateDoc(doc(db('bob'), 'groups/g1'), { members: [] })));
  test('only the user joining may be added', async () => {
    await assertFails(updateDoc(doc(db('bob'), 'groups/g1'),
      { members: ['alice', 'bob', 'carol'], joinCode: 'JOIN42' }));
    await assertFails(updateDoc(doc(db('bob'), 'groups/g1'),
      { members: ['alice', 'bob', 'bob'], joinCode: 'JOIN42' }));
    await assertFails(updateDoc(doc(db('alice'), 'groups/g1'),
      { members: ['alice', 'bob', 'carol'] }));
    await assertSucceeds(updateDoc(doc(db('alice'), 'groups/g1'),
      { members: ['bob'], ownerUid: 'bob' }));
  });
  test('only the owner retires a trip and neither ID nor data can be reclaimed', async () => {
    const retired = { deleted: true, members: [] };
    await assertFails(deleteDoc(doc(db('bob'), 'groups/g1')));
    await assertFails(deleteDoc(doc(db('alice'), 'groups/g1')));
    await assertFails(setDoc(doc(db('bob'), 'groups/g1'), retired));
    await assertSucceeds(setDoc(doc(db('alice'), 'groups/g1'), retired));
    await assertFails(getDoc(doc(db('carol'), 'groups/g1/expenses/e1')));
    await assertFails(getDoc(doc(db('carol'), 'inviteCodes/JOIN42')));
    await assertFails(createTrip(db('carol'), 'g1', 'JOIN42', ['carol']));
    await assertSucceeds(createTrip(db('alice'), newGroupId, 'FRESH1', ['alice']));
    await assertSucceeds(setDoc(doc(db('alice'), 'groups', newGroupId), retired));
    await assertFails(createTrip(db('carol'), newGroupId, 'FRESH2', ['carol']));
  });
  test('legacy orphan IDs stay reserved without a parent document', async () => {
    const orphan = 'dEaD1234aBcD1234aBcD';
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'groups', orphan, 'expenses', 'e'), expense('bob')));
    await assertFails(createTrip(db('carol'), orphan, 'FRESH1', ['carol']));
    await assertFails(getDoc(doc(db('carol'), 'groups', orphan, 'expenses', 'e')));
  });
  test('an existing invite stays with its trip', async () => {
    await assertFails(createTrip(db('carol'), newGroupId, 'JOIN42', ['carol']));
    await assertSucceeds(createTrip(db('carol'), newGroupId, 'FRESH1', ['carol']));
    await assertFails(setDoc(doc(db('carol'), 'inviteCodes/JOIN42'),
      { groupId: newGroupId }));
    await assertSucceeds(updateDoc(doc(db('alice'), 'inviteCodes/JOIN42'),
      { title: 'Updated title' }));
  });
  test('members and owners may only store well-shaped day plans', async () => {
    for (const uid of ['bob', 'alice']) {
      const ref = doc(db(uid), 'groups/g1');
      await assertFails(updateDoc(ref, {
        tripPlan: { days: [{ placeIds: 'invalid' }], updatedAt: serverTimestamp() },
      }));
      await assertSucceeds(updateDoc(ref, {
        tripPlan: {
          days: Array.from({ length: 14 }, () => ({ placeIds: ['p1'] })),
          updatedAt: serverTimestamp(),
        },
      }));
    }
  });
  test('invite codes cannot be listed', () =>
    assertFails(getDocs(collection(db('carol'), 'inviteCodes'))));
});

describe('journal, polls and private swipe history', () => {
  test('journal photos must load from their own entry in the app bucket', async () => {
    const ref = doc(db('bob'), 'groups/g1/journal/j1');
    const photos = Array.from({ length: 6 }, (_, i) => {
      const path = `trips/g1/journal/j1/${i}.jpg`;
      return { path, width: 400, height: 300,
        url: 'https://firebasestorage.googleapis.com/v0/b/travelapp-31255.firebasestorage.app/o/'
          + encodeURIComponent(path) + '?alt=media&token=fake' };
    });
    const entry = {
      authorUid: 'bob', day: '2026-11-20', text: '',
      createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    };
    await assertFails(setDoc(ref, { ...entry, photos: [{ ...photos[0], url: 'https://example.test/p.jpg' }] }));
    await assertFails(setDoc(ref, { ...entry, photos: [{ ...photos[0], path: 'trips/g1/journal/j2/0.jpg' }] }));
    await assertSucceeds(setDoc(ref, { ...entry, photos }));
  });
  test('poll options require string IDs and labels', async () => {
    const ref = doc(db('bob'), 'groups/g1/polls/p1');
    const poll = { question: 'Where?', createdBy: 'bob', votes: {}, closed: false,
      createdAt: serverTimestamp() };
    await assertFails(setDoc(ref, { ...poll, options: [{ id: 'a', label: 42 }, { id: 'b', label: 'Park' }] }));
    await assertSucceeds(setDoc(ref, { ...poll, options: [{ id: 'a', label: 'Market' }, { id: 'b', label: 'Park' }] }));
  });
  test('solo swipe history stays with its original author', async () => {
    const path = 'swipeResults/bob_p1';
    await assertSucceeds(setDoc(doc(db('bob'), path), { userId: 'bob', liked: true }));
    await assertFails(updateDoc(doc(db('carol'), path), { userId: 'carol' }));
    await assertFails(getDoc(doc(db('carol'), path)));
    await assertSucceeds(updateDoc(doc(db('bob'), path), { liked: false }));
  });
});

describe('swipes', () => {
  test('members read all swipes', () =>
    assertSucceeds(getDoc(doc(db('alice'), 'groups/g1/swipes/bob'))));
  test('strangers cannot read swipes', () =>
    assertFails(getDoc(doc(db('carol'), 'groups/g1/swipes/bob'))));
  test('a member writes own votes', () =>
    assertSucceeds(setDoc(doc(db('alice'), 'groups/g1/swipes/alice'),
      { votes: { p1: 2 }, veto: 'p9' })));
  test("a member cannot write someone else's votes", () =>
    assertFails(setDoc(doc(db('alice'), 'groups/g1/swipes/bob'), { votes: { p1: 0 } })));
  test('strangers cannot vote', () =>
    assertFails(setDoc(doc(db('carol'), 'groups/g1/swipes/carol'), { votes: {} })));
});

describe('expenses and claims', () => {
  test('a member adds a valid expense', () =>
    assertSucceeds(setDoc(doc(db('alice'), 'groups/g1/expenses/e2'), expense('alice'))));
  test('amount must be positive', () =>
    assertFails(setDoc(doc(db('alice'), 'groups/g1/expenses/e2'),
      expense('alice', { amountCents: 0 }))));
  test('participants must be members', () =>
    assertFails(setDoc(doc(db('alice'), 'groups/g1/expenses/e2'),
      expense('alice', { participants: ['alice', 'carol'] }))));
  test('nobody adds an expense in someone else\'s name', () =>
    assertFails(setDoc(doc(db('alice'), 'groups/g1/expenses/e2'),
      expense('alice', { createdBy: 'bob' }))));
  test('strangers cannot read expenses', () =>
    assertFails(getDoc(doc(db('carol'), 'groups/g1/expenses/e1'))));
  test("only the creator edits an expense", () =>
    assertFails(updateDoc(doc(db('alice'), 'groups/g1/expenses/e1'), { title: 'Mine' })));
  test('a member writes own receipt claims', () =>
    assertSucceeds(setDoc(doc(db('alice'), 'groups/g1/claims/alice'),
      { items: { e1: ['i1'] }, updatedAt: serverTimestamp() })));
  test("a member cannot write someone else's claims", () =>
    assertFails(setDoc(doc(db('alice'), 'groups/g1/claims/bob'),
      { items: {}, updatedAt: serverTimestamp() })));
});
