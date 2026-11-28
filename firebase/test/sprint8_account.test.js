// Sprint 8: account deletion replayed against the rules (emulator only).
// Payloads mirror EXACTLY what AccountRepository.commitExit writes
// (lib/features/settings/data/account_repository.dart):
//   leave        → delete members/{uid} + users/{uid}/memberships/{cid}
//   leaveOwner   → + companies/{cid}.ownerUids arrayRemove(uid)
//   close        → companies/{cid} {ownerUids: [], closedAt: serverTimestamp,
//                  closedBy: uid} + revoke pending invites + member/membership
//   always       → delete user_settings/{uid} and users/{uid}
// Ledger records (transactions, contracts, …) are never touched.
// Run: `npm test` from firebase/.
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
const PROJECT_ID = 'demo-nordic';

/** @type {import('@firebase/rules-unit-testing').RulesTestEnvironment} */
let env;
const as = (uid) => env.authenticatedContext(uid).firestore();
const inDays = (d) => Timestamp.fromMillis(Date.now() + d * 86400000);

const company = (owners, name = 'Sri Lakshmi Finance') => ({
  name, nameLower: name.toLowerCase(), city: null, phoneE164: null,
  ownerUids: owners, nextLoanNo: 3, createdBy: owners[0] ?? 'ravi',
  createdAt: Timestamp.now(), schemaVersion: 1,
});
const member = (uid, role) => ({
  uid, role, displayName: uid, phoneE164: null, status: 'active',
  inviteCode: null, invitedBy: null, joinedAt: Timestamp.now(), schemaVersion: 1,
});
const membership = (cid, role) => ({
  companyId: cid, companyName: 'Sri Lakshmi Finance', role,
  joinedAt: Timestamp.now(), schemaVersion: 1,
});
const invite = (cid, over = {}) => ({
  companyId: cid, companyName: 'Solo Finance', companyCity: null,
  role: 'collector', inviteeName: 'Meena', inviteePhoneE164: '+919845012891',
  createdBy: 'solo', createdByName: 'Solo', createdAt: Timestamp.now(),
  expiresAt: inDays(7), status: 'pending', acceptedBy: null, acceptedAt: null,
  schemaVersion: 1, ...over,
});

/** Mirrors AccountRepository.commitExit. */
function exitBatch(uid, exits) {
  const f = as(uid);
  const b = writeBatch(f);
  for (const e of exits) {
    const m = doc(f, `companies/${e.cid}/members/${uid}`);
    const ms = doc(f, `users/${uid}/memberships/${e.cid}`);
    if (e.action === 'leave') {
      b.delete(m); b.delete(ms);
    } else if (e.action === 'leaveOwner') {
      b.update(doc(f, `companies/${e.cid}`), { ownerUids: arrayRemove(uid) });
      b.delete(m); b.delete(ms);
    } else if (e.action === 'close') {
      b.update(doc(f, `companies/${e.cid}`), {
        ownerUids: [], closedAt: serverTimestamp(), closedBy: e.closedBy ?? uid,
        ...(e.extra ?? {}),
      });
      for (const code of e.invites ?? []) {
        b.update(doc(f, `invites/${code}`), { status: 'revoked' });
      }
      if (!e.keepMember) b.delete(m);
      b.delete(ms);
    } else if (e.action === 'stale') {
      b.delete(ms);
    }
  }
  b.delete(doc(f, `user_settings/${uid}`));
  b.delete(doc(f, `users/${uid}`));
  return b.commit();
}

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
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
    // S8: owners ravi + asha, collector meena.
    await setDoc(doc(f, 'companies/S8'), company(['ravi', 'asha']));
    for (const [uid, role] of [['ravi', 'owner'], ['asha', 'owner'], ['meena', 'collector']]) {
      await setDoc(doc(f, `companies/S8/members/${uid}`), member(uid, role));
      await setDoc(doc(f, `users/${uid}/memberships/S8`), membership('S8', role));
      await setDoc(doc(f, `users/${uid}`), { displayName: uid, email: `${uid}@x.in`, createdAt: Timestamp.now() });
      await setDoc(doc(f, `user_settings/${uid}`), { activeCompanyId: 'S8', schemaVersion: 1 });
    }
    // A payment meena recorded: must survive her deletion.
    await setDoc(doc(f, 'companies/S8/transactions/t1'), {
      contractId: 'c1', type: 'payment', amountPaise: 350000, recordedBy: 'meena',
      recordedByName: 'Meena', recordedAt: Timestamp.now(), contractActive: true,
    });
    // SOLO: solo is the only owner and only member; one pending invite.
    await setDoc(doc(f, 'companies/SOLO'), company(['solo'], 'Solo Finance'));
    await setDoc(doc(f, 'companies/SOLO/members/solo'), member('solo', 'owner'));
    await setDoc(doc(f, 'users/solo/memberships/SOLO'), membership('SOLO', 'owner'));
    await setDoc(doc(f, 'users/solo'), { displayName: 'Solo', email: 's@x.in', createdAt: Timestamp.now() });
    await setDoc(doc(f, 'user_settings/solo'), { activeCompanyId: 'SOLO', schemaVersion: 1 });
    await setDoc(doc(f, 'invites/SOLO22'), invite('SOLO'));
    await setDoc(doc(f, 'companies/SOLO/transactions/t2'), {
      contractId: 'c2', type: 'payment', amountPaise: 100000, recordedBy: 'solo',
      recordedByName: 'Solo', recordedAt: Timestamp.now(), contractActive: true,
    });
    // TEAM: sole owner boss with a collector.
    await setDoc(doc(f, 'companies/TEAM'), company(['boss'], 'Team Finance'));
    await setDoc(doc(f, 'companies/TEAM/members/boss'), member('boss', 'owner'));
    await setDoc(doc(f, 'companies/TEAM/members/kumar'), member('kumar', 'collector'));
    await setDoc(doc(f, 'users/boss/memberships/TEAM'), membership('TEAM', 'owner'));
  });
});

describe('Sprint 8: delete account, leaving', () => {
  it('collector: member + membership + user_settings + users in one batch', async () => {
    await assertSucceeds(exitBatch('meena', [{ cid: 'S8', action: 'leave' }]));
    await env.withSecurityRulesDisabled(async (ctx) => {
      const t = await getDoc(doc(ctx.firestore(), 'companies/S8/transactions/t1'));
      if (!t.exists() || t.data().recordedByName !== 'Meena') throw new Error('ledger record lost');
    });
    await assertFails(getDoc(doc(as('meena'), 'companies/S8')));
  });
  it('one of two owners: arrayRemove + member + membership', async () => {
    await assertSucceeds(exitBatch('asha', [{ cid: 'S8', action: 'leaveOwner' }]));
    await env.withSecurityRulesDisabled(async (ctx) => {
      const c = await getDoc(doc(ctx.firestore(), 'companies/S8'));
      if (JSON.stringify(c.data().ownerUids) !== '["ravi"]') throw new Error('ownerUids');
    });
  });
  it('an owner leaving WITHOUT the arrayRemove is denied', async () => {
    await assertFails(exitBatch('asha', [{ cid: 'S8', action: 'leave' }]));
  });
  it('a stale membership index doc can be deleted alone', async () => {
    await assertSucceeds(exitBatch('boss', [{ cid: 'GONE', action: 'stale' }, { cid: 'TEAM', action: 'stale' }]));
  });
  it("another user's user_settings / users / membership cannot be deleted", async () => {
    await assertFails(deleteDoc(doc(as('ravi'), 'user_settings/meena')));
    await assertFails(deleteDoc(doc(as('ravi'), 'users/meena')));
  });
  it('ledger records can never be deleted along the way', async () => {
    await assertFails(deleteDoc(doc(as('meena'), 'companies/S8/transactions/t1')));
    const f = as('meena');
    const b = writeBatch(f);
    b.delete(doc(f, 'companies/S8/members/meena'));
    b.delete(doc(f, 'companies/S8/transactions/t1'));
    await assertFails(b.commit());
  });
});

describe('Sprint 8: delete account, sole owner', () => {
  it('only member: closing the company in the same batch succeeds', async () => {
    await assertSucceeds(exitBatch('solo', [{ cid: 'SOLO', action: 'close', invites: ['SOLO22'] }]));
    await env.withSecurityRulesDisabled(async (ctx) => {
      const f = ctx.firestore();
      const c = (await getDoc(doc(f, 'companies/SOLO'))).data();
      if (c.ownerUids.length !== 0 || c.closedBy !== 'solo' || !c.closedAt) throw new Error('not closed');
      if (!(await getDoc(doc(f, 'companies/SOLO/transactions/t2'))).exists()) throw new Error('ledger lost');
      if ((await getDoc(doc(f, 'invites/SOLO22'))).data().status !== 'revoked') throw new Error('invite');
    });
    // Nobody can open it any more.
    await assertFails(getDoc(doc(as('solo'), 'companies/SOLO')));
    await assertFails(getDoc(doc(as('solo'), 'companies/SOLO/transactions/t2')));
  });
  it('the revoked invite can no longer be accepted', async () => {
    await assertSucceeds(exitBatch('solo', [{ cid: 'SOLO', action: 'close', invites: ['SOLO22'] }]));
    const fm = as('meena');
    await assertFails(runTransaction(fm, async (t) => {
      t.set(doc(fm, 'companies/SOLO/members/meena'), { ...member('meena', 'collector'), inviteCode: 'SOLO22', invitedBy: 'solo' });
      t.update(doc(fm, 'invites/SOLO22'), { status: 'accepted', acceptedBy: 'meena', acceptedAt: serverTimestamp() });
    }));
  });
  it('sole owner leaving without closing is denied (last-owner guard)', async () => {
    await assertFails(exitBatch('solo', [{ cid: 'SOLO', action: 'leave' }]));
    await assertFails(exitBatch('solo', [{ cid: 'SOLO', action: 'leaveOwner' }]));
  });
  it('closing while keeping the member doc is denied', async () => {
    await assertFails(exitBatch('solo', [{ cid: 'SOLO', action: 'close', keepMember: true }]));
  });
  it('closedBy must be the caller', async () => {
    await assertFails(exitBatch('solo', [{ cid: 'SOLO', action: 'close', closedBy: 'someone' }]));
  });
  it('closedAt must be the server time', async () => {
    await assertFails(exitBatch('solo', [{ cid: 'SOLO', action: 'close', extra: { closedAt: Timestamp.now() } }]));
  });
  it('closing cannot change other company fields', async () => {
    await assertFails(exitBatch('solo', [{ cid: 'SOLO', action: 'close', extra: { name: 'Renamed' } }]));
  });
  it('one of several owners cannot close the company', async () => {
    await assertFails(exitBatch('asha', [{ cid: 'S8', action: 'close' }]));
  });
  it('a collector cannot close the company', async () => {
    await assertFails(exitBatch('meena', [{ cid: 'S8', action: 'close' }]));
  });
  it('a non-member cannot close the company', async () => {
    const f = as('mallory');
    await assertFails(updateDoc(doc(f, 'companies/SOLO'), {
      ownerUids: [], closedAt: serverTimestamp(), closedBy: 'mallory',
    }));
  });
  it('a sole owner cannot empty ownerUids without leaving (no close flag)', async () => {
    await assertFails(updateDoc(doc(as('solo'), 'companies/SOLO'), { ownerUids: [] }));
  });
  it('a sole owner WITH a collector: the client blocks; if a close lands anyway the company is inert (F5)', async () => {
    // The rules cannot count members; the client refuses (ExitAction.blocked).
    // Should a close land anyway, the remaining collector can neither read
    // nor write the closed company (attempt 2).
    await assertSucceeds(exitBatch('boss', [{ cid: 'TEAM', action: 'close' }]));
    await assertFails(getDoc(doc(as('kumar'), 'companies/TEAM')));
    await assertFails(getDoc(doc(as('kumar'), 'companies/TEAM/members/kumar')));
    await assertFails(setDoc(doc(as('kumar'), 'companies/TEAM/transactions/tk'), {
      contractId: 'c1', type: 'payment', amountPaise: 100, recordedBy: 'kumar',
      recordedByName: 'Kumar', recordedAt: serverTimestamp(), contractActive: true,
    }));
    await assertFails(updateDoc(doc(as('kumar'), 'companies/TEAM/members/kumar'), { displayName: 'K' }));
    // …and nobody can ever regain ownership of a closed company.
    await assertFails(updateDoc(doc(as('kumar'), 'companies/TEAM'), { ownerUids: ['kumar'] }));
  });
  it('closed fields can only be set by the close branch, never edited by an owner', async () => {
    await assertFails(updateDoc(doc(as('ravi'), 'companies/S8'), { closedAt: serverTimestamp(), closedBy: 'ravi' }));
  });
});

describe('Sprint 8 attempt 2: ownerUids and member roles never diverge (S8-B5)', () => {
  it('stripping a co-owner from ownerUids alone is denied', async () => {
    await assertFails(updateDoc(doc(as('asha'), 'companies/S8'), { ownerUids: ['asha'] }));
  });
  it('demote (member role → collector + arrayRemove) in one batch still works', async () => {
    const f = as('asha');
    const b = writeBatch(f);
    b.update(doc(f, 'companies/S8/members/ravi'), { role: 'collector' });
    b.update(doc(f, 'companies/S8'), { ownerUids: arrayRemove('ravi') });
    b.update(doc(f, 'users/ravi/memberships/S8'), { role: 'collector' });
    await assertSucceeds(b.commit());
  });
  it('removing an owner (member delete + arrayRemove) in one batch still works', async () => {
    const f = as('asha');
    const b = writeBatch(f);
    b.delete(doc(f, 'companies/S8/members/ravi'));
    b.update(doc(f, 'companies/S8'), { ownerUids: arrayRemove('ravi') });
    b.delete(doc(f, 'users/ravi/memberships/S8'));
    await assertSucceeds(b.commit());
  });
  it('removing two owners in one write is denied', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const f = ctx.firestore();
      await setDoc(doc(f, 'companies/S8'), company(['ravi', 'asha', 'meena']));
    });
    const f = as('meena');
    const b = writeBatch(f);
    b.delete(doc(f, 'companies/S8/members/ravi'));
    b.delete(doc(f, 'companies/S8/members/asha'));
    b.update(doc(f, 'companies/S8'), { ownerUids: ['meena'] });
    await assertFails(b.commit());
  });
});
