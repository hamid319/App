'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const { lookupPaymentHandle, cleanDeletedTrip } = require('./trip-security');

test('payment lookup reads the handle only while both users share the trip', async () => {
  const reads = [];
  let members = ['alice', 'bob'];
  const db = {
    collection: (name) => ({ doc: (id) => `${name}/${id}` }),
    runTransaction: (read) => read({
      get: async (path) => {
        reads.push(path);
        if (path === 'groups/trip') return { get: () => members };
        assert.equal(path, 'users/bob');
        return { get: () => 'bob1' };
      },
    }),
  };
  assert.equal(await lookupPaymentHandle(db, 'trip', 'stranger', 'bob'), null);
  assert.deepEqual(reads, ['groups/trip']);
  assert.equal(await lookupPaymentHandle(db, 'trip', 'alice', 'bob'), 'bob1');
  members = ['alice'];
  reads.length = 0;
  assert.equal(await lookupPaymentHandle(db, 'trip', 'alice', 'bob'), null);
  assert.deepEqual(reads, ['groups/trip']);
});

test('retired trip cleanup is scoped to descendants, files and owned invites', async () => {
  const children = new Set(['groups/trip/expenses', 'groups/trip/sessions']);
  const groupRef = { id: 'trip', listCollections: async () => [...children] };
  const files = new Set(['trips/trip/journal/e/0.jpg', 'trips/other/journal/e/0.jpg']);
  const invites = new Map([['old', { groupId: 'trip', title: 'Private' }],
    ['other', { groupId: 'other' }]]);
  const db = {
    recursiveDelete: async (child) => {
      assert.ok(children.delete(child));
    },
    collection: (name) => {
      assert.equal(name, 'inviteCodes');
      return { where: (field, operator, id) => ({
        get: async () => ({
          docs: [...invites.keys()]
            .filter((ref) => operator === '==' && invites.get(ref)[field] === id)
            .map((ref) => ({ ref })),
        }),
      }) };
    },
    runTransaction: (run) => run({
      get: async (ref) => ({ get: (field) => invites.get(ref)?.[field] }),
      set: (ref, data) => invites.set(ref, data),
    }),
  };
  const bucket = { deleteFiles: async ({ prefix }) => {
    for (const file of files) if (file.startsWith(prefix)) files.delete(file);
  } };

  await cleanDeletedTrip(db, bucket, groupRef);
  await cleanDeletedTrip(db, bucket, groupRef);
  assert.equal(children.size, 0);
  assert.deepEqual([...files], ['trips/other/journal/e/0.jpg']);
  assert.deepEqual(invites.get('old'), { retired: true });
  assert.deepEqual(invites.get('other'), { groupId: 'other' });
});
