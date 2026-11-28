// Tester — Sprint 8: close-company and member-deletion rules (emulator only).
// Independent of sprint8_account.test.js; payloads mirror
// AccountRepository.commitExit.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  arrayRemove,
  arrayUnion,
  deleteDoc,
  doc,
  getDoc,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const here = dirname(fileURLToPath(import.meta.url));

/** @type {import('@firebase/rules-unit-testing').RulesTestEnvironment} */
let env;
const as = (uid) => env.authenticatedContext(uid).firestore();
const inDays = (d) => Timestamp.fromMillis(Date.now() + d * 86400000);

const company = (owners, name) => ({
  name, nameLower: name.toLowerCase(), city: null, phoneE164: null,
  ownerUids: owners, nextLoanNo: 1, createdBy: owners[0],
  createdAt: Timestamp.now(), schemaVersion: 1,
});
const member = (uid, role, over = {}) => ({
  uid, role, displayName: uid, phoneE164: null, status: 'active',
  inviteCode: null, invitedBy: null, joinedAt: Timestamp.now(), schemaVersion: 1,
  ...over,
});
const membership = (cid, role) => ({
  companyId: cid, companyName: cid, role, joinedAt: Timestamp.now(), schemaVersion: 1,
});
const invite = (cid, role, over = {}) => ({
  companyId: cid, companyName: cid, companyCity: null, role,
  inviteeName: 'X', inviteePhoneE164: '+919845012891', createdBy: 'solo',
  createdByName: 'Solo', createdAt: Timestamp.now(), expiresAt: inDays(7),
  status: 'pending', acceptedBy: null, acceptedAt: null, schemaVersion: 1, ...over,
});
const closeFields = (uid) => ({ ownerUids: [], closedAt: serverTimestamp(), closedBy: uid });

/** Sole-owner close, exactly as commitExit writes it. */
function closeBatch(uid, cid, { invites = [], deleteMember = true, deleteIndex = true } = {}) {
  const f = as(uid);
  const b = writeBatch(f);
  b.update(doc(f, `companies/${cid}`), closeFields(uid));
  for (const code of invites) b.update(doc(f, `invites/${code}`), { status: 'revoked' });
  if (deleteMember) b.delete(doc(f, `companies/${cid}/members/${uid}`));
  if (deleteIndex) b.delete(doc(f, `users/${uid}/memberships/${cid}`));
  b.delete(doc(f, `user_settings/${uid}`));
  b.delete(doc(f, `users/${uid}`));
  return b.commit();
}

/** Stranger accepts owner invite `code` for `cid` (Members accept flow). */
function acceptOwnerInvite(uid, cid, code) {
  const f = as(uid);
  return runTransaction(f, async (t) => {
    t.set(doc(f, `companies/${cid}/members/${uid}`),
      member(uid, 'owner', { inviteCode: code, invitedBy: 'solo' }));
    t.update(doc(f, `companies/${cid}`), { ownerUids: arrayUnion(uid) });
    t.update(doc(f, `invites/${code}`),
      { status: 'accepted', acceptedBy: uid, acceptedAt: serverTimestamp() });
  });
}

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-nordic-tester-s8',
    firestore: {
      rules: readFileSync(resolve(here, '../firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});
afterAll(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const f = ctx.firestore();
    const seed = async (cid, owners, people) => {
      await setDoc(doc(f, `companies/${cid}`), company(owners, cid));
      for (const [uid, role] of people) {
        await setDoc(doc(f, `companies/${cid}/members/${uid}`), member(uid, role));
        await setDoc(doc(f, `users/${uid}/memberships/${cid}`), membership(cid, role));
        await setDoc(doc(f, `users/${uid}`), { displayName: uid });
        await setDoc(doc(f, `user_settings/${uid}`), { activeCompanyId: cid });
      }
    };
    // DUO: co-owners ravi + asha, collector meena.
    await seed('DUO', ['ravi', 'asha'], [['ravi', 'owner'], ['asha', 'owner'], ['meena', 'collector']]);
    // SOLO: solo is the only owner and the only member.
    await seed('SOLO', ['solo'], [['solo', 'owner']]);
    await setDoc(doc(f, 'companies/SOLO/transactions/t1'), {
      contractId: 'c1', type: 'payment', amountPaise: 350000, recordedBy: 'solo',
      recordedByName: 'Solo', recordedAt: Timestamp.now(), contractActive: true,
    });
    await setDoc(doc(f, 'invites/KQ7W22'), invite('SOLO', 'owner'));
    // TEAM: sole owner boss with collector kumar.
    await seed('TEAM', ['boss'], [['boss', 'owner'], ['kumar', 'collector']]);
  });
});

describe('Tester S8: who may close a company', () => {
  it('T1 a co-owner (non-sole) cannot close, even deleting their own member doc', async () => {
    await assertFails(closeBatch('asha', 'DUO'));
  });
  it('T2 a co-owner cannot strip the other owner from ownerUids without '
      + "updating that owner's member doc [S8-B5 fixed in attempt 2]", async () => {
    await assertFails(updateDoc(doc(as('asha'), 'companies/DUO'), { ownerUids: ['asha'] }));
  });
  it('T2-after (attempt 2): with the strip refused, a co-owner can never close as "sole" owner', async () => {
    await assertFails(updateDoc(doc(as('asha'), 'companies/DUO'), { ownerUids: ['asha'] }));
    await assertFails(closeBatch('asha', 'DUO'));
    await assertSucceeds(getDoc(doc(as('ravi'), 'companies/DUO')));
  });
  it('T3 a collector cannot close (DUO / TEAM)', async () => {
    await assertFails(closeBatch('meena', 'DUO'));
    await assertFails(closeBatch('kumar', 'TEAM'));
  });
  it('T4 a stranger cannot close', async () => {
    await assertFails(closeBatch('mallory', 'SOLO', { deleteMember: false, deleteIndex: false }));
  });
  it('T5 sole owner closes; ledger kept and nobody can read it', async () => {
    await assertSucceeds(closeBatch('solo', 'SOLO', { invites: ['KQ7W22'] }));
    await env.withSecurityRulesDisabled(async (ctx) => {
      const t = await getDoc(doc(ctx.firestore(), 'companies/SOLO/transactions/t1'));
      if (!t.exists() || t.data().recordedByName !== 'Solo') throw new Error('ledger changed');
    });
    await assertFails(getDoc(doc(as('solo'), 'companies/SOLO/transactions/t1')));
  });
});

describe('Tester S8: close must delete own member doc in the same batch', () => {
  it('T6 the company update alone is denied', async () => {
    await assertFails(updateDoc(doc(as('solo'), 'companies/SOLO'), closeFields('solo')));
  });
  it('T7 close + index delete but member kept is denied', async () => {
    await assertFails(closeBatch('solo', 'SOLO', { deleteMember: false }));
  });
  it('T8 the sole owner deleting their member doc alone is denied', async () => {
    await assertFails(deleteDoc(doc(as('solo'), 'companies/SOLO/members/solo')));
  });
  it('T9 a member delete with closedBy=self but ownerUids still set is denied', async () => {
    const f = as('solo');
    const b = writeBatch(f);
    b.update(doc(f, 'companies/SOLO'), { closedAt: serverTimestamp(), closedBy: 'solo' });
    b.delete(doc(f, 'companies/SOLO/members/solo'));
    await assertFails(b.commit());
  });
  it('T10 close without deleting the membership index still succeeds (index is user-owned)', async () => {
    await assertSucceeds(closeBatch('solo', 'SOLO', { deleteIndex: false }));
  });
});

describe("Tester S8: another user's member doc", () => {
  it('T11 a collector cannot delete an owner or another member', async () => {
    await assertFails(deleteDoc(doc(as('meena'), 'companies/DUO/members/asha')));
    await assertFails(deleteDoc(doc(as('meena'), 'companies/DUO/members/ravi')));
  });
  it('T12 a stranger cannot delete any member doc', async () => {
    await assertFails(deleteDoc(doc(as('mallory'), 'companies/DUO/members/meena')));
  });
  it('T13 the close-branch shape cannot delete someone else (closedBy = caller)', async () => {
    const f = as('kumar');
    const b = writeBatch(f);
    b.update(doc(f, 'companies/TEAM'), closeFields('kumar'));
    b.delete(doc(f, 'companies/TEAM/members/boss'));
    await assertFails(b.commit());
  });
  it('T14 a co-owner cannot remove another owner without arrayRemove', async () => {
    await assertFails(deleteDoc(doc(as('asha'), 'companies/DUO/members/ravi')));
  });
  it('T15 the existing remove-member flow still works (owner removes collector)', async () => {
    await assertSucceeds(deleteDoc(doc(as('asha'), 'companies/DUO/members/meena')));
  });
  it('T16 the existing flow: owner removes a co-owner with arrayRemove', async () => {
    const f = as('asha');
    const b = writeBatch(f);
    b.update(doc(f, 'companies/DUO'), { ownerUids: arrayRemove('ravi') });
    b.delete(doc(f, 'companies/DUO/members/ravi'));
    await assertSucceeds(b.commit());
  });
});

describe("Tester S8: a closed company's ownerUids can't be refilled", () => {
  beforeEach(async () => {
    await assertSucceeds(closeBatch('solo', 'SOLO', { invites: ['KQ7W22'] }));
  });
  it('T17 a stranger cannot write ownerUids directly', async () => {
    await assertFails(updateDoc(doc(as('mallory'), 'companies/SOLO'), { ownerUids: ['mallory'] }));
    await assertFails(updateDoc(doc(as('mallory'), 'companies/SOLO'), { ownerUids: arrayUnion('mallory') }));
  });
  it('T18 a stranger cannot overwrite the doc or replay register-company', async () => {
    await assertFails(setDoc(doc(as('mallory'), 'companies/SOLO'),
      { ...company(['mallory'], 'SOLO'), createdBy: 'mallory' }));
    const f = as('mallory');
    const b = writeBatch(f);
    b.set(doc(f, 'companies/SOLO'), { ...company(['mallory'], 'Mine'), createdBy: 'mallory' });
    b.set(doc(f, 'companies/SOLO/members/mallory'), member('mallory', 'owner'));
    await assertFails(b.commit());
  });
  it('T19 the ex-owner (Auth not yet deleted) cannot restore themselves', async () => {
    await assertFails(updateDoc(doc(as('solo'), 'companies/SOLO'), { ownerUids: ['solo'] }));
    await assertFails(setDoc(doc(as('solo'), 'companies/SOLO/members/solo'), member('solo', 'owner')));
  });
  it('T20 the revoked owner invite cannot be accepted', async () => {
    await assertFails(acceptOwnerInvite('mallory', 'SOLO', 'KQ7W22'));
  });
  it('T21 nobody can clear closedAt / closedBy', async () => {
    await assertFails(updateDoc(doc(as('mallory'), 'companies/SOLO'), { closedAt: null, closedBy: null }));
    await assertFails(updateDoc(doc(as('solo'), 'companies/SOLO'), { closedAt: null, closedBy: null }));
  });
});

describe('Tester S8: close without revoking an outstanding owner invite', () => {
  // commitExit revokes the invites it read from the server, but the rules do
  // not require it: an owner invite created after that read (e.g. from a
  // second device) or a client that omits the revoke leaves it pending.
  it('T22 a stranger cannot re-own a closed company via a still-pending owner invite '
      + '[S8-B4 fixed in attempt 2]', async () => {
    await assertSucceeds(closeBatch('solo', 'SOLO', { invites: [] }));
    await assertFails(acceptOwnerInvite('mallory', 'SOLO', 'KQ7W22'));
  });
  it('T22-after (attempt 2): the stranger cannot read the closed ledger either', async () => {
    await assertSucceeds(closeBatch('solo', 'SOLO', { invites: [] }));
    await assertFails(acceptOwnerInvite('mallory', 'SOLO', 'KQ7W22'));
    await assertFails(getDoc(doc(as('mallory'), 'companies/SOLO/transactions/t1')));
  });
});
