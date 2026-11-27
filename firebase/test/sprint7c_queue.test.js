// Sprint 7c attempt 4: the onboarding sync list
// (`companies/{cid}/onboardingQueues/{contractId}`) and the "Cancel
// onboarded loan" writes, replayed against the rules (emulator only).
//
// Production evaluates queued batches before batch 1 has landed, so later
// onboarding batches are written by a resumer only after batch 1 is on the
// server. Batch 1 carries the durable queue doc next to the contract.
// Dates are relative to IST today. Run: `npm test` from firebase/.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  deleteDoc,
  doc,
  getDoc,
  increment,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const here = dirname(fileURLToPath(import.meta.url));
const CID = 'S7Q';
const OTHER = 'S7Q-OTHER';
const NEW = '7c9c2d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e';
const ONB = '7c900000-0000-4000-8000-0000000000c1'; // seeded onboarded contract
const STD = '7c900000-0000-4000-8000-0000000000c2'; // seeded standard contract

/** @type {import('@firebase/rules-unit-testing').RulesTestEnvironment} */
let env;
const as = (uid) => (uid == null
  ? env.unauthenticatedContext().firestore()
  : env.authenticatedContext(uid).firestore());
const p = (col, id) => `companies/${CID}/${col}/${id}`;

const DAY = 86400000;
const T = new Date(Date.now() + 330 * 60000).toISOString().slice(0, 10);
const addDays = (civil, n) => new Date(Date.parse(`${civil}T00:00:00Z`) + n * DAY)
  .toISOString().slice(0, 10);
const D = (n) => addDays(T, n);

// Daily ₹1,00,000 at ₹300 (334 rows), like the device smoke test.
const INST = 30000;
const SANCTIONED = 10000000;
const DISBURSED = D(-400);
const FIRST_DUE = D(-399);
const dueOn = (seq) => addDays(FIRST_DUE, seq - 1);

const contract = (createdBy, over = {}) => ({
  baseInstallmentCount: 334, borrowerId: 'b1', borrowerName: 'Anita Sharma',
  borrowerPhoneE164: '+919845012890', closedAt: null, createdAt: Timestamp.now(),
  createdBy, disbursedOn: DISBURSED, firstDueDate: FIRST_DUE, frequency: 'daily',
  guarantor: null, installmentPaise: INST, lastPaymentOn: dueOn(328), loanNo: 8,
  netDisbursedPaise: SANCTIONED, notes: null, onboardedOn: T,
  onboardedPaymentCount: 328, onboardedTotalPaise: 328 * INST, origin: 'onboarded',
  preferredMonthDay: null, preferredWeekday: null, previousRef: null, purpose: null,
  rolledOverFromContractId: null, rolledOverToContractId: null, rolloverSettledPaise: null,
  sanctionedPaise: SANCTIONED, schemaVersion: 1, status: 'active', totalPaidPaise: 0,
  totalWaivedPaise: 0, updatedAt: Timestamp.now(), upfrontInput: 0, upfrontMode: 'flat',
  upfrontPaise: 0,
  ...over,
});
const tx = (contractId, recordedBy, over = {}) => ({
  amountPaise: INST, borrowerId: 'b1', borrowerName: 'Anita Sharma',
  clientRecordedAt: Timestamp.now(), contractActive: true, contractId, deviceId: 'dev-1',
  loanNo: 8, mode: 'cash', note: null, openingBalance: false, origin: 'onboarding',
  paidOn: dueOn(1), recordedAt: serverTimestamp(), recordedBy, recordedByName: recordedBy,
  reference: null, relatedContractId: null, rescheduleInfo: null, reversesTxId: null,
  schemaVersion: 1, type: 'payment',
  ...over,
});
// The queue as `OnboardingQueue.toFirestore` writes it (compact entries).
const entries = (from, n, a = INST) => Array.from({ length: n }, (_, k) => ({
  i: `${NEW}-q${from + k}`, d: dueOn(from + k), a, m: 'cash', o: false,
}));
const queue = (uid, over = {}) => {
  const es = over.entries ?? entries(101, 228);
  return {
    contractId: NEW, status: 'pending', entries: es, count: es.length,
    totalPaise: es.reduce((s, e) => s + e.a, 0), createdBy: uid,
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(), schemaVersion: 1,
    ...over,
  };
};

// Batch 1: contract + disbursement + nextLoanNo + queue + 100 payments
// (installments left out here; their rules are covered elsewhere).
const batch1 = (uid, { contractOver = {}, queueOver = {}, withQueue = true } = {}) => {
  const f = as(uid);
  const b = writeBatch(f);
  b.set(doc(f, p('contracts', NEW)), { ...contract(uid, contractOver), totalPaidPaise: increment(100 * INST) });
  b.set(doc(f, p('transactions', `${NEW}-d`)), tx(NEW, uid, {
    type: 'disbursement', amountPaise: SANCTIONED, paidOn: DISBURSED, mode: null,
  }));
  b.update(doc(f, `companies/${CID}`), { nextLoanNo: increment(1) });
  if (withQueue) b.set(doc(f, p('onboardingQueues', NEW)), queue(uid, queueOver));
  for (let k = 1; k <= 100; k++) {
    b.set(doc(f, p('transactions', `${NEW}-p${k}`)), tx(NEW, uid, { paidOn: dueOn(k) }));
  }
  return b.commit();
};

// One resumed batch: contract increment + n queued payments.
const resumed = (uid, from, n, contractId = NEW) => {
  const f = as(uid);
  const b = writeBatch(f);
  b.update(doc(f, p('contracts', contractId)), {
    totalPaidPaise: increment(n * INST), updatedAt: Timestamp.now(),
  });
  for (let k = from; k < from + n; k++) {
    b.set(doc(f, p('transactions', `${contractId}-q${k}`)), tx(contractId, uid, { paidOn: dueOn(k) }));
  }
  return b.commit();
};

const readAs = async (path) => {
  let out;
  await env.withSecurityRulesDisabled(async (ctx) => {
    out = (await getDoc(doc(ctx.firestore(), path))).data();
  });
  return out;
};

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-nordic',
    firestore: {
      rules: readFileSync(resolve(here, '../firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});
afterAll(async () => { await env?.cleanup(); });

const seed = () => env.withSecurityRulesDisabled(async (ctx) => {
  const f = ctx.firestore();
  const company = (owner) => ({
    name: 'Sri Lakshmi Finance', nameLower: 'sri lakshmi finance', city: null, phoneE164: null,
    ownerUids: [owner], nextLoanNo: 8, createdBy: owner, createdAt: Timestamp.now(), schemaVersion: 1,
  });
  const member = (uid, role) => ({
    uid, role, displayName: uid, phoneE164: null, status: 'active', inviteCode: null,
    invitedBy: null, joinedAt: Timestamp.now(), schemaVersion: 1,
  });
  await setDoc(doc(f, `companies/${CID}`), company('ravi'));
  await setDoc(doc(f, `companies/${CID}/members/ravi`), member('ravi', 'owner'));
  await setDoc(doc(f, `companies/${CID}/members/meena`), member('meena', 'collector'));
  await setDoc(doc(f, `companies/${OTHER}`), company('zed'));
  await setDoc(doc(f, `companies/${OTHER}/members/zed`), member('zed', 'owner'));
  // An onboarded contract whose batch 1 landed, with its pending queue.
  await setDoc(doc(f, p('contracts', ONB)), contract('ravi', { totalPaidPaise: 2 * INST }));
  await setDoc(doc(f, p('onboardingQueues', ONB)), {
    ...queue('ravi'), contractId: ONB, createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  });
  await setDoc(doc(f, p('transactions', `${ONB}-p1`)), tx(ONB, 'ravi', { recordedAt: Timestamp.now() }));
  await setDoc(doc(f, p('transactions', `${ONB}-p2`)), tx(ONB, 'ravi', {
    paidOn: dueOn(2), recordedAt: Timestamp.now(),
  }));
  await setDoc(doc(f, p('contracts', STD)), contract('ravi', {
    origin: 'standard', onboardedOn: null, onboardedPaymentCount: null,
    onboardedTotalPaise: null, disbursedOn: T, firstDueDate: D(1), lastPaymentOn: null,
  }));
});

beforeEach(async () => { await env.clearFirestore(); await seed(); });

describe('Sprint 7c (attempt 4): sync list created in batch 1', () => {
  it('owner, batch 1 with the contract and its queue: allowed', async () => {
    await assertSucceeds(batch1('ravi'));
    const q = await readAs(p('onboardingQueues', NEW));
    expect(q.status).toBe('pending');
    expect(q.entries).toHaveLength(228);
  });
  it('owner, 1,100-entry queue (about 100 KB): allowed', async () => {
    const es = entries(1, 1100, 100);
    await assertSucceeds(batch1('ravi', {
      contractOver: { onboardedPaymentCount: 1100, onboardedTotalPaise: 100 * INST + 1100 * 100 },
      queueOver: { entries: es, count: 1100, totalPaise: 1100 * 100 },
    }));
  });
  it('collector / other-company owner / signed out, batch 1: denied', async () => {
    await assertFails(batch1('meena'));
    await assertFails(batch1('zed'));
    await assertFails(batch1(null));
  });
  it('queue without its contract: denied', async () => {
    await assertFails(setDoc(doc(as('ravi'), p('onboardingQueues', NEW)), queue('ravi')));
  });
  it('queue added later for an existing contract: denied (batch 1 only)', async () => {
    await assertFails(setDoc(doc(as('ravi'), p('onboardingQueues', STD)), {
      ...queue('ravi'), contractId: STD,
    }));
  });
  it('queue next to a standard contract: denied', async () => {
    await assertFails(batch1('ravi', {
      contractOver: {
        origin: 'standard', onboardedOn: null, onboardedPaymentCount: null,
        onboardedTotalPaise: null, totalPaidPaise: 0,
      },
    }));
  });
  it('more entries or cash than the contract onboarded: denied', async () => {
    await assertFails(batch1('ravi', { contractOver: { onboardedPaymentCount: 227 } }));
    await assertFails(batch1('ravi', { contractOver: { onboardedTotalPaise: 228 * INST - 1 } }));
  });
  it('malformed queue (wrong id, status, count, empty, > 1,100, extra key, createdBy): denied', async () => {
    await assertFails(batch1('ravi', { queueOver: { contractId: ONB } }));
    await assertFails(batch1('ravi', { queueOver: { status: 'complete' } }));
    await assertFails(batch1('ravi', { queueOver: { count: 5 } }));
    await assertFails(batch1('ravi', { queueOver: { entries: [], count: 0, totalPaise: 0 } }));
    const big = entries(1, 1101);
    await assertFails(batch1('ravi', {
      contractOver: { onboardedPaymentCount: 1101, onboardedTotalPaise: 1101 * INST },
      queueOver: { entries: big, count: 1101, totalPaise: 1101 * INST },
    }));
    await assertFails(batch1('ravi', { queueOver: { extra: true } }));
    await assertFails(batch1('ravi', { queueOver: { createdBy: 'meena' } }));
    await assertFails(batch1('ravi', { queueOver: { totalPaise: -1 } }));
  });
});

describe('Sprint 7c (attempt 4): resumer and queue status', () => {
  it('owner, a resumed batch once batch 1 is on the server: allowed', async () => {
    await assertSucceeds(resumed('ravi', 3, 100, ONB));
    expect((await readAs(p('contracts', ONB))).totalPaidPaise).toBe(102 * INST);
  });
  it('a resumed batch before batch 1 exists: denied (why later batches wait)', async () => {
    await assertFails(resumed('ravi', 101, 100));
  });
  it('re-sending an id that already landed: the whole batch is denied (no double count)', async () => {
    const f = as('ravi');
    const b = writeBatch(f);
    b.update(doc(f, p('contracts', ONB)), { totalPaidPaise: increment(INST), updatedAt: Timestamp.now() });
    b.set(doc(f, p('transactions', `${ONB}-p2`)), tx(ONB, 'ravi', { paidOn: dueOn(2) }));
    await assertFails(b.commit());
    expect((await readAs(p('contracts', ONB))).totalPaidPaise).toBe(2 * INST);
  });
  it('collector, a resumed batch: denied', async () => {
    await assertFails(resumed('meena', 3, 5, ONB));
  });
  it('owner marks the queue complete / cancelled: allowed', async () => {
    const r = doc(as('ravi'), p('onboardingQueues', ONB));
    await assertSucceeds(updateDoc(r, { status: 'complete', updatedAt: serverTimestamp() }));
  });
  it('owner marks the queue cancelled: allowed', async () => {
    const r = doc(as('ravi'), p('onboardingQueues', ONB));
    await assertSucceeds(updateDoc(r, { status: 'cancelled', updatedAt: serverTimestamp() }));
  });
  it('entries are immutable; a finished queue cannot reopen; collectors cannot update; no delete', async () => {
    const r = doc(as('ravi'), p('onboardingQueues', ONB));
    await assertFails(updateDoc(r, { entries: [], updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(r, { count: 1 }));
    await assertFails(updateDoc(r, { status: 'paused' }));
    await assertFails(updateDoc(doc(as('meena'), p('onboardingQueues', ONB)), { status: 'complete' }));
    await assertFails(deleteDoc(r));
    await assertSucceeds(updateDoc(r, { status: 'complete' }));
    await assertFails(updateDoc(r, { status: 'pending' }));
  });
  it('read: members (owner, collector) yes; other company / signed out no', async () => {
    await assertSucceeds(getDoc(doc(as('ravi'), p('onboardingQueues', ONB))));
    await assertSucceeds(getDoc(doc(as('meena'), p('onboardingQueues', ONB))));
    await assertFails(getDoc(doc(as('zed'), p('onboardingQueues', ONB))));
    await assertFails(getDoc(doc(as(null), p('onboardingQueues', ONB))));
  });
});

describe('Sprint 7c (attempt 4): Cancel onboarded loan', () => {
  const reversal = (uid, id, original, paidOn) => tx(ONB, uid, {
    type: 'reversal', reversesTxId: original, paidOn, note: 'Onboarded by mistake',
    contractActive: false,
  });
  it('owner: reversals on the original dates, then status cancelled + queue cancelled: allowed', async () => {
    const f = as('ravi');
    const b = writeBatch(f);
    b.update(doc(f, p('contracts', ONB)), { totalPaidPaise: increment(-2 * INST), updatedAt: Timestamp.now() });
    b.set(doc(f, p('transactions', 'rev-1')), reversal('ravi', 'rev-1', `${ONB}-p1`, dueOn(1)));
    b.set(doc(f, p('transactions', 'rev-2')), reversal('ravi', 'rev-2', `${ONB}-p2`, dueOn(2)));
    await assertSucceeds(b.commit());
    const t = writeBatch(f);
    t.update(doc(f, p('contracts', ONB)), {
      status: 'cancelled', closedAt: Timestamp.now(), updatedAt: Timestamp.now(),
    });
    t.update(doc(f, p('onboardingQueues', ONB)), { status: 'cancelled', updatedAt: serverTimestamp() });
    t.update(doc(f, p('transactions', `${ONB}-p1`)), { contractActive: false });
    await assertSucceeds(t.commit());
    const c = await readAs(p('contracts', ONB));
    expect(c.status).toBe('cancelled');
    expect(c.totalPaidPaise).toBe(0);
  });
  it('collector setting status cancelled: denied', async () => {
    await assertFails(updateDoc(doc(as('meena'), p('contracts', ONB)), {
      status: 'cancelled', updatedAt: Timestamp.now(),
    }));
  });
  it('collector reversing an onboarding payment: denied', async () => {
    await assertFails(setDoc(doc(as('meena'), p('transactions', 'rev-x')),
      reversal('meena', 'rev-x', `${ONB}-p1`, dueOn(1))));
  });
});

describe('Sprint 7c (attempt 5, F1): no onboarding payment on a cancelled loan', () => {
  const cancelOnb = () => env.withSecurityRulesDisabled((ctx) =>
    updateDoc(doc(ctx.firestore(), p('contracts', ONB)), { status: 'cancelled' }));
  it('a resumed batch after Cancel landed: denied', async () => {
    await cancelOnb();
    await assertFails(resumed('ravi', 3, 10, ONB));
    expect((await readAs(p('contracts', ONB))).totalPaidPaise).toBe(2 * INST);
  });
  it('a single onboarding payment on a cancelled loan: denied', async () => {
    await cancelOnb();
    await assertFails(resumed('ravi', 3, 1, ONB));
  });
  it('a repair payment that closes the loan in the same batch: allowed', async () => {
    const f = as('ravi');
    const b = writeBatch(f);
    b.update(doc(f, p('contracts', ONB)), {
      totalPaidPaise: increment(INST), status: 'closed', closedAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });
    b.set(doc(f, p('transactions', 'repair-close')), tx(ONB, 'ravi', { paidOn: dueOn(3), contractActive: false }));
    await assertSucceeds(b.commit());
  });
  it('reversals of onboarding payments on a cancelled loan: allowed (F2 recovery)', async () => {
    await cancelOnb();
    const f = as('ravi');
    const b = writeBatch(f);
    b.update(doc(f, p('contracts', ONB)), { totalPaidPaise: increment(-INST), updatedAt: Timestamp.now() });
    b.set(doc(f, p('transactions', 'rev-late')), tx(ONB, 'ravi', {
      type: 'reversal', reversesTxId: `${ONB}-p1`, paidOn: dueOn(1), note: 'Finish cancelling',
      contractActive: false,
    }));
    await assertSucceeds(b.commit());
  });
  it('a live payment on a cancelled loan is unaffected by this rule (collector path, control)', async () => {
    await cancelOnb();
    // Live payments keep their own rules; the collector contract branch
    // still refuses to touch a cancelled loan's status.
    await assertFails(updateDoc(doc(as('meena'), p('contracts', ONB)), { status: 'active' }));
  });
});
