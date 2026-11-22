// Firestore security rules tests (emulator only; project demo-nordic).
// Run: `npm test` from firebase/ (wraps `firebase emulators:exec`).
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
  increment,
  query,
  where,
  arrayUnion,
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

// Actors. alice = owner of A, carol + dave = collectors of A, bob = owner of B.
const ROLES = ['owner', 'collector', 'otherCompany', 'signedOut'];
const UID = { owner: 'alice', collector: 'carol', otherCompany: 'bob', signedOut: 'anon' };

function db(role) {
  return role === 'signedOut'
    ? env.unauthenticatedContext().firestore()
    : env.authenticatedContext(UID[role]).firestore();
}
const as = {
  alice: () => env.authenticatedContext('alice').firestore(),
  carol: () => env.authenticatedContext('carol').firestore(),
  bob: () => env.authenticatedContext('bob').firestore(),
  eve: () => env.authenticatedContext('eve').firestore(),
  anon: () => env.unauthenticatedContext().firestore(),
};

const now = () => Timestamp.now();
const inDays = (d) => Timestamp.fromMillis(Date.now() + d * 86400000);

// ---------------------------------------------------------------- fixtures

const company = (name, owners) => ({
  name, nameLower: name.toLowerCase(), city: 'Chennai', ownerUids: owners,
  nextLoanNo: 5, createdBy: owners[0], createdAt: now(), schemaVersion: 1,
});
const memberDoc = (uid, role, extra = {}) => ({
  uid, role, displayName: uid, status: 'active', joinedAt: now(), schemaVersion: 1, ...extra,
});
const membershipDoc = (cid, role) => ({
  companyId: cid, companyName: cid, role, joinedAt: now(), schemaVersion: 1,
});
const borrower = (by = 'alice') => ({
  name: 'Ravi', nameLower: 'ravi', phoneE164: '+919800000001', archived: false,
  createdBy: by, createdAt: now(), updatedAt: now(), schemaVersion: 1,
});
const contract = (by = 'alice', over = {}) => ({
  borrowerId: 'b1', borrowerName: 'Ravi', borrowerPhoneE164: '+919800000001', loanNo: 5,
  status: 'active', sanctionedPaise: 1000000, upfrontMode: 'percent', upfrontInput: 700,
  upfrontPaise: 70000, netDisbursedPaise: 930000, frequency: 'weekly', preferredWeekday: 1,
  installmentPaise: 100000, baseInstallmentCount: 10, firstDueDate: '2026-11-23',
  disbursedOn: '2026-11-16', totalPaidPaise: 0, createdBy: by, createdAt: now(),
  updatedAt: now(), schemaVersion: 1, ...over,
});
const installment = (by = 'alice', over = {}) => ({
  contractId: 'c1', borrowerId: 'b1', borrowerName: 'Ravi', loanNo: 5, contractActive: true,
  seq: 1, kind: 'base', dueDate: '2026-11-23', amountDuePaise: 100000, rescheduledOutPaise: 0,
  rescheduledToIds: [], createdBy: by, createdAt: now(), schemaVersion: 1, ...over,
});
const tx = (by, over = {}) => ({
  contractId: 'c1', borrowerId: 'b1', borrowerName: 'Ravi', loanNo: 5, contractActive: true,
  type: 'payment', amountPaise: 100000, paidOn: '2026-11-21', mode: 'cash',
  recordedBy: by, recordedByName: by, recordedAt: serverTimestamp(),
  clientRecordedAt: now(), deviceId: 'dev-1', schemaVersion: 1, ...over,
});
const invite = (over = {}) => ({
  companyId: 'A', companyName: 'Alpha', role: 'collector', inviteeName: 'Eve',
  inviteePhoneE164: '+919800000009', createdBy: 'alice', createdByName: 'alice',
  createdAt: now(), expiresAt: inDays(7), status: 'pending', acceptedBy: null,
  acceptedAt: null, schemaVersion: 1, ...over,
});

async function seed() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const f = ctx.firestore();
    const put = (p, d) => setDoc(doc(f, p), d);
    // For seeding, recordedAt must be a concrete timestamp.
    const seededTx = (over) => ({ ...tx('alice', over), recordedAt: now() });
    await Promise.all([
      put('companies/A', company('Alpha', ['alice'])),
      put('companies/A/members/alice', memberDoc('alice', 'owner')),
      put('companies/A/members/carol', memberDoc('carol', 'collector')),
      put('companies/A/members/dave', memberDoc('dave', 'collector')),
      put('companies/B', company('Beta', ['bob'])),
      put('companies/B/members/bob', memberDoc('bob', 'owner')),
      put('users/alice', { displayName: 'alice', email: 'a@x.in', createdAt: now() }),
      put('users/alice/memberships/A', membershipDoc('A', 'owner')),
      put('users/carol/memberships/A', membershipDoc('A', 'collector')),
      put('users/dave/memberships/A', membershipDoc('A', 'collector')),
      put('users/bob/memberships/B', membershipDoc('B', 'owner')),
      put('user_settings/alice', { activeCompanyId: 'A', autoLockMinutes: 1, updatedAt: now() }),
      put('companies/A/borrowers/b1', borrower()),
      put('companies/A/contracts/c1', contract()),
      put('companies/A/installments/i1', installment()),
      put('companies/A/installments/i2', installment('alice', { seq: 2, dueDate: '2026-11-30' })),
      put('companies/A/transactions/d1', seededTx({ type: 'disbursement', amountPaise: 930000, paidOn: '2026-11-16' })),
      put('companies/A/transactions/t1', seededTx({})),
      put('companies/B/borrowers/bb1', borrower('bob')),
      put('invites/ABCDEF', invite()),
      put('invites/EXPRED', invite({ expiresAt: inDays(-1) })),
      put('invites/OWNRQQ', invite({ role: 'owner' })),
      put('invites/REVKED', invite({ status: 'revoked' })),
    ]);
  });
}

async function rulesOff(fn) {
  await env.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));
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
  await seed();
});

// ---------------------------------------------------------------- matrix
// Each op: (f, role) => Promise. `allow` lists the roles expected to succeed.

const A = 'companies/A';
const MATRIX = {
  'companies/{cid}': {
    get: { allow: ['owner', 'collector'], run: (f) => getDoc(doc(f, A)) },
    list: { allow: [], run: (f) => getDocs(collection(f, 'companies')) },
    create: { allow: [], run: (f, r) => setDoc(doc(f, 'companies/NEW'), company('New', [UID[r]])) },
    update: { allow: ['owner'], run: (f) => updateDoc(doc(f, A), { name: 'Alpha Finance' }) },
    delete: { allow: [], run: (f) => deleteDoc(doc(f, A)) },
  },
  'companies/{cid}/members': {
    get: { allow: ['owner', 'collector'], run: (f) => getDoc(doc(f, `${A}/members/dave`)) },
    list: { allow: ['owner', 'collector'], run: (f) => getDocs(collection(f, `${A}/members`)) },
    create: { allow: ['owner'], run: (f) => setDoc(doc(f, `${A}/members/zed`), memberDoc('zed', 'collector')) },
    update: { allow: ['owner'], run: (f) => updateDoc(doc(f, `${A}/members/dave`), { displayName: 'Dave K' }) },
    delete: { allow: ['owner'], run: (f) => deleteDoc(doc(f, `${A}/members/dave`)) },
  },
  'companies/{cid}/borrowers': {
    get: { allow: ['owner', 'collector'], run: (f) => getDoc(doc(f, `${A}/borrowers/b1`)) },
    list: { allow: ['owner', 'collector'], run: (f) => getDocs(collection(f, `${A}/borrowers`)) },
    create: { allow: ['owner'], run: (f, r) => setDoc(doc(f, `${A}/borrowers/b2`), borrower(UID[r])) },
    update: { allow: ['owner'], run: (f) => updateDoc(doc(f, `${A}/borrowers/b1`), { locality: 'Adyar', updatedAt: now() }) },
    delete: { allow: [], run: (f) => deleteDoc(doc(f, `${A}/borrowers/b1`)) },
  },
  'companies/{cid}/contracts': {
    get: { allow: ['owner', 'collector'], run: (f) => getDoc(doc(f, `${A}/contracts/c1`)) },
    list: { allow: ['owner', 'collector'], run: (f) => getDocs(collection(f, `${A}/contracts`)) },
    create: { allow: ['owner'], run: (f, r) => setDoc(doc(f, `${A}/contracts/c2`), contract(UID[r])) },
    update: { allow: ['owner'], run: (f) => updateDoc(doc(f, `${A}/contracts/c1`), { purpose: 'shop', updatedAt: now() }) },
    delete: { allow: [], run: (f) => deleteDoc(doc(f, `${A}/contracts/c1`)) },
  },
  'companies/{cid}/installments': {
    get: { allow: ['owner', 'collector'], run: (f) => getDoc(doc(f, `${A}/installments/i1`)) },
    list: { allow: ['owner', 'collector'], run: (f) => getDocs(collection(f, `${A}/installments`)) },
    create: { allow: ['owner'], run: (f, r) => setDoc(doc(f, `${A}/installments/i9`), installment(UID[r], { seq: 9 })) },
    update: { allow: ['owner', 'collector'], run: (f) => updateDoc(doc(f, `${A}/installments/i1`), { contractActive: false }) },
    delete: { allow: [], run: (f) => deleteDoc(doc(f, `${A}/installments/i1`)) },
  },
  'companies/{cid}/transactions': {
    get: { allow: ['owner', 'collector'], run: (f) => getDoc(doc(f, `${A}/transactions/t1`)) },
    list: { allow: ['owner', 'collector'], run: (f) => getDocs(collection(f, `${A}/transactions`)) },
    create: { allow: ['owner', 'collector'], run: (f, r) => setDoc(doc(f, `${A}/transactions/t9`), tx(UID[r])) },
    update: { allow: ['owner', 'collector'], run: (f) => updateDoc(doc(f, `${A}/transactions/t1`), { contractActive: false }) },
    delete: { allow: [], run: (f) => deleteDoc(doc(f, `${A}/transactions/t1`)) },
  },
  'invites/{code}': {
    get: { allow: ['owner', 'collector', 'otherCompany'], run: (f) => getDoc(doc(f, 'invites/ABCDEF')) },
    list: { allow: [], run: (f) => getDocs(collection(f, 'invites')) },
    create: { allow: ['owner'], run: (f, r) => setDoc(doc(f, 'invites/QRSTUV'), invite({ createdBy: UID[r] })) },
    update: { allow: ['owner'], run: (f) => updateDoc(doc(f, 'invites/ABCDEF'), { status: 'revoked' }) },
    delete: { allow: [], run: (f) => deleteDoc(doc(f, 'invites/ABCDEF')) },
  },
  // Per-user docs: the "owner" actor (alice) is the subject; everyone else is a stranger.
  'users/{uid}': {
    get: { allow: ['owner'], run: (f) => getDoc(doc(f, 'users/alice')) },
    list: { allow: [], run: (f) => getDocs(collection(f, 'users')) },
    create: { allow: ['owner'], prep: (f) => deleteDoc(doc(f, 'users/alice')), run: (f) => setDoc(doc(f, 'users/alice'), { displayName: 'alice', email: 'a@x.in', createdAt: now() }) },
    update: { allow: ['owner'], run: (f) => updateDoc(doc(f, 'users/alice'), { phoneE164: '+919800000000' }) },
    delete: { allow: ['owner'], run: (f) => deleteDoc(doc(f, 'users/alice')) },
  },
  'user_settings/{uid}': {
    get: { allow: ['owner'], run: (f) => getDoc(doc(f, 'user_settings/alice')) },
    list: { allow: [], run: (f) => getDocs(collection(f, 'user_settings')) },
    create: { allow: ['owner'], prep: (f) => deleteDoc(doc(f, 'user_settings/alice')), run: (f) => setDoc(doc(f, 'user_settings/alice'), { activeCompanyId: 'A', autoLockMinutes: 1, updatedAt: now() }) },
    update: { allow: ['owner'], run: (f) => updateDoc(doc(f, 'user_settings/alice'), { autoLockMinutes: 5 }) },
    delete: { allow: ['owner'], run: (f) => deleteDoc(doc(f, 'user_settings/alice')) },
  },
  // Each actor targets users/{self}/memberships/A for get/list/create; update + delete target carol's.
  'users/{uid}/memberships/{cid}': {
    get: { allow: ['owner', 'collector'], run: (f, r) => getDoc(doc(f, `users/${UID[r] === 'bob' ? 'carol' : UID[r]}/memberships/A`)) },
    list: { allow: ['owner', 'collector', 'otherCompany'], run: (f, r) => getDocs(collection(f, `users/${UID[r]}/memberships`)) },
    create: {
      allow: ['owner', 'collector'],
      prep: (f) => Promise.all([deleteDoc(doc(f, 'users/alice/memberships/A')), deleteDoc(doc(f, 'users/carol/memberships/A'))]),
      run: (f, r) => setDoc(doc(f, `users/${UID[r]}/memberships/A`), membershipDoc('A', r === 'owner' ? 'owner' : 'collector')),
    },
    update: { allow: ['owner'], run: (f) => updateDoc(doc(f, 'users/carol/memberships/A'), { companyName: 'Alpha Finance' }) },
    delete: { allow: ['owner', 'collector'], run: (f) => deleteDoc(doc(f, 'users/carol/memberships/A')) },
  },
};

describe('collection x role matrix', () => {
  for (const [path, ops] of Object.entries(MATRIX)) {
    describe(path, () => {
      for (const [op, spec] of Object.entries(ops)) {
        for (const role of ROLES) {
          const ok = spec.allow.includes(role);
          it(`${op} by ${role} -> ${ok ? 'allowed' : 'denied'}`, async () => {
            if (spec.prep) await rulesOff(spec.prep);
            const p = spec.run(db(role), role);
            await (ok ? assertSucceeds(p) : assertFails(p));
          });
        }
      }
    });
  }
});

// ---------------------------------------------------------------- write paths

describe('register company batch', () => {
  const registerBatch = (f, uid, cid, companyOver = {}) => {
    const b = writeBatch(f);
    b.set(doc(f, `companies/${cid}`), { ...company('Gamma', [uid]), ...companyOver });
    b.set(doc(f, `companies/${cid}/members/${uid}`), memberDoc(uid, 'owner'));
    b.set(doc(f, `users/${uid}/memberships/${cid}`), membershipDoc(cid, 'owner'));
    b.set(doc(f, `user_settings/${uid}`), { activeCompanyId: cid, autoLockMinutes: 1, updatedAt: now() });
    return b.commit();
  };

  it('allows a signed-in user to register a company with themselves as sole owner', async () => {
    await assertSucceeds(registerBatch(as.eve(), 'eve', 'G'));
  });
  it('denies company create without the owner member doc in the batch', async () => {
    await assertFails(setDoc(doc(as.eve(), 'companies/G'), company('Gamma', ['eve'])));
  });
  it('denies registering with extra ownerUids', async () => {
    await assertFails(registerBatch(as.eve(), 'eve', 'G', { ownerUids: ['eve', 'mallory'] }));
  });
  it('denies registering on top of an existing company id', async () => {
    await assertFails(registerBatch(as.eve(), 'eve', 'A'));
  });
  it('denies a signed-out register', async () => {
    await assertFails(registerBatch(as.anon(), 'anon', 'G'));
  });
});

describe('create contract batch (owner)', () => {
  const contractBatch = (f, by, over = {}) => {
    const b = writeBatch(f);
    b.set(doc(f, `${A}/contracts/c2`), contract(by, over));
    for (let i = 1; i <= 3; i++) {
      b.set(doc(f, `${A}/installments/c2-${i}`), installment(by, { contractId: 'c2', seq: i }));
    }
    b.set(doc(f, `${A}/transactions/c2-d`), tx(by, { contractId: 'c2', type: 'disbursement', amountPaise: 930000 }));
    b.update(doc(f, A), { nextLoanNo: increment(1) });
    return b.commit();
  };

  it('allows owner: contract + installments + disbursement + nextLoanNo increment', async () => {
    await assertSucceeds(contractBatch(as.alice(), 'alice'));
  });
  it('denies the same batch by a collector', async () => {
    await assertFails(contractBatch(as.carol(), 'carol'));
  });
  it('denies upfront >= sanctioned', async () => {
    await assertFails(setDoc(doc(as.alice(), `${A}/contracts/c3`), contract('alice', { upfrontPaise: 1000000, netDisbursedPaise: 0 })));
  });
  it('denies non-integer money', async () => {
    await assertFails(setDoc(doc(as.alice(), `${A}/contracts/c3`), contract('alice', { sanctionedPaise: 1000000.5 })));
  });
  it('denies sanctioned == 0', async () => {
    await assertFails(setDoc(doc(as.alice(), `${A}/contracts/c3`), contract('alice', { sanctionedPaise: 0, upfrontPaise: 0, netDisbursedPaise: 0 })));
  });
  it('denies netDisbursed != sanctioned - upfront on a non-rollover contract', async () => {
    await assertFails(setDoc(doc(as.alice(), `${A}/contracts/c3`), contract('alice', { netDisbursedPaise: 900000 })));
  });
  it('allows a smaller net on a rollover contract', async () => {
    await assertSucceeds(setDoc(doc(as.alice(), `${A}/contracts/c3`), contract('alice', { netDisbursedPaise: 500000, rolledOverFromContractId: 'c1' })));
  });
});

describe('record payment batch (collector)', () => {
  it('allows transaction create + contract totalPaidPaise increment', async () => {
    const f = as.carol();
    const b = writeBatch(f);
    b.set(doc(f, `${A}/transactions/p1`), tx('carol'));
    b.update(doc(f, `${A}/contracts/c1`), { totalPaidPaise: increment(100000), lastPaymentOn: '2026-11-21', updatedAt: serverTimestamp() });
    await assertSucceeds(b.commit());
  });
  it('allows the closing variant (status closed + contractActive false flags)', async () => {
    const f = as.carol();
    const b = writeBatch(f);
    b.set(doc(f, `${A}/transactions/p1`), tx('carol', { amountPaise: 1000000 }));
    b.update(doc(f, `${A}/contracts/c1`), { totalPaidPaise: increment(1000000), lastPaymentOn: '2026-11-21', updatedAt: serverTimestamp(), status: 'closed', closedAt: serverTimestamp() });
    b.update(doc(f, `${A}/installments/i1`), { contractActive: false });
    b.update(doc(f, `${A}/installments/i2`), { contractActive: false });
    b.update(doc(f, `${A}/transactions/t1`), { contractActive: false });
    b.update(doc(f, `${A}/transactions/d1`), { contractActive: false });
    await assertSucceeds(b.commit());
  });
  it('denies a payment stamped with another uid', async () => {
    await assertFails(setDoc(doc(as.carol(), `${A}/transactions/p1`), tx('alice')));
  });
  it('denies a payment with a client recordedAt instead of serverTimestamp', async () => {
    await assertFails(setDoc(doc(as.carol(), `${A}/transactions/p1`), tx('carol', { recordedAt: now() })));
  });
  it('denies a negative or fractional amount', async () => {
    await assertFails(setDoc(doc(as.carol(), `${A}/transactions/p1`), tx('carol', { amountPaise: -5 })));
    await assertFails(setDoc(doc(as.carol(), `${A}/transactions/p2`), tx('carol', { amountPaise: 10.5 })));
  });
  it('denies a collector decreasing totalPaidPaise', async () => {
    await rulesOff((f) => updateDoc(doc(f, `${A}/contracts/c1`), { totalPaidPaise: 200000 }));
    await assertFails(updateDoc(doc(as.carol(), `${A}/contracts/c1`), { totalPaidPaise: increment(-100000) }));
  });
  it('denies a collector setting status rolledOver', async () => {
    await assertFails(updateDoc(doc(as.carol(), `${A}/contracts/c1`), { status: 'rolledOver' }));
  });
});

describe('collector restrictions', () => {
  it('denies a reversal transaction by a collector', async () => {
    await assertFails(setDoc(doc(as.carol(), `${A}/transactions/r1`), tx('carol', { type: 'reversal', reversesTxId: 't1' })));
  });
  it('denies rolloverSettlement and disbursement by a collector', async () => {
    await assertFails(setDoc(doc(as.carol(), `${A}/transactions/r1`), tx('carol', { type: 'rolloverSettlement' })));
    await assertFails(setDoc(doc(as.carol(), `${A}/transactions/r2`), tx('carol', { type: 'disbursement' })));
  });
  it('denies a collector editing sanctionedPaise', async () => {
    await assertFails(updateDoc(doc(as.carol(), `${A}/contracts/c1`), { sanctionedPaise: 2000000 }));
  });
  it('denies a collector creating a base installment', async () => {
    await assertFails(setDoc(doc(as.carol(), `${A}/installments/i9`), installment('carol', { seq: 9 })));
  });
  it('denies a collector creating an invite', async () => {
    await assertFails(setDoc(doc(as.carol(), 'invites/QRSTUV'), invite({ createdBy: 'carol' })));
  });
  it('denies a collector changing a member role', async () => {
    await assertFails(updateDoc(doc(as.carol(), `${A}/members/carol`), { role: 'owner' }));
  });
  it('allows a collector reschedule batch', async () => {
    const f = as.carol();
    const b = writeBatch(f);
    b.update(doc(f, `${A}/installments/i1`), { rescheduledOutPaise: increment(40000), rescheduledToIds: arrayUnion('i3') });
    b.set(doc(f, `${A}/installments/i3`), installment('carol', { seq: 11, kind: 'rescheduled', rescheduledFromId: 'i1', dueDate: '2026-12-02', amountDuePaise: 40000 }));
    b.set(doc(f, `${A}/transactions/rs1`), tx('carol', { type: 'reschedule', amountPaise: 0, rescheduleInfo: { fromId: 'i1', toId: 'i3' } }));
    await assertSucceeds(b.commit());
  });
  it('denies rescheduling out more than the installment amount', async () => {
    await assertFails(updateDoc(doc(as.carol(), `${A}/installments/i1`), { rescheduledOutPaise: 100001 }));
  });
  it('denies a collector changing an installment amountDuePaise', async () => {
    await assertFails(updateDoc(doc(as.carol(), `${A}/installments/i1`), { amountDuePaise: 1 }));
  });
});

describe('owner reversal', () => {
  it('allows reversal tx + totalPaidPaise decrement', async () => {
    await rulesOff((f) => updateDoc(doc(f, `${A}/contracts/c1`), { totalPaidPaise: 100000 }));
    const f = as.alice();
    const b = writeBatch(f);
    b.set(doc(f, `${A}/transactions/r1`), tx('alice', { type: 'reversal', reversesTxId: 't1' }));
    b.update(doc(f, `${A}/contracts/c1`), { totalPaidPaise: increment(-100000), updatedAt: serverTimestamp() });
    await assertSucceeds(b.commit());
  });
});

describe('transaction immutability', () => {
  for (const who of ['alice', 'carol']) {
    it(`denies amount update by ${who}`, async () => {
      await assertFails(updateDoc(doc(as[who](), `${A}/transactions/t1`), { amountPaise: 1 }));
    });
    it(`denies type update by ${who}`, async () => {
      await assertFails(updateDoc(doc(as[who](), `${A}/transactions/t1`), { type: 'reversal' }));
    });
    it(`denies delete by ${who}`, async () => {
      await assertFails(deleteDoc(doc(as[who](), `${A}/transactions/t1`)));
    });
  }
  it('allows only the contractActive flag to change', async () => {
    await assertSucceeds(updateDoc(doc(as.carol(), `${A}/transactions/t1`), { contractActive: false }));
  });
});

describe('invite accept (runTransaction by invitee)', () => {
  const accept = (f, uid, code, role = 'collector', cid = 'A', withCompany = false) =>
    runTransaction(f, async (t) => {
      const inv = await t.get(doc(f, `invites/${code}`));
      if (!inv.exists()) throw new Error('missing invite');
      t.set(doc(f, `companies/${cid}/members/${uid}`), memberDoc(uid, role, { inviteCode: code, invitedBy: 'alice' }));
      t.set(doc(f, `users/${uid}/memberships/${cid}`), membershipDoc(cid, role));
      t.update(doc(f, `invites/${code}`), { status: 'accepted', acceptedBy: uid, acceptedAt: serverTimestamp() });
      if (withCompany) t.update(doc(f, `companies/${cid}`), { ownerUids: arrayUnion(uid) });
    });

  it('allows accepting a pending, unexpired invite', async () => {
    await assertSucceeds(accept(as.eve(), 'eve', 'ABCDEF'));
    // ...and the new collector can now read the company.
    await assertSucceeds(getDoc(doc(as.eve(), A)));
  });
  it('denies an expired invite', async () => {
    await assertFails(accept(as.eve(), 'eve', 'EXPRED'));
  });
  it('denies a revoked invite', async () => {
    await assertFails(accept(as.eve(), 'eve', 'REVKED'));
  });
  it('denies claiming a different role than the invite', async () => {
    await assertFails(accept(as.eve(), 'eve', 'ABCDEF', 'owner', 'A', true));
  });
  it('denies using the invite for another company', async () => {
    await assertFails(accept(as.eve(), 'eve', 'ABCDEF', 'collector', 'B'));
  });
  it('denies a member doc carrying unknown keys', async () => {
    await assertFails(setDoc(doc(as.alice(), `${A}/members/zed`), memberDoc('zed', 'collector', { isAdmin: true })));
  });
  it('denies creating a member doc without the invite update', async () => {
    await assertFails(setDoc(doc(as.eve(), `${A}/members/eve`), memberDoc('eve', 'collector', { inviteCode: 'ABCDEF' })));
  });
  it('denies accepting an invite without creating the member doc', async () => {
    await assertFails(updateDoc(doc(as.eve(), 'invites/ABCDEF'), { status: 'accepted', acceptedBy: 'eve', acceptedAt: serverTimestamp() }));
  });
  it('allows accepting an owner invite (adds self to ownerUids)', async () => {
    await assertSucceeds(accept(as.eve(), 'eve', 'OWNRQQ', 'owner', 'A', true));
  });
  it('denies an owner invite accept that skips ownerUids', async () => {
    await assertFails(accept(as.eve(), 'eve', 'OWNRQQ', 'owner', 'A', false));
  });
  it('allows only the owner a companyId-scoped invite query', async () => {
    await assertSucceeds(getDocs(query(collection(as.alice(), 'invites'), where('companyId', '==', 'A'))));
    await assertFails(getDocs(query(collection(as.carol(), 'invites'), where('companyId', '==', 'A'))));
    await assertFails(getDocs(query(collection(as.bob(), 'invites'), where('companyId', '==', 'A'))));
    await assertFails(getDocs(query(collection(as.eve(), 'invites'), where('companyId', '==', 'A'))));
  });
  it('denies unconstrained listing of invites (even for the owner)', async () => {
    await assertFails(getDocs(collection(as.alice(), 'invites')));
    await assertFails(getDocs(collection(as.eve(), 'invites')));
  });
  it('denies a signed-out invite get', async () => {
    await assertFails(getDoc(doc(as.anon(), 'invites/ABCDEF')));
  });
  it('denies the owner of another company revoking an invite', async () => {
    await assertFails(updateDoc(doc(as.bob(), 'invites/ABCDEF'), { status: 'revoked' }));
  });
});

describe('last-owner guard and member removal', () => {
  it('denies the sole owner demoting themselves (with ownerUids emptied)', async () => {
    const f = as.alice();
    const b = writeBatch(f);
    b.update(doc(f, `${A}/members/alice`), { role: 'collector' });
    b.update(doc(f, A), { ownerUids: [] });
    await assertFails(b.commit());
  });
  it('denies the sole owner demoting themselves (member doc only)', async () => {
    await assertFails(updateDoc(doc(as.alice(), `${A}/members/alice`), { role: 'collector' }));
  });
  it('denies the sole owner deleting their own member doc', async () => {
    await assertFails(deleteDoc(doc(as.alice(), `${A}/members/alice`)));
  });
  it('denies emptying ownerUids on the company', async () => {
    await assertFails(updateDoc(doc(as.alice(), A), { ownerUids: [] }));
  });
  it('allows owner removing a collector (member + membership delete)', async () => {
    const f = as.alice();
    const b = writeBatch(f);
    b.delete(doc(f, `${A}/members/carol`));
    b.delete(doc(f, 'users/carol/memberships/A'));
    await assertSucceeds(b.commit());
    await assertFails(getDoc(doc(as.carol(), `${A}/contracts/c1`)));
  });
  it('allows promoting a collector to owner with ownerUids arrayUnion', async () => {
    const f = as.alice();
    const b = writeBatch(f);
    b.update(doc(f, `${A}/members/carol`), { role: 'owner' });
    b.update(doc(f, A), { ownerUids: arrayUnion('carol') });
    b.update(doc(f, 'users/carol/memberships/A'), { role: 'owner' });
    await assertSucceeds(b.commit());
  });
  it('allows demoting one of two owners', async () => {
    await rulesOff(async (f) => {
      await updateDoc(doc(f, A), { ownerUids: ['alice', 'carol'] });
      await updateDoc(doc(f, `${A}/members/carol`), { role: 'owner' });
    });
    const f = as.alice();
    const b = writeBatch(f);
    b.update(doc(f, `${A}/members/carol`), { role: 'collector' });
    b.update(doc(f, A), { ownerUids: ['alice'] });
    await assertSucceeds(b.commit());
  });
  it('allows a collector leaving (own member doc + membership)', async () => {
    const f = as.carol();
    const b = writeBatch(f);
    b.delete(doc(f, `${A}/members/carol`));
    b.delete(doc(f, 'users/carol/memberships/A'));
    await assertSucceeds(b.commit());
  });
});

describe('tenant isolation', () => {
  it('denies an owner of B reading or writing anything in A', async () => {
    const f = as.bob();
    await assertFails(getDoc(doc(f, `${A}/borrowers/b1`)));
    await assertFails(setDoc(doc(f, `${A}/borrowers/x`), borrower('bob')));
    await assertFails(setDoc(doc(f, `${A}/transactions/x`), tx('bob')));
  });
  it('denies an owner of A reading B', async () => {
    await assertFails(getDoc(doc(as.alice(), 'companies/B/borrowers/bb1')));
  });
  it('denies unknown top-level collections', async () => {
    await assertFails(getDoc(doc(as.alice(), 'secrets/x')));
    await assertFails(setDoc(doc(as.alice(), 'secrets/x'), { a: 1 }));
  });
});
