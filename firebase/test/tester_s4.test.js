// Tester — Sprint 4 adversarial rules checks (emulator only, demo-nordic).
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  Timestamp, collection, doc, getDoc, getDocs, query, runTransaction,
  serverTimestamp, setDoc, where, writeBatch,
} from 'firebase/firestore';

const here = dirname(fileURLToPath(import.meta.url));
let env;
const as = (uid) => env.authenticatedContext(uid).firestore();
const inDays = (d) => Timestamp.fromMillis(Date.now() + d * 86400000);

const company = (owner, name) => ({
  name, nameLower: name.toLowerCase(), city: null, phoneE164: null, ownerUids: [owner],
  nextLoanNo: 0, createdBy: owner, createdAt: Timestamp.now(), schemaVersion: 1,
});
const member = (uid, role, extra = {}) => ({
  uid, role, displayName: uid, phoneE164: null, status: 'active', inviteCode: null,
  invitedBy: null, joinedAt: Timestamp.now(), schemaVersion: 1, ...extra,
});
const membership = (cid, role) => ({
  companyId: cid, companyName: cid, role, joinedAt: Timestamp.now(), schemaVersion: 1,
});
const invite = (cid, over = {}) => ({
  companyId: cid, companyName: cid, companyCity: null, role: 'collector',
  inviteeName: 'Meena', inviteePhoneE164: '+919845012891', createdBy: 'ownA',
  createdByName: 'Owner A', createdAt: Timestamp.now(), expiresAt: inDays(7),
  status: 'pending', acceptedBy: null, acceptedAt: null, schemaVersion: 1, ...over,
});
const invitesOf = (f, cid) => query(collection(f, 'invites'), where('companyId', '==', cid), where('status', '==', 'pending'));

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-nordic',
    firestore: { rules: readFileSync(resolve(here, '../firestore.rules'), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
afterAll(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const f = ctx.firestore();
    await setDoc(doc(f, 'companies/A'), company('ownA', 'Company A'));
    await setDoc(doc(f, 'companies/A/members/ownA'), member('ownA', 'owner'));
    await setDoc(doc(f, 'companies/A/members/colA'), member('colA', 'collector'));
    await setDoc(doc(f, 'users/colA/memberships/A'), membership('A', 'collector'));
    await setDoc(doc(f, 'companies/B'), company('ownB', 'Company B'));
    await setDoc(doc(f, 'companies/B/members/ownB'), member('ownB', 'owner'));
    await setDoc(doc(f, 'invites/AAAA22'), invite('A'));
    await setDoc(doc(f, 'invites/BBBB22'), invite('B', { createdBy: 'ownB' }));
  });
});

describe('Tester S4: invite listing', () => {
  it('owner of A can list A invites (control)', async () => {
    await assertSucceeds(getDocs(invitesOf(as('ownA'), 'A')));
  });
  it('collector of A cannot list A invites', async () => {
    await assertFails(getDocs(invitesOf(as('colA'), 'A')));
  });
  it('owner of A cannot list B invites', async () => {
    await assertFails(getDocs(invitesOf(as('ownA'), 'B')));
  });
  it('owner listing without a companyId filter is denied', async () => {
    await assertFails(getDocs(query(collection(as('ownA'), 'invites'), where('status', '==', 'pending'))));
    await assertFails(getDocs(collection(as('ownA'), 'invites')));
  });
  it('owner listing with companyId "in" [A, B] is denied', async () => {
    await assertFails(getDocs(query(collection(as('ownA'), 'invites'), where('companyId', 'in', ['A', 'B']))));
  });
});

/** Accept transaction with an overridable member role. */
const accept = (f, uid, code, memberRole) => runTransaction(f, async (t) => {
  const inv = (await t.get(doc(f, `invites/${code}`))).data();
  t.set(doc(f, `companies/${inv.companyId}/members/${uid}`), member(uid, memberRole, { inviteCode: code, invitedBy: inv.createdBy }));
  t.set(doc(f, `users/${uid}/memberships/${inv.companyId}`), membership(inv.companyId, memberRole));
  t.update(doc(f, `invites/${code}`), { status: 'accepted', acceptedBy: uid, acceptedAt: serverTimestamp() });
});

describe('Tester S4: accept role integrity', () => {
  it('collector invite accepted as collector succeeds (control)', async () => {
    await assertSucceeds(accept(as('meena'), 'meena', 'AAAA22', 'collector'));
  });
  it('collector invite accepted with role owner is denied', async () => {
    await assertFails(accept(as('meena'), 'meena', 'AAAA22', 'owner'));
  });
  it('member doc without the invite (no inviteCode) cannot self-join', async () => {
    await assertFails(setDoc(doc(as('eve'), 'companies/A/members/eve'), member('eve', 'collector')));
  });
});

describe('Tester S4: removed member', () => {
  it('after owner removes colA, colA cannot read company, members or invites', async () => {
    await assertSucceeds(getDoc(doc(as('colA'), 'companies/A')));
    const fo = as('ownA');
    const b = writeBatch(fo);
    b.delete(doc(fo, 'companies/A/members/colA'));
    b.delete(doc(fo, 'users/colA/memberships/A'));
    await assertSucceeds(b.commit());
    await assertFails(getDoc(doc(as('colA'), 'companies/A')));
    await assertFails(getDocs(collection(as('colA'), 'companies/A/members')));
    await assertFails(getDoc(doc(as('colA'), 'companies/A/members/ownA')));
  });
  it('removed member cannot re-add themselves', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const { deleteDoc } = await import('firebase/firestore');
      await deleteDoc(doc(ctx.firestore(), 'companies/A/members/colA'));
    });
    await assertFails(setDoc(doc(as('colA'), 'companies/A/members/colA'), member('colA', 'collector')));
  });
});
