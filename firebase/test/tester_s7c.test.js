// Tester, Sprint 7c: M2 onboarding totals, the "Add missing onboarding
// payment" repair and M1 installment spill, replayed against the rules
// (emulator only). Payload shapes mirror Contract/Installment/LedgerTransaction
// toJson after Sprint 7c. Dates are relative to IST today.
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
  doc,
  getDoc,
  increment,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const here = dirname(fileURLToPath(import.meta.url));
const CID = 'T7C';
const OTHER = 'T7X';
const NEW = 'e7c00000-0000-4000-8000-000000000001';
const ONB = 'e7c00000-0000-4000-8000-0000000000a1'; // onboarded yesterday
const STD = 'e7c00000-0000-4000-8000-0000000000b1';

let env;
const as = (uid) => (uid == null
  ? env.unauthenticatedContext().firestore()
  : env.authenticatedContext(uid).firestore());
const p = (col, id, cid = CID) => `companies/${cid}/${col}/${id}`;

const DAY = 86400000;
const T = new Date(Date.now() + 330 * 60000).toISOString().slice(0, 10);
const addDays = (civil, n) => new Date(Date.parse(`${civil}T00:00:00Z`) + n * DAY)
  .toISOString().slice(0, 10);
const D = (n) => addDays(T, n);

// The 10-week weekly loan: ₹1,00,000 at ₹10,000, disbursed 70 days ago.
const INST = 1000000;
const N_INST = 10;
const SANCTIONED = INST * N_INST;
const DISBURSED = D(-70);
const FIRST_DUE = D(-63);
const dueOn = (seq) => addDays(FIRST_DUE, 7 * (seq - 1));

const contract = (createdBy, over = {}) => ({
  baseInstallmentCount: N_INST, borrowerId: 'b1', borrowerName: 'Anita Sharma',
  borrowerPhoneE164: '+919845012890', closedAt: null, createdAt: Timestamp.now(),
  createdBy, disbursedOn: DISBURSED, firstDueDate: FIRST_DUE, frequency: 'weekly',
  guarantor: null, installmentPaise: INST, lastPaymentOn: null, loanNo: 8,
  netDisbursedPaise: SANCTIONED, notes: null, onboardedOn: T,
  onboardedPaymentCount: 6, onboardedTotalPaise: 5500000, origin: 'onboarded',
  preferredMonthDay: null, preferredWeekday: 2, previousRef: 'Book 3 / 117', purpose: null,
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
const omit = (o, ...keys) => Object.fromEntries(Object.entries(o).filter(([k]) => !keys.includes(k)));
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

const create = (uid, data) => setDoc(doc(as(uid), p('contracts', NEW)), data);

/** The repair batch: one onboarding payment + the totalPaid increment. */
const repair = (uid, contractId, over = {}, cid = CID) => {
  const f = as(uid);
  const b = writeBatch(f);
  const amount = over.amountPaise ?? 500000;
  b.set(doc(f, p('transactions', `rep-${Math.random()}`, cid)), tx(contractId, uid, {
    paidOn: dueOn(6), amountPaise: amount, ...over,
  }));
  b.update(doc(f, p('contracts', contractId, cid)), {
    totalPaidPaise: increment(amount), updatedAt: Timestamp.now(),
  });
  return b.commit();
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
  const member = (uid, role) => ({
    uid, role, displayName: uid, phoneE164: null, status: 'active', inviteCode: null,
    invitedBy: null, joinedAt: Timestamp.now(), schemaVersion: 1,
  });
  for (const [cid, owner] of [[CID, 'ravi'], [OTHER, 'otto']]) {
    await setDoc(doc(f, `companies/${cid}`), {
      name: 'Sri Lakshmi Finance', nameLower: 'sri lakshmi finance', city: null,
      phoneE164: null, ownerUids: [owner], nextLoanNo: 8, createdBy: owner,
      createdAt: Timestamp.now(), schemaVersion: 1,
    });
    await setDoc(doc(f, `companies/${cid}/members/${owner}`), member(owner, 'owner'));
  }
  await setDoc(doc(f, `companies/${CID}/members/meena`), member('meena', 'collector'));
  // Onboarded YESTERDAY with 5 of 6 payments landed, so a repair dated today
  // is inside "not future" but outside [disbursedOn, onboardedOn].
  await setDoc(doc(f, p('contracts', ONB)), contract('ravi', {
    onboardedOn: D(-1), totalPaidPaise: 5 * INST,
  }));
  await setDoc(doc(f, p('contracts', STD)), standard('ravi'));
  await setDoc(doc(f, p('contracts', ONB, OTHER)), contract('otto', { totalPaidPaise: 0 }));
});

const readRaw = async (path) => {
  let out;
  await env.withSecurityRulesDisabled(async (ctx) => {
    out = (await getDoc(doc(ctx.firestore(), path))).data();
  });
  return out;
};

beforeEach(async () => { await env.clearFirestore(); await seed(); });

describe('Tester 7c: onboardedPaymentCount / onboardedTotalPaise bounds', () => {
  it('count 1100: allowed', async () => {
    await assertSucceeds(create('ravi', contract('ravi', { onboardedPaymentCount: 1100 })));
  });
  it('count 1101: denied', async () => {
    await assertFails(create('ravi', contract('ravi', { onboardedPaymentCount: 1101 })));
  });
  it('total = sanctioned − 1 paisa: allowed', async () => {
    await assertSucceeds(create('ravi', contract('ravi', { onboardedTotalPaise: SANCTIONED - 1 })));
  });
  it('total = sanctioned: denied', async () => {
    await assertFails(create('ravi', contract('ravi', { onboardedTotalPaise: SANCTIONED })));
  });
  it('total > sanctioned: denied', async () => {
    await assertFails(create('ravi', contract('ravi', { onboardedTotalPaise: SANCTIONED + 100 })));
  });
  it('chunk-1 totalPaid == onboardedTotal: allowed', async () => {
    await assertSucceeds(create('ravi', contract('ravi', { totalPaidPaise: 5500000 })));
  });
  it('chunk-1 totalPaid > onboardedTotal: denied', async () => {
    await assertFails(create('ravi', contract('ravi', { totalPaidPaise: 5500001 })));
  });
});

describe('Tester 7c: standard contracts carry neither total', () => {
  it('both null: allowed', async () => {
    await assertSucceeds(create('ravi', standard('ravi')));
  });
  it('both absent: allowed', async () => {
    await assertSucceeds(create('ravi',
      omit(standard('ravi'), 'onboardedPaymentCount', 'onboardedTotalPaise')));
  });
  it('count set (6): denied', async () => {
    await assertFails(create('ravi', standard('ravi', { onboardedPaymentCount: 6 })));
  });
  it('total set (₹55,000): denied', async () => {
    await assertFails(create('ravi', standard('ravi', { onboardedTotalPaise: 5500000 })));
  });
  it('both set on an origin-absent doc: denied', async () => {
    await assertFails(create('ravi', omit(standard('ravi', {
      onboardedPaymentCount: 0, onboardedTotalPaise: 0,
    }), 'origin')));
  });
});

describe('Tester 7c: the totals are immutable on owner update', () => {
  it('owner raising onboardedPaymentCount alone: denied', async () => {
    await assertFails(updateDoc(doc(as('ravi'), p('contracts', ONB)), {
      onboardedPaymentCount: 5, updatedAt: Timestamp.now(),
    }));
  });
  it('owner lowering onboardedTotalPaise to hide a gap: denied', async () => {
    await assertFails(updateDoc(doc(as('ravi'), p('contracts', ONB)), {
      onboardedTotalPaise: 5000000, updatedAt: Timestamp.now(),
    }));
  });
  it('owner writing the same values back (no affected key): allowed', async () => {
    await assertSucceeds(updateDoc(doc(as('ravi'), p('contracts', ONB)), {
      onboardedPaymentCount: 6, onboardedTotalPaise: 5500000, updatedAt: Timestamp.now(),
    }));
  });
  it('values unchanged after a denied attempt', async () => {
    await assertFails(updateDoc(doc(as('ravi'), p('contracts', ONB)), {
      onboardedPaymentCount: 7, updatedAt: Timestamp.now(),
    }));
    const c = await readRaw(p('contracts', ONB));
    expect(c.onboardedPaymentCount).toBe(6);
    expect(c.onboardedTotalPaise).toBe(5500000);
  });
});

describe('Tester 7c: "Add missing onboarding payment" repair', () => {
  it('owner, inside [disbursedOn, onboardedOn]: allowed', async () => {
    await assertSucceeds(repair('ravi', ONB));
    expect((await readRaw(p('contracts', ONB))).totalPaidPaise).toBe(5500000);
  });
  it('owner, the day before disbursedOn: denied', async () => {
    await assertFails(repair('ravi', ONB, { paidOn: addDays(DISBURSED, -1) }));
  });
  it('owner, the day after onboardedOn (today, not future): denied', async () => {
    await assertFails(repair('ravi', ONB, { paidOn: T }));
  });
  it('collector, valid date and amount: denied', async () => {
    await assertFails(repair('meena', ONB));
  });
  it('signed out: denied', async () => {
    await assertFails(repair(null, ONB));
  });
  it('owner of another company: denied', async () => {
    await assertFails(repair('otto', ONB));
  });
  it('origin onboarding on a standard contract: denied', async () => {
    await assertFails(repair('ravi', STD, { paidOn: T }));
  });
});

describe('Tester 7c: M1 installment-only spill batch', () => {
  it('owner, installments only (no contract op), onboarded contract exists: allowed', async () => {
    const f = as('ravi');
    const b = writeBatch(f);
    for (let seq = 1; seq <= N_INST; seq++) {
      b.set(doc(f, p('installments', `${ONB}-i${seq}`)), installment(ONB, seq, 'ravi'));
    }
    await assertSucceeds(b.commit());
    expect(await readRaw(p('installments', `${ONB}-i10`))).toBeDefined();
  });
  it('owner, spill batch landing before chunk 1 (contract not yet there): denied (7c R1, no orphan rows)', async () => {
    const f = as('ravi');
    const b = writeBatch(f);
    b.set(doc(f, p('installments', `${NEW}-i1`)), installment(NEW, 1, 'ravi'));
    await assertFails(b.commit());
  });
  it('collector, the same spill batch: denied', async () => {
    const f = as('meena');
    const b = writeBatch(f);
    b.set(doc(f, p('installments', `${ONB}-i1`)), installment(ONB, 1, 'meena'));
    await assertFails(b.commit());
  });
});
