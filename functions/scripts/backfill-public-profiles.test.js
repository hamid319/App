'use strict';

const test = require('node:test');
const assert = require('node:assert');
const { publicFields } = require('./backfill-public-profiles');

test('copies only the public fields', () => {
  assert.deepStrictEqual(
    publicFields({ displayName: 'Bob', email: 'bob@example.com', paypalHandle: 'bob1', favorites: ['x'] }),
    { displayName: 'Bob' },
  );
});

test('skips values the rules would reject', () => {
  assert.deepStrictEqual(
    publicFields({ displayName: 'x'.repeat(101), photoUrl: 42, paypalHandle: 'ok' }),
    null,
  );
});

test('nothing to show gives null', () => {
  assert.strictEqual(publicFields({ email: 'a@example.com', displayName: '  ' }), null);
});
