// Sprint 7c onboarding rules delta, replayed against the rules (emulator only).
// - M2: an onboarded contract carries the immutable `onboardedPaymentCount`
//   and `onboardedTotalPaise` (ints ≥ 0, total < sanctioned, chunk-1 paid ≤
//   total, count ≤ 1,100); standard contracts carry neither (absent or null).
//   The owner's "Add missing onboarding payment" repair goes through the
//   existing `onboardingTx` rule.
// - M1: installments are spill ops, so with a small batch limit they can land
//   in a batch that holds no contract op. Their rule needs only an owner.
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
  deleteField,
  doc,
  getDoc,
  increment,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const here = dirname(fileURLToPath(import.meta.url));
const CID = 'S7C';
const NEW = '7c1c2d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e';
const ONB = '7c000000-0000-4000-8000-0000000000c1'; // seeded onboarded contract
const STD = '7c000000-0000-4000-8000-0000000000c2'; // seeded standard contract

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

// Weekly loan: ₹1,00,000 at ₹10,000, first due 70 days ago.
const INST = 1000000;
const N_INST = 10;
const SANCTIONED = INST * N_INST;
const DISBURSED = D(-77);
const FIRST_DUE = D(-70);
const dueOn = (seq) => addDays(FIRST_DUE, 7 * (seq - 1));

// Contract.toJson as the Dart side writes it after Sprint 7c.
const contract = (createdBy, over = {}) => ({
  baseInstallmentCount: N_INST, borrowerId: 'b1', borrowerName: 'Anita Sharma',
  borrowerPhoneE164: '+919845012890', closedAt: null, createdAt: Timestamp.now(),
  createdBy, disbursedOn: DISBURSED, firstDueDate: FIRST_DUE, frequency: 'weekly',
  guarantor: null, installmentPaise: INST, lastPaymentOn: null, loanNo: 8,
  netDisbursedPaise: SANCTIONED, notes: null, onboardedOn: T,
  onboardedPaymentCount: 6, onboardedTotalPaise: 5500000, origin: 'onboarded',
  preferredMonthDay: null, preferredWeekday: 2, previousRef: 'Book 7 / 12', purpose: null,
  rolledOverFromContractId: null, rolledOverToContractId: null, rolloverSettledPaise: null,
  sanctionedPaise: SANCTIONED, schemaVersion: 1, status: 'active', totalPaidPaise: 0,
  totalWaivedPaise: 0, updatedAt: Timestamp.now(), upfrontInput: 0, upfrontMode: 'flat',
  upfrontPaise: 0,
  ...over,
});
const standard = (createdBy, over = {}) => contract(createdBy, {
  origin: 'standard', onboardedOn: null, previousRef: null,
  onboardedPaymentCount: null, onboardedTotalPaise: null,
  disbursedOn: T, firstDueDate: D(7),
  ...over,
});
const installment = (contractId, seq, createdBy) => ({
  amountDuePaise: INST, borrowerId: 'b1', borrowerName: 'Anita Sharma', contractActive: true,
  contractId, createdAt: Timestamp.now(), createdBy, dueDate: dueOn(seq), kind: 'base',
  loanNo: 8, rescheduledFromId: null, rescheduledOutPaise: 0, rescheduledToIds: [],
  schemaVersion: 1, seq,
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

const createContract = (uid, data) => setDoc(doc(as(uid), p('contracts', NEW)), data);

// ---------------------------------------------------------------- env + seed

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
  const member = (uid, role) => ({
    uid, role, displayName: uid, phoneE164: null, status: 'active', inviteCode: null,
    invitedBy: null, joinedAt: Timestamp.now(), schemaVersion: 1,
  });
  await setDoc(doc(f, `companies/${CID}`), {
    name: 'Sri Lakshmi Finance', nameLower: 'sri lakshmi finance', city: null, phoneE164: null,
    ownerUids: ['ravi'], nextLoanNo: 8, createdBy: 'ravi', createdAt: Timestamp.now(), schemaVersion: 1,
  });
  await setDoc(doc(f, `companies/${CID}/members/ravi`), member('ravi', 'owner'));
  await setDoc(doc(f, `companies/${CID}/members/meena`), member('meena', 'collector'));
  // Onboarded contract whose chunk 1 landed with 5 of its 6 payments.
  await setDoc(doc(f, p('contracts', ONB)), contract('ravi', { totalPaidPaise: 5 * INST }));
  await setDoc(doc(f, p('contracts', STD)), standard('ravi'));
});

const readAs = async (path) => {
  let out;
  await env.withSecurityRulesDisabled(async (ctx) => {
    out = (await getDoc(doc(ctx.firestore(), path))).data();
  });
  return out;
};

beforeEach(async () => { await env.clearFirestore(); await seed(); });

// ---------------------------------------------------------------- M2: create

describe('Sprint 7c: onboarded contract carries the onboarding totals', () => {
  const ok = (over = {}) => contract('ravi', { totalPaidPaise: 5 * INST, ...over });
  it('owner, counts as ints ≥ 0: allowed', async () => {
    await assertSucceeds(createContract('ravi', ok()));
  });
  it('owner, ₹0 onboarding (0 payments, ₹0 total): allowed', async () => {
    await assertSucceeds(createContract('ravi', ok({
      totalPaidPaise: 0, onboardedPaymentCount: 0, onboardedTotalPaise: 0,
    })));
  });
  it('owner, 1,100 payments: allowed; 1,101: denied', async () => {
    await assertSucceeds(createContract('ravi', ok({ onboardedPaymentCount: 1100 })));
    await assertFails(createContract('ravi', ok({ onboardedPaymentCount: 1101 })));
  });
  it('onboardedPaymentCount missing / null: denied', async () => {
    const data = ok();
    delete data.onboardedPaymentCount;
    await assertFails(createContract('ravi', data));
    await assertFails(createContract('ravi', ok({ onboardedPaymentCount: null })));
  });
  it('onboardedTotalPaise missing / null: denied', async () => {
    const data = ok();
    delete data.onboardedTotalPaise;
    await assertFails(createContract('ravi', data));
    await assertFails(createContract('ravi', ok({ onboardedTotalPaise: null })));
  });
  it('negative count or total: denied', async () => {
    await assertFails(createContract('ravi', ok({ onboardedPaymentCount: -1 })));
    await assertFails(createContract('ravi', ok({ totalPaidPaise: 0, onboardedTotalPaise: -1 })));
  });
  it('non-int count or total (float, string): denied', async () => {
    await assertFails(createContract('ravi', ok({ onboardedPaymentCount: 1.5 })));
    await assertFails(createContract('ravi', ok({ onboardedPaymentCount: '6' })));
    await assertFails(createContract('ravi', ok({ onboardedTotalPaise: 5500000.5 })));
    await assertFails(createContract('ravi', ok({ onboardedTotalPaise: '5500000' })));
  });
  it('onboarded total == sanctioned (fully repaid): denied', async () => {
    await assertFails(createContract('ravi', ok({ onboardedTotalPaise: SANCTIONED })));
  });
  it('chunk-1 totalPaid above the onboarded total: denied', async () => {
    await assertFails(createContract('ravi', ok({ totalPaidPaise: 6 * INST })));
  });
  it('collector with valid totals: denied', async () => {
    await assertFails(createContract('meena', contract('meena', { totalPaidPaise: 0 })));
  });
});

describe('Sprint 7c: standard contracts carry no onboarding totals', () => {
  it('both null: allowed', async () => {
    await assertSucceeds(createContract('ravi', standard('ravi')));
  });
  it('both absent (older app build): allowed', async () => {
    const data = standard('ravi');
    delete data.onboardedPaymentCount;
    delete data.onboardedTotalPaise;
    await assertSucceeds(createContract('ravi', data));
  });
  it('onboardedPaymentCount set (even 0): denied', async () => {
    await assertFails(createContract('ravi', standard('ravi', { onboardedPaymentCount: 0 })));
  });
  it('onboardedTotalPaise set (even 0): denied', async () => {
    await assertFails(createContract('ravi', standard('ravi', { onboardedTotalPaise: 0 })));
  });
});

// ---------------------------------------------------------------- M2: update

describe('Sprint 7c: the onboarding totals are immutable', () => {
  const upd = (uid, data, id = ONB) => updateDoc(doc(as(uid), p('contracts', id)), data);
  it('owner changing onboardedPaymentCount / onboardedTotalPaise: denied', async () => {
    await assertFails(upd('ravi', { onboardedPaymentCount: 5 }));
    await assertFails(upd('ravi', { onboardedTotalPaise: 4500000 }));
  });
  it('owner deleting them: denied', async () => {
    await assertFails(upd('ravi', { onboardedPaymentCount: deleteField() }));
    await assertFails(upd('ravi', { onboardedTotalPaise: deleteField() }));
  });
  it('owner adding them to a standard contract: denied', async () => {
    await assertFails(upd('ravi', { onboardedPaymentCount: 1, onboardedTotalPaise: 100 }, STD));
  });
  it('collector changing them alongside a payment increment: denied', async () => {
    await assertFails(upd('meena', {
      totalPaidPaise: increment(100), updatedAt: Timestamp.now(), onboardedPaymentCount: 7,
    }));
  });
  it('owner increment that leaves them untouched (control): allowed', async () => {
    await assertSucceeds(upd('ravi', { totalPaidPaise: increment(INST), updatedAt: Timestamp.now() }));
  });
});

// ---------------------------------------------------------------- M2: repair

describe('Sprint 7c: "Add missing onboarding payment"', () => {
  const addMissing = (uid, over = {}) => {
    const f = as(uid);
    const b = writeBatch(f);
    // The missing 6th payment: the ₹5,000 partial on row 6.
    const amount = over.amountPaise ?? 500000;
    b.set(doc(f, p('transactions', 'missing-1')), tx(ONB, uid, {
      paidOn: dueOn(6), amountPaise: amount, ...over,
    }));
    b.update(doc(f, p('contracts', ONB)), {
      totalPaidPaise: increment(amount), updatedAt: Timestamp.now(),
    });
    return b.commit();
  };
  it('owner, dated within [disbursedOn, onboardedOn]: allowed; totals unchanged', async () => {
    await assertSucceeds(addMissing('ravi'));
    const c = await readAs(p('contracts', ONB));
    expect(c.totalPaidPaise).toBe(5500000);
    expect(c.onboardedPaymentCount).toBe(6);
    expect(c.onboardedTotalPaise).toBe(5500000);
  });
  it('owner, dated on disbursedOn or onboardedOn (edges): allowed', async () => {
    await assertSucceeds(addMissing('ravi', { paidOn: DISBURSED }));
    const f = as('ravi');
    const b = writeBatch(f);
    b.set(doc(f, p('transactions', 'missing-2')), tx(ONB, 'ravi', { paidOn: T, amountPaise: 100 }));
    b.update(doc(f, p('contracts', ONB)), { totalPaidPaise: increment(100), updatedAt: Timestamp.now() });
    await assertSucceeds(b.commit());
  });
  it('owner, dated after onboardedOn: denied', async () => {
    await assertFails(addMissing('ravi', { paidOn: D(1) }));
  });
  it('owner, dated before disbursedOn: denied', async () => {
    await assertFails(addMissing('ravi', { paidOn: addDays(DISBURSED, -1) }));
  });
  it('owner, without a mode: denied', async () => {
    await assertFails(addMissing('ravi', { mode: null }));
  });
  it('owner, one payment above onboardedTotalPaise: denied (R2 single-payment bound)', async () => {
    await assertFails(addMissing('ravi', { amountPaise: 5500001 }));
    await assertSucceeds(addMissing('ravi', { amountPaise: 5500000 }));
  });
  it('collector: denied', async () => {
    await assertFails(addMissing('meena'));
  });
});

// ---------------------------------------------------------------- M1

describe('Sprint 7c: installments as spill ops (small batch limit)', () => {
  // batchLimit 5 for a ₹0 onboarding: [contract, disb, nextLoanNo, i1, i2],
  // [i3..i7], [i8..i10]. Batches 2 and 3 carry no contract op.
  const batches = (uid) => {
    const f = as(uid);
    const b1 = writeBatch(f);
    b1.set(doc(f, p('contracts', NEW)), {
      ...contract(uid, { onboardedPaymentCount: 0, onboardedTotalPaise: 0 }),
      totalPaidPaise: increment(0),
    });
    b1.set(doc(f, p('transactions', `${NEW}-d`)), tx(NEW, uid, {
      type: 'disbursement', amountPaise: SANCTIONED, paidOn: DISBURSED, mode: null,
    }));
    b1.update(doc(f, `companies/${CID}`), { nextLoanNo: increment(1) });
    const out = [b1];
    let b = b1;
    let count = 3;
    for (let seq = 1; seq <= N_INST; seq++) {
      if (count >= 5) { b = writeBatch(f); out.push(b); count = 0; }
      b.set(doc(f, p('installments', `${NEW}-i${seq}`)), installment(NEW, seq, uid));
      count++;
    }
    return out;
  };
  it('owner, 3 batches committed together in order: allowed; every row lands', async () => {
    const bs = batches('ravi');
    expect(bs).toHaveLength(3);
    await assertSucceeds(Promise.all(bs.map((b) => b.commit())));
    expect(await readAs(p('installments', `${NEW}-i10`))).toBeDefined();
    expect((await readAs(p('contracts', NEW))).onboardedPaymentCount).toBe(0);
  });
  it('owner, an installment-only batch without its contract: denied (R1, no orphan rows)', async () => {
    const f = as('ravi');
    const b = writeBatch(f);
    for (let seq = 1; seq <= 3; seq++) {
      b.set(doc(f, p('installments', `${NEW}-i${seq}`)), installment(NEW, seq, 'ravi'));
    }
    await assertFails(b.commit());
  });
  it('owner, an installment-only batch for a stored contract: allowed', async () => {
    const f = as('ravi');
    const b = writeBatch(f);
    for (let seq = 1; seq <= 3; seq++) {
      b.set(doc(f, p('installments', `${ONB}-x${seq}`)), installment(ONB, seq, 'ravi'));
    }
    await assertSucceeds(b.commit());
  });
  it('batch 1 denied ⇒ the overflow installment batch is denied too', async () => {
    const bs = batches('ravi');
    // Make batch 1 invalid: a fully repaid onboarded total.
    const f = as('ravi');
    const bad = writeBatch(f);
    bad.set(doc(f, p('contracts', NEW)), {
      ...contract('ravi', { onboardedPaymentCount: 0, onboardedTotalPaise: SANCTIONED }),
      totalPaidPaise: increment(0),
    });
    bs[0] = bad;
    const results = await Promise.allSettled(bs.map((b) => b.commit()));
    expect(results[0].status).toBe('rejected');
    expect(results.slice(1).every((r) => r.status === 'rejected')).toBe(true);
    expect(await readAs(p('installments', `${NEW}-i10`))).toBeUndefined();
    expect(await readAs(p('contracts', NEW))).toBeUndefined();
  });
  it('collector, an installment-only batch of base rows: denied', async () => {
    const f = as('meena');
    const b = writeBatch(f);
    b.set(doc(f, p('installments', `${NEW}-i1`)), installment(NEW, 1, 'meena'));
    await assertFails(b.commit());
  });
});
