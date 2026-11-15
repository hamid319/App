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
      { displayName: 'Alice', photoUrl: null, paypalHandle: 'alice1' })));
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
    await assertSucceeds(setDoc(doc(db('carol'), 'groups/g2'),
      { ownerUid: 'carol', members: ['carol'], invite: { code: 'X' } }));
    await assertFails(setDoc(doc(db('carol'), 'groups/g3'),
      { ownerUid: 'carol', members: ['carol', 'bob'], invite: { code: 'X' } }));
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
  test('only the owner deletes the trip', async () => {
    await assertFails(deleteDoc(doc(db('bob'), 'groups/g1')));
    await assertSucceeds(deleteDoc(doc(db('alice'), 'groups/g1')));
  });
  test('invite codes cannot be listed', () =>
    assertFails(getDocs(collection(db('carol'), 'inviteCodes'))));
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
