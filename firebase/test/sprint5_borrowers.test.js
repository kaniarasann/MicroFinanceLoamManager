// Sprint 5 (Task 10) borrower writes replayed against the rules (emulator only).
// Payloads mirror EXACTLY what lib/features/borrowers/data/borrower_repository.dart
// writes (Borrower.toJson via ModelCodecs.borrower: id excluded, nulls kept,
// createdAt / updatedAt as Timestamps).
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
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

const here = dirname(fileURLToPath(import.meta.url));
const PROJECT_ID = 'demo-nordic';
const CID = 'S5';
const BID = '0b9a7c3e-4d2f-4a1b-9c8d-7e6f5a4b3c2d';

/** @type {import('@firebase/rules-unit-testing').RulesTestEnvironment} */
let env;
const as = (uid) => env.authenticatedContext(uid).firestore();
const path = (id = BID) => `companies/${CID}/borrowers/${id}`;

// BorrowerRepository.createBorrower → Borrower.toJson.
const dartBorrower = (createdBy, over = {}) => ({
  name: 'Anita Sharma',
  nameLower: 'anita sharma',
  phoneE164: '+919845012890',
  locality: 'Anna Nagar',
  notes: null,
  archived: false,
  createdBy,
  createdAt: Timestamp.now(),
  updatedAt: Timestamp.now(),
  schemaVersion: 1,
  ...over,
});
// BorrowerRepository.updateBorrower.
const updatePatch = () => ({
  name: 'Anita S. Rao',
  nameLower: 'anita s. rao',
  phoneE164: '+919900112233',
  locality: null,
  notes: 'Prefers UPI',
  updatedAt: Timestamp.now(),
});
// BorrowerRepository.archiveBorrower.
const archivePatch = () => ({ archived: true, updatedAt: Timestamp.now() });

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
    await setDoc(doc(f, `companies/${CID}`), {
      name: 'Sri Lakshmi Finance', nameLower: 'sri lakshmi finance', city: null, phoneE164: null,
      ownerUids: ['ravi'], nextLoanNo: 0, createdBy: 'ravi', createdAt: Timestamp.now(), schemaVersion: 1,
    });
    for (const [uid, role] of [['ravi', 'owner'], ['meena', 'collector']]) {
      await setDoc(doc(f, `companies/${CID}/members/${uid}`), {
        uid, role, displayName: uid, phoneE164: null, status: 'active', inviteCode: null,
        invitedBy: null, joinedAt: Timestamp.now(), schemaVersion: 1,
      });
    }
    await setDoc(doc(f, path('existing')), dartBorrower('ravi', { name: 'Ravi Kumar', nameLower: 'ravi kumar' }));
  });
});

describe('Sprint 5: createBorrower', () => {
  it('owner: allowed', async () => {
    await assertSucceeds(setDoc(doc(as('ravi'), path()), dartBorrower('ravi')));
  });
  it('owner with all optional fields null: allowed', async () => {
    await assertSucceeds(setDoc(doc(as('ravi'), path()), dartBorrower('ravi', { locality: null })));
  });
  it('owner stamping someone else as createdBy: denied', async () => {
    await assertFails(setDoc(doc(as('ravi'), path()), dartBorrower('meena')));
  });
  it('collector: denied', async () => {
    await assertFails(setDoc(doc(as('meena'), path()), dartBorrower('meena')));
  });
  it('non-member: denied', async () => {
    await assertFails(setDoc(doc(as('stranger'), path()), dartBorrower('stranger')));
  });
});

describe('Sprint 5: updateBorrower', () => {
  it('owner: allowed', async () => {
    await assertSucceeds(updateDoc(doc(as('ravi'), path('existing')), updatePatch()));
  });
  it('owner changing createdAt: denied', async () => {
    await assertFails(updateDoc(doc(as('ravi'), path('existing')), { ...updatePatch(), createdAt: Timestamp.fromMillis(Date.now() + 60_000) }));
  });
  it('collector: denied', async () => {
    await assertFails(updateDoc(doc(as('meena'), path('existing')), updatePatch()));
  });
});

describe('Sprint 5: archiveBorrower (never delete)', () => {
  it('owner archive: allowed', async () => {
    await assertSucceeds(updateDoc(doc(as('ravi'), path('existing')), archivePatch()));
  });
  it('collector archive: denied', async () => {
    await assertFails(updateDoc(doc(as('meena'), path('existing')), archivePatch()));
  });
  it('delete is denied even for the owner', async () => {
    await assertFails(deleteDoc(doc(as('ravi'), path('existing'))));
    await assertFails(deleteDoc(doc(as('meena'), path('existing'))));
  });
});

describe('Sprint 5: reads used by the app', () => {
  it('collector: watchBorrowers query and watchBorrower get', async () => {
    const f = as('meena');
    await assertSucceeds(getDocs(query(
      collection(f, `companies/${CID}/borrowers`),
      where('archived', '==', false),
      orderBy('nameLower'),
    )));
    await assertSucceeds(getDoc(doc(f, path('existing'))));
  });
  it('collector: borrower history queries (contracts / transactions)', async () => {
    const f = as('meena');
    await assertSucceeds(getDocs(query(
      collection(f, `companies/${CID}/contracts`),
      where('borrowerId', '==', 'existing'),
      where('status', 'in', ['closed', 'rolledOver']),
    )));
    await assertSucceeds(getDocs(query(
      collection(f, `companies/${CID}/transactions`),
      where('borrowerId', '==', 'existing'),
      where('contractActive', '==', false),
    )));
  });
  it('non-member: list denied', async () => {
    await assertFails(getDocs(collection(as('stranger'), `companies/${CID}/borrowers`)));
  });
});
