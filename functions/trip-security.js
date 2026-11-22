'use strict';

async function lookupPaymentHandle(db, groupId, requester, recipient) {
  return db.runTransaction(async (transaction) => {
    const group = await transaction.get(db.collection('groups').doc(groupId));
    const members = group.get('members');
    if (!Array.isArray(members) ||
        !members.includes(requester) || !members.includes(recipient)) {
      return null;
    }
    const profile = await transaction.get(db.collection('users').doc(recipient));
    const handle = profile.get('paypalHandle');
    return typeof handle === 'string' && handle.length <= 64 ? handle : null;
  }, { readOnly: true });
}

async function cleanDeletedTrip(db, bucket, groupRef) {
  // Keep the parent tombstone. Recursive deletion of the parent would let
  // clients claim its ID again. Each cleanup step can safely be retried.
  const children = await groupRef.listCollections();
  for (const child of children) {
    await db.recursiveDelete(child);
  }
  await bucket.deleteFiles({ prefix: `trips/${groupRef.id}/journal/` });

  const invites = await db.collection('inviteCodes')
    .where('groupId', '==', groupRef.id).get();
  for (const invite of invites.docs) {
    await db.runTransaction(async (transaction) => {
      const current = await transaction.get(invite.ref);
      if (current.get('groupId') === groupRef.id) {
        transaction.set(invite.ref, { retired: true });
      }
    });
  }
}

module.exports = { lookupPaymentHandle, cleanDeletedTrip };
