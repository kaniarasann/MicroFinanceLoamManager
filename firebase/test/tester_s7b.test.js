// Sprint 7b tester: onboarding rules replay (emulator only).
// Payloads mirror the Dart write path exactly: the key sets below are the
// ones asserted on the docs `onboardContract` writes in
// test/features/contracts/tester/s7b_onboard_repository_test.dart (R7), and
// the batches follow `OnboardingPlan.chunks` / `reverseOpeningBalance`
// (aggregate op first, then installments, disbursement, nextLoanNo, payments).
// Dates are relative to IST today.
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
  Timestamp, doc, getDoc, increment, serverTimestamp, setDoc, updateDoc, writeBatch,
} from 'firebase/firestore';

const here = dirname(fileURLToPath(import.meta.url));
const CID = 'T7B';
const OTHER = 'T7B-OTHER';

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

// Mirrored from the Dart R7 test (sorted).
const CONTRACT_KEYS = [
  'baseInstallmentCount', 'borrowerId', 'borrowerName', 'borrowerPhoneE164',
  'closedAt', 'createdAt', 'createdBy', 'disbursedOn', 'firstDueDate',
  'frequency', 'guarantor', 'installmentPaise', 'lastPaymentOn', 'loanNo',
  'netDisbursedPaise', 'notes', 'onboardedOn', 'origin', 'preferredMonthDay',
  'preferredWeekday', 'previousRef', 'purpose', 'rolledOverFromContractId',
  'rolledOverToContractId', 'rolloverSettledPaise', 'sanctionedPaise',
  'schemaVersion', 'status', 'totalPaidPaise', 'totalWaivedPaise',
  'updatedAt', 'upfrontInput', 'upfrontMode', 'upfrontPaise',
].sort();
const INSTALLMENT_KEYS = [
  'amountDuePaise', 'borrowerId', 'borrowerName', 'contractActive',
  'contractId', 'createdAt', 'createdBy', 'dueDate', 'kind', 'loanNo',
  'rescheduledFromId', 'rescheduledOutPaise', 'rescheduledToIds',
  'schemaVersion', 'seq',
].sort();
const TX_KEYS = [
  'amountPaise', 'borrowerId', 'borrowerName', 'clientRecordedAt',
  'contractActive', 'contractId', 'deviceId', 'loanNo', 'mode', 'note',
  'openingBalance', 'origin', 'paidOn', 'recordedAt', 'recordedBy',
  'recordedByName', 'reference', 'relatedContractId', 'rescheduleInfo',
  'reversesTxId', 'schemaVersion', 'type',
].sort();

// ---------------------------------------------------------------- loans

// Weekly: ₹1,00,000, ₹10,000 weekly, first due 70 days ago, disbursed 77
// days ago, ₹5,000 upfront. Opening ₹55,000 spread: rows 1–5 + ₹5,000 on 6.
const WEEKLY = {
  id: 'a7b00000-0000-4000-8000-0000000000w1', frequency: 'weekly', weekday: 2,
  sanctioned: 10000000, upfront: 500000, inst: 1000000, n: 10,
  disbursedOn: D(-77), firstDue: D(-70), step: 7,
};
// Daily: ₹36,600 at ₹100, 366 rows, disbursed 400 days ago, upfront ₹0.
const DAILY = {
  id: 'a7b00000-0000-4000-8000-0000000000d1', frequency: 'daily', weekday: null,
  sanctioned: 3660000, upfront: 0, inst: 10000, n: 366,
  disbursedOn: D(-400), firstDue: D(-399), step: 1,
};
const dueOn = (loan, seq) => addDays(loan.firstDue, loan.step * (seq - 1));

const contractDoc = (loan, uid, over = {}) => ({
  baseInstallmentCount: loan.n, borrowerId: 'b1', borrowerName: 'Anita Sharma',
  borrowerPhoneE164: '+919845012890', closedAt: null, createdAt: Timestamp.now(),
  createdBy: uid, disbursedOn: loan.disbursedOn, firstDueDate: loan.firstDue,
  frequency: loan.frequency, guarantor: null, installmentPaise: loan.inst,
  lastPaymentOn: null, loanNo: 4, netDisbursedPaise: loan.sanctioned - loan.upfront,
  notes: null, onboardedOn: T, origin: 'onboarded', preferredMonthDay: null,
  preferredWeekday: loan.weekday, previousRef: 'Book 7 / 12', purpose: null,
  rolledOverFromContractId: null, rolledOverToContractId: null,
  rolloverSettledPaise: null, sanctionedPaise: loan.sanctioned, schemaVersion: 1,
  status: 'active', totalPaidPaise: 0, totalWaivedPaise: 0,
  updatedAt: Timestamp.now(), upfrontInput: loan.upfront, upfrontMode: 'flat',
  upfrontPaise: loan.upfront,
  ...over,
});
const installmentDoc = (loan, seq, uid) => ({
  amountDuePaise: loan.inst, borrowerId: 'b1', borrowerName: 'Anita Sharma',
  contractActive: true, contractId: loan.id, createdAt: Timestamp.now(), createdBy: uid,
  dueDate: dueOn(loan, seq), kind: 'base', loanNo: 4, rescheduledFromId: null,
  rescheduledOutPaise: 0, rescheduledToIds: [], schemaVersion: 1, seq,
});
const txDoc = (contractId, uid, over = {}) => ({
  amountPaise: 1000000, borrowerId: 'b1', borrowerName: 'Anita Sharma',
  clientRecordedAt: Timestamp.now(), contractActive: true, contractId,
  deviceId: 'dev-1', loanNo: 4, mode: 'cash', note: null, openingBalance: false,
  origin: 'onboarding', paidOn: T, recordedAt: serverTimestamp(), recordedBy: uid,
  recordedByName: 'Ravi', reference: null, relatedContractId: null,
  rescheduleInfo: null, reversesTxId: null, schemaVersion: 1, type: 'payment',
  ...over,
});

// Weekly opening-total spread (as spreadOpeningTotal produces it).
const weeklySpread = () => [
  ...[1, 2, 3, 4, 5].map((s) => ({ paidOn: dueOn(WEEKLY, s), amountPaise: 1000000 })),
  { paidOn: dueOn(WEEKLY, 6), amountPaise: 500000 },
].map((x) => ({ ...x, mode: 'cash', openingBalance: true, note: 'Opening balance' }));

// Daily itemised payments (oldest first, as planOnboarding sorts them).
const dailyItemised = (n, amountPaise) => Array.from({ length: n }, (_, i) => ({
  paidOn: addDays(DAILY.firstDue, i % 300), amountPaise,
  mode: ['upi', 'cash', 'bank'][i % 3], openingBalance: false, note: null,
})).sort((a, b) => a.paidOn.localeCompare(b.paidOn));

// balancedChunkSizes: first batch room = 450 − (N inst + disb + company) − 1.
const chunkSizes = (items, nInst) => {
  const first = Math.min(items, 450 - (nInst + 2) - 1);
  const out = [first];
  let left = items - first;
  while (left > 0) { const k = Math.min(left, 449); out.push(k); left -= k; }
  return out;
};

/** Builds the batches of `OnboardingPlan.chunks` for [loan] as [uid]. */
const onboardBatches = (loan, uid, pays, { contractOver = {}, f = as(uid) } = {}) => {
  const sizes = chunkSizes(pays.length, loan.n);
  const last = pays.length ? pays[pays.length - 1].paidOn : null;
  const batches = [];
  let at = 0;
  sizes.forEach((size, c) => {
    const b = writeBatch(f);
    const chunk = pays.slice(at, at + size);
    const sum = chunk.reduce((s, x) => s + x.amountPaise, 0);
    const cref = doc(f, p('contracts', loan.id));
    if (c === 0) {
      b.set(cref, { ...contractDoc(loan, uid, { lastPaymentOn: last, ...contractOver }), totalPaidPaise: increment(sum) });
      for (let seq = 1; seq <= loan.n; seq++) {
        b.set(doc(f, p('installments', `${loan.id}-i${seq}`)), installmentDoc(loan, seq, uid));
      }
      b.set(doc(f, p('transactions', `${loan.id}-d`)), txDoc(loan.id, uid, {
        type: 'disbursement', amountPaise: loan.sanctioned - loan.upfront,
        paidOn: loan.disbursedOn, mode: null,
      }));
      b.update(doc(f, `companies/${CID}`), { nextLoanNo: increment(1) });
    } else {
      b.update(cref, { totalPaidPaise: increment(sum), updatedAt: Timestamp.now() });
    }
    chunk.forEach((x, i) => {
      b.set(doc(f, p('transactions', `${loan.id}-p${at + i}`)), txDoc(loan.id, uid, x));
    });
    at += size;
    batches.push(b);
  });
  return batches;
};
// Committed together, in order (like BalancedChunks.commit).
const commitAll = (batches) => Promise.all(batches.map((b) => b.commit()));
const onboard = (loan, uid, pays, opts) => commitAll(onboardBatches(loan, uid, pays, opts));

const readAs = async (path) => {
  let out;
  await env.withSecurityRulesDisabled(async (ctx) => {
    out = (await getDoc(doc(ctx.firestore(), path))).data();
  });
  return out;
};

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
  const company = (owner) => ({
    name: 'Sri Lakshmi Finance', nameLower: 'sri lakshmi finance', city: null, phoneE164: null,
    ownerUids: [owner], nextLoanNo: 4, createdBy: owner, createdAt: Timestamp.now(), schemaVersion: 1,
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
});

beforeEach(async () => { await env.clearFirestore(); await seed(); });

// ---------------------------------------------------------------- tests

describe('Tester 7b: payload mirror', () => {
  it('builders produce exactly the Dart key sets', () => {
    expect(Object.keys(contractDoc(WEEKLY, 'ravi')).sort()).toEqual(CONTRACT_KEYS);
    expect(Object.keys(installmentDoc(WEEKLY, 1, 'ravi')).sort()).toEqual(INSTALLMENT_KEYS);
    expect(Object.keys(txDoc(WEEKLY.id, 'ravi')).sort()).toEqual(TX_KEYS);
  });
  it('chunk plan matches the Dart planner: 6 → [6]; 300 → [81, 219]; 1100 → [81, 449, 449, 121]', () => {
    expect(chunkSizes(6, 10)).toEqual([6]);
    expect(chunkSizes(300, 366)).toEqual([81, 219]);
    expect(chunkSizes(1100, 366)).toEqual([81, 449, 449, 121]);
  });
});

describe('Tester 7b: replay of the Dart onboarding batches', () => {
  it('weekly ₹55,000 opening total (1 batch, 19 ops) by owner: allowed; totalPaid ₹55,000', async () => {
    await assertSucceeds(onboard(WEEKLY, 'ravi', weeklySpread()));
    const c = await readAs(p('contracts', WEEKLY.id));
    expect(c.totalPaidPaise).toBe(5500000);
    expect(c.lastPaymentOn).toBe(dueOn(WEEKLY, 6));
    expect((await readAs(`companies/${CID}`)).nextLoanNo).toBe(5);
  });
  it('daily 300 itemised (2 batches: 450 + 220 ops) by owner: allowed; Σ == totalPaid', async () => {
    await assertSucceeds(onboard(DAILY, 'ravi', dailyItemised(300, 10000)));
    expect((await readAs(p('contracts', DAILY.id))).totalPaidPaise).toBe(3000000);
  });
  it('daily 1,100 itemised (4 batches) by owner: allowed; Σ == totalPaid', async () => {
    await assertSucceeds(onboard(DAILY, 'ravi', dailyItemised(1100, 1000)));
    expect((await readAs(p('contracts', DAILY.id))).totalPaidPaise).toBe(1100000);
  });
  it('opening ₹0 and upfront ₹0 (net = sanctioned): allowed', async () => {
    await assertSucceeds(onboard({ ...WEEKLY, upfront: 0 }, 'ravi', []));
  });
  it('collector replaying the weekly batch: denied, nothing lands', async () => {
    await assertFails(onboard(WEEKLY, 'meena', weeklySpread()));
    expect(await readAs(p('contracts', WEEKLY.id))).toBeUndefined();
  });
  it('another company owner replaying the weekly batch: denied', async () => {
    await assertFails(onboard(WEEKLY, 'zed', weeklySpread()));
  });
  it('signed out: denied', async () => {
    await assertFails(onboard(WEEKLY, null, weeklySpread()));
  });
  it('opening total == sanctioned (fully repaid): denied', async () => {
    const all10 = Array.from({ length: 10 }, (_, i) => ({
      paidOn: dueOn(WEEKLY, i + 1), amountPaise: 1000000, mode: 'cash', openingBalance: true,
    }));
    await assertFails(onboard(WEEKLY, 'ravi', all10));
  });
  it('previousRef 41 chars: denied; 40 chars: allowed', async () => {
    await assertFails(onboard(WEEKLY, 'ravi', [], { contractOver: { previousRef: 'R'.repeat(41) } }));
    await assertSucceeds(onboard(WEEKLY, 'ravi', [], { contractOver: { previousRef: 'R'.repeat(40) } }));
  });
  it('a payment before disbursedOn in the batch: denied', async () => {
    await assertFails(onboard(WEEKLY, 'ravi', [
      { paidOn: addDays(WEEKLY.disbursedOn, -1), amountPaise: 100, mode: 'cash' },
    ]));
  });
  it('a payment without a mode in the batch: denied', async () => {
    await assertFails(onboard(WEEKLY, 'ravi', [{ paidOn: dueOn(WEEKLY, 1), amountPaise: 100, mode: null }]));
  });
});

describe('Tester 7b: after onboarding', () => {
  beforeEach(async () => { await onboard(WEEKLY, 'ravi', weeklySpread()); });
  const pay = (uid, over = {}, contractUpd = {}) => {
    const f = as(uid);
    const b = writeBatch(f);
    b.set(doc(f, p('transactions', 'live-1')), txDoc(WEEKLY.id, uid, {
      origin: 'live', amountPaise: 500000, mode: 'upi', ...over,
    }));
    b.update(doc(f, p('contracts', WEEKLY.id)), {
      totalPaidPaise: increment(over.amountPaise ?? 500000), lastPaymentOn: T,
      updatedAt: Timestamp.now(), ...contractUpd,
    });
    return b.commit();
  };

  it('collector live payment today (origin live): allowed', async () => {
    await assertSucceeds(pay('meena'));
  });
  it('collector live payment of ₹45,000 that closes the loan (+ contractActive flips): allowed', async () => {
    const f = as('meena');
    const b = writeBatch(f);
    b.set(doc(f, p('transactions', 'live-close')), txDoc(WEEKLY.id, 'meena', {
      origin: 'live', amountPaise: 4500000, mode: 'upi', contractActive: false,
    }));
    b.update(doc(f, p('contracts', WEEKLY.id)), {
      totalPaidPaise: increment(4500000), lastPaymentOn: T, updatedAt: Timestamp.now(),
      status: 'closed', closedAt: Timestamp.now(),
    });
    for (let s = 1; s <= 10; s++) b.update(doc(f, p('installments', `${WEEKLY.id}-i${s}`)), { contractActive: false });
    b.update(doc(f, p('transactions', `${WEEKLY.id}-d`)), { contractActive: false });
    for (let i = 0; i < 6; i++) b.update(doc(f, p('transactions', `${WEEKLY.id}-p${i}`)), { contractActive: false });
    await assertSucceeds(b.commit());
    expect((await readAs(p('contracts', WEEKLY.id))).status).toBe('closed');
  });
  it('live payment carrying openingBalance: true: denied (collector and owner)', async () => {
    await assertFails(pay('meena', { openingBalance: true }));
    await assertFails(pay('ravi', { openingBalance: true }));
  });
  it('owner reversal of one onboarding payment dated on its original paidOn: allowed', async () => {
    const f = as('ravi');
    const b = writeBatch(f);
    b.set(doc(f, p('transactions', 'rev-1')), txDoc(WEEKLY.id, 'ravi', {
      type: 'reversal', paidOn: dueOn(WEEKLY, 3), mode: 'cash', note: 'Not paid',
      reversesTxId: `${WEEKLY.id}-p2`,
    }));
    b.update(doc(f, p('contracts', WEEKLY.id)), {
      totalPaidPaise: increment(-1000000), updatedAt: Timestamp.now(),
    });
    await assertSucceeds(b.commit());
    expect((await readAs(p('contracts', WEEKLY.id))).totalPaidPaise).toBe(4500000);
  });
  it('collector onboarding reversal: denied', async () => {
    const f = as('meena');
    const b = writeBatch(f);
    b.set(doc(f, p('transactions', 'rev-1')), txDoc(WEEKLY.id, 'meena', {
      type: 'reversal', paidOn: dueOn(WEEKLY, 3), note: 'x', reversesTxId: `${WEEKLY.id}-p2`,
    }));
    b.update(doc(f, p('contracts', WEEKLY.id)), { totalPaidPaise: increment(-1000000), updatedAt: Timestamp.now() });
    await assertFails(b.commit());
  });
  const reverseOpening = (uid) => {
    const f = as(uid);
    const b = writeBatch(f);
    b.update(doc(f, p('contracts', WEEKLY.id)), {
      totalPaidPaise: increment(-5500000), updatedAt: Timestamp.now(),
    });
    weeklySpread().forEach((x, i) => {
      b.set(doc(f, p('transactions', `ro-${i}`)), txDoc(WEEKLY.id, uid, {
        type: 'reversal', amountPaise: x.amountPaise, paidOn: x.paidOn, mode: 'cash',
        note: 'Wrong opening total', reversesTxId: `${WEEKLY.id}-p${i}`, openingBalance: false,
      }));
    });
    return b.commit();
  };
  it('reverseOpeningBalance batch (6 reversals + contract −Σ) by owner: allowed; totalPaid 0', async () => {
    await assertSucceeds(reverseOpening('ravi'));
    expect((await readAs(p('contracts', WEEKLY.id))).totalPaidPaise).toBe(0);
  });
  it('reverseOpeningBalance batch by collector: denied', async () => {
    await assertFails(reverseOpening('meena'));
  });
  it('owner updates to origin / onboardedOn / disbursedOn: denied; removing origin: denied', async () => {
    const r = doc(as('ravi'), p('contracts', WEEKLY.id));
    await assertFails(updateDoc(r, { origin: 'standard' }));
    await assertFails(updateDoc(r, { onboardedOn: D(-1) }));
    await assertFails(updateDoc(r, { disbursedOn: D(-78) }));
    const data = contractDoc(WEEKLY, 'ravi', { totalPaidPaise: 5500000 });
    delete data.origin;
    await assertFails(setDoc(r, data));
  });
});

describe('Tester 7b: standard contracts', () => {
  const STD = { ...WEEKLY, id: 'a7b00000-0000-4000-8000-0000000000s1', disbursedOn: T, firstDue: D(7) };
  const std = (over = {}) => contractDoc(STD, 'ravi', { origin: 'standard', onboardedOn: null, previousRef: null, ...over });
  it('standard contract with totalPaid 0: allowed (control)', async () => {
    await assertSucceeds(setDoc(doc(as('ravi'), p('contracts', STD.id)), std()));
  });
  it('standard contract with totalPaid > 0: denied', async () => {
    await assertFails(setDoc(doc(as('ravi'), p('contracts', STD.id)), std({ totalPaidPaise: 100 })));
  });
  it('owner adding origin onboarded to a legacy contract (no origin field): denied', async () => {
    const legacy = std();
    delete legacy.origin; delete legacy.onboardedOn; delete legacy.previousRef;
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), p('contracts', STD.id)), legacy));
    await assertFails(updateDoc(doc(as('ravi'), p('contracts', STD.id)), { origin: 'onboarded', onboardedOn: T }));
  });
  it('onboarding payment on a standard contract: denied', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), p('contracts', STD.id)), std()));
    await assertFails(setDoc(doc(as('ravi'), p('transactions', 'x')), txDoc(STD.id, 'ravi', { paidOn: T })));
  });
});
