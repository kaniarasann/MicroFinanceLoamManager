// Tester adversarial rules tests (Sprint 3). Emulator only; project demo-nordic.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';
import {
  assertFails, assertSucceeds, initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp, collection, deleteDoc, doc, getDoc, getDocs, serverTimestamp, setDoc, updateDoc,
} from 'firebase/firestore';

const here = dirname(fileURLToPath(import.meta.url));
let env;
const now = () => Timestamp.now();
const inDays = (d) => Timestamp.fromMillis(Date.now() + d * 86400000);
const carol = () => env.authenticatedContext('carol').firestore();
const eve = () => env.authenticatedContext('eve').firestore();
const anon = () => env.unauthenticatedContext().firestore();

const company = (name, owners) => ({
  name, nameLower: name.toLowerCase(), city: 'Chennai', ownerUids: owners,
  nextLoanNo: 5, createdBy: owners[0], createdAt: now(), schemaVersion: 1,
});
const member = (uid, role) => ({
  uid, role, displayName: uid, status: 'active', joinedAt: now(), schemaVersion: 1,
});
const contract = (by, over = {}) => ({
  borrowerId: 'b1', borrowerName: 'Ravi', borrowerPhoneE164: '+919800000001', loanNo: 5,
  status: 'active', sanctionedPaise: 1000000, upfrontMode: 'percent', upfrontInput: 700,
  upfrontPaise: 70000, netDisbursedPaise: 930000, frequency: 'weekly', preferredWeekday: 1,
  installmentPaise: 100000, baseInstallmentCount: 10, firstDueDate: '2026-11-23',
  disbursedOn: '2026-11-16', totalPaidPaise: 200000, createdBy: by, createdAt: now(),
  updatedAt: now(), schemaVersion: 1, ...over,
});
const tx = {
  contractId: 'c1', borrowerId: 'b1', borrowerName: 'Ravi', loanNo: 5, contractActive: true,
  type: 'payment', amountPaise: 100000, paidOn: '2026-11-21', mode: 'cash',
  recordedBy: 'carol', recordedByName: 'carol', recordedAt: now(),
  clientRecordedAt: now(), deviceId: 'dev-1', schemaVersion: 1,
};
const invite = {
  companyId: 'A', companyName: 'Alpha', role: 'collector', inviteeName: 'Eve',
  inviteePhoneE164: '+919800000009', createdBy: 'alice', createdByName: 'alice',
  createdAt: now(), expiresAt: inDays(7), status: 'pending', acceptedBy: null,
  acceptedAt: null, schemaVersion: 1,
};

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-nordic',
    firestore: {
      rules: readFileSync(resolve(here, '../firestore.rules'), 'utf8'),
      host: '127.0.0.1', port: 8080,
    },
  });
});
afterAll(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const f = ctx.firestore();
    const put = (p, d) => setDoc(doc(f, p), d);
    await Promise.all([
      put('companies/A', company('Alpha', ['alice'])),
      put('companies/A/members/alice', member('alice', 'owner')),
      put('companies/A/members/carol', member('carol', 'collector')),
      put('companies/B', company('Beta', ['bob'])),
      put('companies/B/members/bob', member('bob', 'owner')),
      put('companies/A/contracts/c1', contract('alice')),
      put('companies/B/contracts/cb1', contract('bob')),
      put('companies/A/transactions/t1', tx),
      put('invites/ABCDEF', invite),
    ]);
  });
});

describe('tester: tenant isolation', () => {
  it('collector of A cannot get B contract by guessed id', async () => {
    await assertFails(getDoc(doc(carol(), 'companies/B/contracts/cb1')));
  });
  it('collector of A cannot list B contracts', async () => {
    await assertFails(getDocs(collection(carol(), 'companies/B/contracts')));
  });
  it('control: collector of A can get own company contract', async () => {
    await assertSucceeds(getDoc(doc(carol(), 'companies/A/contracts/c1')));
  });
});

describe('tester: collector write restrictions', () => {
  it('collector cannot delete a transaction', async () => {
    await assertFails(deleteDoc(doc(carol(), 'companies/A/transactions/t1')));
  });
  it('collector cannot set contract status to rolledOver', async () => {
    await assertFails(updateDoc(doc(carol(), 'companies/A/contracts/c1'),
      { status: 'rolledOver', updatedAt: serverTimestamp() }));
  });
  it('collector cannot decrease totalPaidPaise', async () => {
    await assertFails(updateDoc(doc(carol(), 'companies/A/contracts/c1'),
      { totalPaidPaise: 100000, updatedAt: serverTimestamp() }));
  });
  it('collector cannot set totalPaidPaise to a non-integer', async () => {
    await assertFails(updateDoc(doc(carol(), 'companies/A/contracts/c1'),
      { totalPaidPaise: 300000.5, updatedAt: serverTimestamp() }));
  });
  it('control: collector can increase totalPaidPaise', async () => {
    await assertSucceeds(updateDoc(doc(carol(), 'companies/A/contracts/c1'),
      { totalPaidPaise: 300000, updatedAt: serverTimestamp() }));
  });
});

describe('tester: invites', () => {
  it('signed-in non-member can get an invite by exact code', async () => {
    await assertSucceeds(getDoc(doc(eve(), 'invites/ABCDEF')));
  });
  it('signed-in user cannot list invites', async () => {
    await assertFails(getDocs(collection(eve(), 'invites')));
  });
  it('signed-out user cannot get an invite', async () => {
    await assertFails(getDoc(doc(anon(), 'invites/ABCDEF')));
  });
  it('signed-out user cannot read contracts', async () => {
    await assertFails(getDoc(doc(anon(), 'companies/A/contracts/c1')));
  });
});
