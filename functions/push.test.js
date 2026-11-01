'use strict';

const test = require('node:test');
const assert = require('node:assert');
const push = require('./push');

const members = ['a', 'b', 'c'];

test('threshold matches the app rule', () => {
  assert.deepStrictEqual([1, 2, 3, 4, 5].map(push.matchThreshold),
    [1, 2, 2, 3, 3]);
});

test('second like of three members is a new match', () => {
  const others = { a: { votes: { p: 1 } } };
  assert.deepStrictEqual(push.newMatches({
    uid: 'b', before: undefined, after: { votes: { p: 1, q: 0 } },
    others, members,
  }), ['p']);
});

test('third like on an existing match is not new', () => {
  const others = { a: { votes: { p: 1 } }, b: { votes: { p: 1 } } };
  assert.deepStrictEqual(push.newMatches({
    uid: 'c', before: undefined, after: { votes: { p: 1 } }, others, members,
  }), []);
});

test('a veto blocks the match, a nope is no new like', () => {
  const others = { a: { votes: { p: 1 }, veto: 'p' }, c: { votes: {} } };
  assert.deepStrictEqual(push.newMatches({
    uid: 'b', before: undefined, after: { votes: { p: 1 } }, others, members,
  }), []);
  assert.strictEqual(push.hasNewLike({ votes: { p: 1 } },
    { votes: { p: 1, q: 0 } }), false);
});

test('super-like plus one like matches in a group of four', () => {
  const four = ['a', 'b', 'c', 'd'];
  const others = { a: { votes: { p: 2 } } };
  assert.deepStrictEqual(push.newMatches({
    uid: 'b', before: undefined, after: { votes: { p: 1 } },
    others, members: four,
  }), ['p']);
});

test('texts fall back to English and format money', () => {
  assert.strictEqual(push.textsFor('fr'), push.TEXTS.en);
  assert.match(push.formatAmount(1250, 'EUR', 'de'), /12,50/);
  assert.strictEqual(push.tripTitle({ location: { cityName: 'Lisbon' } }),
    'Lisbon');
});
